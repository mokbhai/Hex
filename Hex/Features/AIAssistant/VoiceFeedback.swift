import Foundation
import AVFoundation
import ComposableArchitecture

/// Handles voice feedback and audio output for assistant responses
actor VoiceFeedback {
    enum VoiceFeedbackError: LocalizedError {
        case synthesisNotAvailable
        case playbackFailed(String)
        case invalidText
        case audioSessionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .synthesisNotAvailable:
                return "Text-to-speech synthesis is not available"
            case .playbackFailed(let reason):
                return "Audio playback failed: \(reason)"
            case .invalidText:
                return "Invalid text for voice synthesis"
            case .audioSessionFailed(let reason):
                return "Audio session configuration failed: \(reason)"
            }
        }
    }
    
    enum VoiceGender: String, CaseIterable, Codable {
        case male
        case female
        case neutral
    }
    
    struct VoiceSettings: Codable {
        var enabled: Bool = true
        var rate: Float = 0.5 // 0.0 to 1.0
        var pitch: Float = 1.0 // 0.5 to 2.0
        var volume: Float = 0.8 // 0.0 to 1.0
        var gender: VoiceGender = .female
        var language: String = "en-US"
    }
    
    private let synthesizer = AVSpeechSynthesizer()
    private var settings: VoiceSettings
    private let logger: ErrorLogger
    private let performanceMetrics: PerformanceMetrics
    
    init(
        settings: VoiceSettings = .init(),
        logger: ErrorLogger = ErrorLogger.shared,
        metrics: PerformanceMetrics = PerformanceMetrics.shared
    ) {
        self.settings = settings
        self.logger = logger
        self.performanceMetrics = metrics
        configureAudioSession()
    }
    
    // MARK: - Public Methods
    
    /// Speak the given text with current voice settings
    func speak(_ text: String) async throws {
        guard !text.isEmpty else {
            throw VoiceFeedbackError.invalidText
        }
        
        guard settings.enabled else {
            return
        }
        
        let timer = performanceMetrics.startMeasurement(label: "voice_synthesis")
        defer { timer.end() }
        
        do {
            try await synthesizeAndPlay(text)
        } catch {
            logger.logError(error, context: [
                "operation": "voice_speak",
                "text_length": text.count
            ])
            throw error
        }
    }
    
    /// Speak with custom rate and pitch
    func speak(_ text: String, rate: Float, pitch: Float) async throws {
        let originalRate = settings.rate
        let originalPitch = settings.pitch
        
        defer {
            settings.rate = originalRate
            settings.pitch = originalPitch
        }
        
        settings.rate = rate
        settings.pitch = pitch
        try await speak(text)
    }
    
    /// Stop current speech playback
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    /// Pause current speech
    func pauseSpeech() {
        synthesizer.pauseSpeaking(at: .word)
    }
    
    /// Resume paused speech
    func continueSpeech() {
        synthesizer.continueSpeaking()
    }
    
    /// Check if currently speaking
    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }
    
    /// Update voice settings
    func updateSettings(_ newSettings: VoiceSettings) {
        self.settings = newSettings
    }
    
    /// Play a system sound
    func playSystemSound(_ soundName: String) async throws {
        let timer = performanceMetrics.startMeasurement(label: "system_sound")
        defer { timer.end() }
        
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            throw VoiceFeedbackError.playbackFailed("Sound file not found: \(soundName)")
        }
        
        try await playAudio(from: soundURL)
    }
    
    /// Play notification sound
    func playNotificationSound() async throws {
        try await playSystemSound("notification")
    }
    
    /// Play success sound
    func playSuccessSound() async throws {
        try await playSystemSound("success")
    }
    
    /// Play error sound
    func playErrorSound() async throws {
        try await playSystemSound("error")
    }
    
    // MARK: - Private Methods
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.logError(error, context: ["operation": "configure_audio_session"])
        }
    }
    
    private func synthesizeAndPlay(_ text: String) async throws {
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * settings.rate
        utterance.pitchMultiplier = settings.pitch
        utterance.volume = settings.volume
        
        // Select appropriate voice
        if let voice = selectVoice(for: settings.gender, language: settings.language) {
            utterance.voice = voice
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = SpeechSynthesizerDelegate { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // Store delegate to keep it alive
            objc_setAssociatedObject(
                self.synthesizer,
                "delegate",
                delegate,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            
            synthesizer.delegate = delegate
            synthesizer.speak(utterance)
        }
    }
    
    private func playAudio(from url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = settings.volume
                
                let delegate = AudioPlayerDelegate { [weak player] success in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: VoiceFeedbackError.playbackFailed("Playback stopped"))
                    }
                }
                
                objc_setAssociatedObject(
                    player,
                    "delegate",
                    delegate,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                
                player.delegate = delegate
                player.play()
            } catch {
                continuation.resume(throwing: VoiceFeedbackError.playbackFailed(error.localizedDescription))
            }
        }
    }
    
    private func selectVoice(for gender: VoiceGender, language: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.contains(language.prefix(2))
        }
        
        switch gender {
        case .male:
            return voices.first(where: { $0.quality == .premium && $0.gender == .male })
                ?? voices.first(where: { $0.gender == .male })
                ?? voices.first
        case .female:
            return voices.first(where: { $0.quality == .premium && $0.gender == .female })
                ?? voices.first(where: { $0.gender == .female })
                ?? voices.first
        case .neutral:
            return voices.first(where: { $0.quality == .premium })
                ?? voices.first
        }
    }
}

// MARK: - Supporting Delegates

private class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    typealias CompletionHandler = (Result<Void, Error>) -> Void
    
    private let completion: CompletionHandler
    
    init(completion: @escaping CompletionHandler) {
        self.completion = completion
    }
    
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        completion(.success(()))
    }
    
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        completion(.failure(VoiceFeedback.VoiceFeedbackError.playbackFailed("Cancelled")))
    }
}

private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    typealias CompletionHandler = (Bool) -> Void
    
    private let completion: CompletionHandler
    
    init(completion: @escaping CompletionHandler) {
        self.completion = completion
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion(flag)
    }
}

// MARK: - TCA Integration

extension VoiceFeedback: DependencyKey {
    static let liveValue = VoiceFeedback()
    
    static let testValue = VoiceFeedback(
        settings: VoiceSettings(enabled: false),
        logger: ErrorLogger.testValue,
        metrics: PerformanceMetrics.testValue
    )
}

extension DependencyValues {
    var voiceFeedback: VoiceFeedback {
        get { self[VoiceFeedback.self] }
        set { self[VoiceFeedback.self] = newValue }
    }
}
