import ComposableArchitecture
import HexCore
import Inject
import SwiftUI

struct RefinementHotKeyView: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<SettingsFeature>

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Refinement hotkey", systemImage: "wand.and.stars")
        .font(.headline)

      HStack {
        Spacer()
        HotKeyView(
          modifiers: store.isSettingRefinementHotkey ? store.currentRefinementModifiers : (store.hexSettings.refinementHotkey?.modifiers ?? []),
          key: store.isSettingRefinementHotkey ? nil : store.hexSettings.refinementHotkey?.key,
          isActive: store.isSettingRefinementHotkey
        )
        .onTapGesture {
          store.send(.startSettingRefinementHotkey)
        }
        Spacer()
      }

      HStack {
        Button("Set hotkey") {
          store.send(.startSettingRefinementHotkey)
        }
        .buttonStyle(.borderedProminent)

        Button("Clear") {
          store.send(.clearRefinementHotkey)
        }
        .buttonStyle(.bordered)
        .disabled(store.hexSettings.refinementHotkey == nil)

        Spacer()
      }
      .font(.subheadline)

      Text("Press the hotkey to capture the current selection and refine it locally.")
        .settingsCaption()
    }
    .contentShape(Rectangle())
    .enableInjection()
  }
}
