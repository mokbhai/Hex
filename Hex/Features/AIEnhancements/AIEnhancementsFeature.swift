import ComposableArchitecture
import HexCore

@Reducer
struct AIEnhancementsFeature {
  @ObservableState
  struct State {
    @Shared(.hexSettings) var hexSettings: HexSettings
    @Shared(.isSettingSelectTextHotkey) var isSettingSelectTextHotkey: Bool = false
    var currentSelectTextModifiers: Modifiers = .init(modifiers: [])
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case startSettingSelectTextHotkey
    case clearSelectTextHotkey
    case keyEvent(KeyEvent)
    case task
  }

  @Dependency(\.keyEventMonitor) var keyEventMonitor

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        return .run { send in
          // Listen for key events to enable hotkey setting
          for try await keyEvent in await keyEventMonitor.listenForKeyPress() {
            await send(.keyEvent(keyEvent))
          }
        }

      case .startSettingSelectTextHotkey:
        state.$isSettingSelectTextHotkey.withLock { $0 = true }
        state.currentSelectTextModifiers = .init(modifiers: [])
        return .none

      case .clearSelectTextHotkey:
        state.$hexSettings.withLock { $0.selectTextHotkey = nil }
        return .none

  
      case let .keyEvent(keyEvent):
        guard state.isSettingSelectTextHotkey else { return .none }

        if keyEvent.key == .escape {
          state.$isSettingSelectTextHotkey.withLock { $0 = false }
          state.currentSelectTextModifiers = []
          return .none
        }

        state.currentSelectTextModifiers = keyEvent.modifiers.union(state.currentSelectTextModifiers)
        let currentModifiers = state.currentSelectTextModifiers
        if let key = keyEvent.key {
          guard !currentModifiers.isEmpty else {
            return .none
          }
          state.$hexSettings.withLock {
            $0.selectTextHotkey = HotKey(key: key, modifiers: currentModifiers.erasingSides())
          }
          state.$isSettingSelectTextHotkey.withLock { $0 = false }
          state.currentSelectTextModifiers = []
        }
        return .none
      }
    }
  }
}