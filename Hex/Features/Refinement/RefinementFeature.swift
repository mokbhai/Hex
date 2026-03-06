import ComposableArchitecture
import Foundation
import HexCore
import Inject
import SwiftUI

private let refinementFeatureLogger = HexLog.refinement

@Reducer
struct RefinementFeature {
  @ObservableState
  struct State {
    enum Status: Equatable {
      case idle
      case capturingText
      case loadingModel
      case generating
      case pasting
      case error(String)
    }

    var status: Status = .idle
    var capturedText: String?
    var refinedText: String?
    @Shared(.hexSettings) var hexSettings: HexSettings
  }

  enum Action {
    case hotkeyTriggered
    case captureCompleted(String?)
    case startGeneration(String)
    case refinementFinished(String)
    case replaceFinished
    case failed(String)
    case cancel
  }

  @Dependency(\.refinement) var refinement
  @Dependency(\.accessibilityCapture) var accessibilityCapture
  @Dependency(\.pasteboard) var pasteboard

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .hotkeyTriggered:
        guard state.hexSettings.refinementEnabled else {
          refinementFeatureLogger.notice("Refinement hotkey ignored because feature disabled")
          return .none
        }
        state.status = .capturingText
        state.capturedText = nil
        state.refinedText = nil
        return .run { send in
          do {
            let captured = try await accessibilityCapture.captureSelectedText()
            await send(.captureCompleted(captured))
          } catch {
            await send(.failed(error.localizedDescription))
          }
        }

      case let .captureCompleted(text):
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          return .send(.failed("No selected text to refine."))
        }
        state.capturedText = text
        state.status = .loadingModel
        return .send(.startGeneration(text))

      case let .startGeneration(text):
        state.status = .generating
        let parameters = RefinementParameters(
          temperature: state.hexSettings.refinementTemperature,
          topP: state.hexSettings.refinementTopP,
          maxTokens: state.hexSettings.refinementMaxTokens
        )
        let modelIdentifier = state.hexSettings.refinementModelIdentifier ?? HexSettings().refinementModelIdentifier ?? ""
        return .run { send in
          do {
            let refined = try await refinement.refine(text, modelIdentifier, parameters)
            await send(.refinementFinished(refined))
          } catch {
            await send(.failed(error.localizedDescription))
          }
        }

      case let .refinementFinished(output):
        state.refinedText = output
        state.status = .pasting
        return .run { send in
          do {
            try await accessibilityCapture.replaceSelectedText(output)
          } catch {
            // Fallback: copy and paste via keyboard command
            await pasteboard.copy(output)
            await pasteboard.sendKeyboardCommand(.init(key: .v, modifiers: [.command]))
          }
          await send(.replaceFinished)
        }

      case .replaceFinished:
        state.status = .idle
        return .none

      case let .failed(message):
        state.status = .error(message)
        refinementFeatureLogger.error("Refinement failed: \(message, privacy: .public)")
        return .none

      case .cancel:
        state.status = .idle
        return .run { _ in
          await refinement.cancel()
        }
      }
    }
  }
}

struct RefinementView: View {
  @Bindable var store: StoreOf<RefinementFeature>
  @ObserveInjection var inject

  var body: some View {
    RefinementIndicatorView(status: indicatorStatus)
      .task {
        // No startup work needed yet
      }
      .enableInjection()
  }

  private var indicatorStatus: RefinementIndicatorView.Status {
    switch store.status {
    case .idle:
      return .hidden
    case .capturingText:
      return .capturing
    case .loadingModel:
      return .loadingModel
    case .generating:
      return .generating
    case .pasting:
      return .pasting
    case .error:
      return .error
    }
  }
}
