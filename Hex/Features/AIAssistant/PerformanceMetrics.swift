import Foundation
import ComposableArchitecture
import os.log

/// Represents a single performance measurement
struct PerformanceMetric: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let operationName: String
    let category: String // e.g., "ModelLoading", "Inference", "Search", "Timer", "Calculator"
    let duration: TimeInterval
    let memoryDelta: Int64? // bytes
    let cpuUsage: Double? // percentage
    let metadata: [String: String]?
    let success: Bool
    
    init(
        operationName: String,
        category: String,
        duration: TimeInterval,
        memoryDelta: Int64? = nil,
        cpuUsage: Double? = nil,
        metadata: [String: String]? = nil,
        success: Bool = true
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.operationName = operationName
        self.category = category
        self.duration = duration
        self.memoryDelta = memoryDelta
        self.cpuUsage = cpuUsage
        self.metadata = metadata
        self.success = success
    }
}

/// Performance threshold configuration
struct PerformanceThreshold: Codable {
    let operationName: String
    let warningThreshold: TimeInterval
    let criticalThreshold: TimeInterval
    let category: String
}

/// Performance summary for an operation
struct PerformanceSummary: Codable {
    let operationName: String
    let category: String
    let measurementCount: Int
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let averageDuration: TimeInterval
    let p95Duration: TimeInterval
    let p99Duration: TimeInterval
    let successRate: Double
    let totalMemoryDelta: Int64?
    let averageMemoryDelta: Int64?
    let averageCPUUsage: Double?
}

