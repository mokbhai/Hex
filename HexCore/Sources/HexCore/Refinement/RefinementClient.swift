import Dependencies
import DependenciesMacros
import Foundation
#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
import MLXNN
#endif

private let refinementLogger = HexLog.refinement

public struct RefinementParameters: Equatable, Sendable {
  public var temperature: Double
  public var topP: Double
  public var maxTokens: Int
  public var systemPrompt: String

  public init(
    temperature: Double = 0.7,
    topP: Double = 0.9,
    maxTokens: Int = 512,
    systemPrompt: String = RefinementParameters.defaultSystemPrompt
  ) {
    self.temperature = temperature
    self.topP = topP
    self.maxTokens = maxTokens
    self.systemPrompt = systemPrompt
  }

  public static let defaultSystemPrompt: String = """
  Fix the grammar, improve clarity, and correct typos in the following text. Preserve the original meaning and tone. Return only the corrected text without any explanation.\n\nText: {input}
  """
}

@DependencyClient
public struct RefinementClient: Sendable {
  public var refine: @Sendable (
    _ text: String,
    _ modelIdentifier: String,
    _ parameters: RefinementParameters
  ) async throws -> String

  public var isModelAvailable: @Sendable (_ modelIdentifier: String) async -> Bool = { _ in false }
  public var cancel: @Sendable () async -> Void
}

extension RefinementClient: DependencyKey {
  public static var liveValue: RefinementClient {
    let live = RefinementClientLive()
    return RefinementClient(
      refine: { text, modelIdentifier, parameters in
        try await live.refine(text: text, modelIdentifier: modelIdentifier, parameters: parameters)
      },
      isModelAvailable: { modelIdentifier in
        await live.isModelAvailable(modelIdentifier: modelIdentifier)
      },
      cancel: {
        await live.cancel()
      }
    )
  }
}

public extension DependencyValues {
  var refinement: RefinementClient {
    get { self[RefinementClient.self] }
    set { self[RefinementClient.self] = newValue }
  }
}

actor RefinementClientLive {
  private var currentTask: Task<String, Error>?

  func refine(text: String, modelIdentifier: String, parameters: RefinementParameters) async throws -> String {
    cancel()

    currentTask = Task { @Sendable in
      refinementLogger.notice("Starting refinement model=\(modelIdentifier, privacy: .public) length=\(text.count)")

      let prompt = parameters.systemPrompt.replacingOccurrences(of: "{input}", with: text)

      // Placeholder implementation: echo input while wiring MLX dependency.
      // This keeps the flow working while the MLX-backed generator is integrated.
      // TODO: Replace with actual MLX text generation pipeline.
      let refinedText = try await runLocalRefinement(
        prompt: prompt,
        modelIdentifier: modelIdentifier,
        parameters: parameters
      )

      refinementLogger.notice("Refinement complete length=\(refinedText.count)")
      return refinedText
    }

    guard let currentTask else {
      throw CancellationError()
    }

    do {
      let result = try await currentTask.value
      return result
    } catch {
      refinementLogger.error("Refinement failed: \(error.localizedDescription)")
      throw error
    }
  }

  func isModelAvailable(modelIdentifier: String) async -> Bool {
    // Simple availability detection: check if model directory exists in Application Support/Hex/models/llm/<id>
    // Model download pipeline should populate this path.
    let supportURL: URL
    do {
      supportURL = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      )
    } catch {
      refinementLogger.error("Unable to locate Application Support: \(error.localizedDescription)")
      return false
    }

    let modelPath = supportURL
      .appendingPathComponent("com.kitlangton.Hex/models/llm", isDirectory: true)
      .appendingPathComponent(modelIdentifier)

    return FileManager.default.fileExists(atPath: modelPath.path)
  }

  func cancel() {
    currentTask?.cancel()
    currentTask = nil
  }

  private func runLocalRefinement(
    prompt: String,
    modelIdentifier: String,
    parameters: RefinementParameters
  ) async throws -> String {
    // TODO: Wire up MLX text generation. For now, return the input portion after the template.
    // This keeps the flow non-blocking and ensures UI integration compiles.
    #if canImport(MLXLM)
    _ = modelIdentifier
    _ = parameters
    #endif

    // Extract the last line as a lightweight placeholder output.
    let lines = prompt.components(separatedBy: "\n")
    if let last = lines.last, !last.isEmpty {
      return last.replacingOccurrences(of: "Text: ", with: "")
    }
    return prompt
  }
}