/// Real-time performance tracker
actor PerformanceMetrics {
    static let shared = PerformanceMetrics()
    
    private var metrics: [PerformanceMetric] = []
    private var thresholds: [String: PerformanceThreshold] = [:]
    private var activeOperations: [String: Date] = [:]
    private let osLog = OSLog(subsystem: "com.hex.ai-assistant", category: "Performance")
    private let fileManager = FileManager.default
    private let metricsDirectory: URL
    private var performanceAlerts: [String: Int] = [:] // operation -> alert count
    
    /// Configuration for performance tracking
    struct Configuration {
        let maxMetricsInMemory: Int = 10000
        let enablePersistence: Bool = true
        let persistenceInterval: TimeInterval = 30 // seconds
        let retentionDays: Int = 7
        let enableResourceTracking: Bool = true
        let alertOnThresholdExceedance: Bool = true
    }
    
    private let config: Configuration
    private var persistenceTask: Task<Void, Never>?
    
    nonisolated private init() {
        self.config = Configuration()
        
        // Setup metrics directory
        let appSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.metricsDirectory = appSupportDirectory.appendingPathComponent("HexMetrics", isDirectory: true)
        
        Task {
            try? FileManager.default.createDirectory(
                at: self.metricsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            await self.setupPersistenceTask()
            await self.loadPersistentMetrics()
            await self.setupDefaultThresholds()
        }
    }
    
    // MARK: - Recording Metrics
    
    /// Start measuring an operation (returns operation ID)
    func startOperation(_ name: String, category: String) -> String {
        let operationId = UUID().uuidString
        activeOperations[operationId] = Date()
        return operationId
    }
    
    /// End operation and record metric
    func endOperation(
        _ operationId: String,
        operationName: String,
        category: String,
        metadata: [String: String]? = nil,
        success: Bool = true
    ) {
        guard let startTime = activeOperations.removeValue(forKey: operationId) else {
            os_log("Operation not found: %{public}@", log: osLog, type: .warning, operationId)
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let metric = PerformanceMetric(
            operationName: operationName,
            category: category,
            duration: duration,
            metadata: metadata,
            success: success
        )
        
        recordMetric(metric)
        checkThresholds(metric)
    }
    
    /// Record a metric directly
    func recordMetric(_ metric: PerformanceMetric) {
        metrics.append(metric)
        
        // Maintain size limit
        if metrics.count > config.maxMetricsInMemory {
            metrics.removeFirst(metrics.count - config.maxMetricsInMemory)
        }
        
        // Log slow operations
        if let threshold = thresholds[metric.operationName] {
            if metric.duration > threshold.criticalThreshold {
                os_log(
                    "CRITICAL: Operation %{public}@ took %.2f seconds (threshold: %.2f)",
                    log: osLog,
                    type: .fault,
                    metric.operationName,
                    metric.duration,
                    threshold.criticalThreshold
                )
            } else if metric.duration > threshold.warningThreshold {
                os_log(
                    "WARNING: Operation %{public}@ took %.2f seconds (threshold: %.2f)",
                    log: osLog,
                    type: .error,
                    metric.operationName,
                    metric.duration,
                    threshold.warningThreshold
                )
            }
        }
    }
    
    // MARK: - Threshold Management
    
    private func setupDefaultThresholds() {
        let defaultThresholds = [
            // Model operations
            PerformanceThreshold(
                operationName: "ModelLoading",
                warningThreshold: 5.0,
                criticalThreshold: 10.0,
                category: "ModelLoading"
            ),
            PerformanceThreshold(
                operationName: "Inference",
                warningThreshold: 3.0,
                criticalThreshold: 10.0,
                category: "Inference"
            ),
            // Search operations
            PerformanceThreshold(
                operationName: "WebSearch",
                warningThreshold: 2.0,
                criticalThreshold: 5.0,
                category: "Search"
            ),
            // System operations
            PerformanceThreshold(
                operationName: "SystemCommand",
                warningThreshold: 1.0,
                criticalThreshold: 5.0,
                category: "SystemCommand"
            ),
            // Productivity tools
            PerformanceThreshold(
                operationName: "Calculator",
                warningThreshold: 0.1,
                criticalThreshold: 0.5,
                category: "Calculator"
            ),
            PerformanceThreshold(
                operationName: "NotePersistence",
                warningThreshold: 1.0,
                criticalThreshold: 3.0,
                category: "Todo"
            ),
            PerformanceThreshold(
                operationName: "TodoPersistence",
                warningThreshold: 1.0,
                criticalThreshold: 3.0,
                category: "Todo"
            )
        ]
        
        for threshold in defaultThresholds {
            thresholds[threshold.operationName] = threshold
        }
    }
    
    /// Set custom threshold for an operation
    func setThreshold(
        operationName: String,
        warningThreshold: TimeInterval,
        criticalThreshold: TimeInterval,
        category: String
    ) {
        thresholds[operationName] = PerformanceThreshold(
            operationName: operationName,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold,
            category: category
        )
    }
    
    private func checkThresholds(_ metric: PerformanceMetric) {
        guard let threshold = thresholds[metric.operationName] else { return }
        guard config.alertOnThresholdExceedance else { return }
        
        if metric.duration > threshold.criticalThreshold {
            performanceAlerts[metric.operationName, default: 0] += 1
            os_log(
                "Performance alert: %{public}@ exceeded critical threshold",
                log: osLog,
                type: .fault,
                metric.operationName
            )
        }
    }
    
    // MARK: - Querying Metrics
    
    /// Get all metrics
    func getMetrics(limit: Int = 1000) -> [PerformanceMetric] {
        Array(metrics.suffix(limit))
    }
    
    /// Get metrics for an operation
    func getMetricsForOperation(_ operationName: String, limit: Int = 1000) -> [PerformanceMetric] {
        metrics.filter { $0.operationName == operationName }.suffix(limit).reversed()
    }
    
    /// Get metrics for a category
    func getMetricsForCategory(_ category: String, limit: Int = 1000) -> [PerformanceMetric] {
        metrics.filter { $0.category == category }.suffix(limit).reversed()
    }
    
    /// Get metrics within a date range
    func getMetricsByDateRange(from: Date, to: Date) -> [PerformanceMetric] {
        metrics.filter { $0.timestamp >= from && $0.timestamp <= to }
    }
    
    /// Get metrics since a given time interval
    func getMetricsSince(_ timeInterval: TimeInterval) -> [PerformanceMetric] {
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        return metrics.filter { $0.timestamp >= cutoffDate }
    }
    
    // MARK: - Analytics
    
    /// Get performance summary for an operation
    func getSummary(for operationName: String) -> PerformanceSummary? {
        let operationMetrics = metrics.filter { $0.operationName == operationName }
        guard !operationMetrics.isEmpty else { return nil }
        
        let durations = operationMetrics.map { $0.duration }.sorted()
        let successCount = operationMetrics.filter { $0.success }.count
        let successRate = Double(successCount) / Double(operationMetrics.count)
        
        let p95Index = Int(Double(durations.count) * 0.95)
        let p99Index = Int(Double(durations.count) * 0.99)
        
        let memoryDeltas = operationMetrics.compactMap { $0.memoryDelta }
        let totalMemory = memoryDeltas.reduce(0, +)
        let avgMemory = memoryDeltas.isEmpty ? nil : totalMemory / Int64(memoryDeltas.count)
        
        let cpuUsages = operationMetrics.compactMap { $0.cpuUsage }
        let avgCPU = cpuUsages.isEmpty ? nil : cpuUsages.reduce(0, +) / Double(cpuUsages.count)
        
        return PerformanceSummary(
            operationName: operationName,
            category: operationMetrics.first?.category ?? "Unknown",
            measurementCount: operationMetrics.count,
            minDuration: durations.first ?? 0,
            maxDuration: durations.last ?? 0,
            averageDuration: durations.reduce(0, +) / Double(durations.count),
            p95Duration: durations[safe: p95Index] ?? durations.last ?? 0,
            p99Duration: durations[safe: p99Index] ?? durations.last ?? 0,
            successRate: successRate,
            totalMemoryDelta: memoryDeltas.isEmpty ? nil : totalMemory,
            averageMemoryDelta: avgMemory,
            averageCPUUsage: avgCPU
        )
    }
    
    /// Get summaries for all operations
    func getAllSummaries() -> [String: PerformanceSummary] {
        let operationNames = Set(metrics.map { $0.operationName })
        var summaries: [String: PerformanceSummary] = [:]
        
        for name in operationNames {
            if let summary = getSummary(for: name) {
                summaries[name] = summary
            }
        }
        
        return summaries
    }
    
    /// Get slowest operations
    func getSlowestOperations(limit: Int = 10) -> [(name: String, avgDuration: TimeInterval)] {
        let operationNames = Set(metrics.map { $0.operationName })
        var slowest: [(String, TimeInterval)] = []
        
        for name in operationNames {
            if let summary = getSummary(for: name) {
                slowest.append((name, summary.averageDuration))
            }
        }
        
        return slowest.sorted { $0.1 > $1.1 }.prefix(limit).map { $0 }
    }
    
    /// Get operations with highest failure rate
    func getUnreliableOperations(limit: Int = 10) -> [(name: String, failureRate: Double)] {
        let operationNames = Set(metrics.map { $0.operationName })
        var unreliable: [(String, Double)] = []
        
        for name in operationNames {
            if let summary = getSummary(for: name) {
                let failureRate = 1.0 - summary.successRate
                if failureRate > 0.0 {
                    unreliable.append((name, failureRate))
                }
            }
        }
        
        return unreliable.sorted { $0.1 > $1.1 }.prefix(limit).map { $0 }
    }
    
    /// Get comprehensive performance report
    func getPerformanceReport() -> [String: Any] {
        let allSummaries = getAllSummaries()
        let slowest = getSlowestOperations(limit: 5)
        let unreliable = getUnreliableOperations(limit: 5)
        let alerts = performanceAlerts.filter { $0.value > 0 }
        
        return [
            "totalMeasurements": metrics.count,
            "operationCount": allSummaries.count,
            "summaries": allSummaries,
            "slowestOperations": slowest.map { ["name": $0.name, "avgDuration": $0.avgDuration] },
            "unreliableOperations": unreliable.map { ["name": $0.name, "failureRate": $0.failureRate] },
            "performanceAlerts": alerts,
            "lastUpdateTime": Date()
        ]
    }
    
    /// Get performance health score (0-100)
    func getHealthScore() -> Int {
        guard !metrics.isEmpty else { return 100 }
        
        let summaries = getAllSummaries()
        var score = 100
        
        for (name, summary) in summaries {
            // Penalize high failure rates
            let failureRate = 1.0 - summary.successRate
            score -= Int(failureRate * 20) // up to 20 points per operation
            
            // Penalize operations exceeding thresholds
            if let threshold = thresholds[name] {
                if summary.averageDuration > threshold.criticalThreshold {
                    score -= 15
                } else if summary.averageDuration > threshold.warningThreshold {
                    score -= 5
                }
            }
        }
        
        return max(0, score)
    }
    
    // MARK: - Persistence
    
    private func setupPersistenceTask() {
        persistenceTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(config.persistenceInterval * 1_000_000_000))
                if !Task.isCancelled {
                    await persistMetrics()
                }
            }
        }
    }
    
    private func persistMetrics() async {
        guard config.enablePersistence else { return }
        
        let dateFormatter = ISO8601DateFormatter()
        let filename = "performance-metrics-\(dateFormatter.string(from: Date())).json"
        let fileURL = metricsDirectory.appendingPathComponent(filename)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metrics)
            try data.write(to: fileURL)
        } catch {
            os_log("Failed to persist metrics: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    private func loadPersistentMetrics() async {
        guard config.enablePersistence else { return }
        
        do {
            let metricFiles = try fileManager.contentsOfDirectory(
                at: metricsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ).filter { $0.pathExtension == "json" }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            for file in metricFiles.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).prefix(5) {
                let data = try Data(contentsOf: file)
                let loadedMetrics = try decoder.decode([PerformanceMetric].self, from: data)
                metrics.append(contentsOf: loadedMetrics)
            }
            
            // Maintain size limit
            if metrics.count > config.maxMetricsInMemory {
                metrics.removeFirst(metrics.count - config.maxMetricsInMemory)
            }
        } catch {
            os_log("Failed to load persistent metrics: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    // MARK: - Cleanup
    
    /// Clear metrics older than retention period
    func clearOldMetrics() {
        let cutoffDate = Date().addingTimeInterval(-Double(config.retentionDays) * 86400)
        metrics.removeAll { $0.timestamp < cutoffDate }
    }
    
    /// Clear all metrics
    func clearAll() {
        metrics.removeAll()
        performanceAlerts.removeAll()
    }
    
    deinit {
        persistenceTask?.cancel()
    }
}

// MARK: - Helper Extensions

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

// MARK: - TCA Integration

extension DependencyValues {
    var performanceMetrics: PerformanceMetrics {
        get { self[PerformanceMetricsKey.self] }
        set { self[PerformanceMetricsKey.self] = newValue }
    }
}

private struct PerformanceMetricsKey: DependencyKey {
    static let liveValue = PerformanceMetrics.shared
    static let testValue = PerformanceMetrics.shared
}
