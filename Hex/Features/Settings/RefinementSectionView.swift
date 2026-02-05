import ComposableArchitecture
import HexCore
import Inject
import SwiftUI

struct RefinementSectionView: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<SettingsFeature>

  var body: some View {
    Section("Refinement") {
      Toggle("Enable refinement", isOn: $store.hexSettings.refinementEnabled)

      Toggle("Auto-refine transcriptions", isOn: $store.hexSettings.autoRefineTranscriptions)
        .disabled(!store.hexSettings.refinementEnabled)

      if store.hexSettings.refinementEnabled {
        Text("Runs the selected text through a local LLM and replaces it in-place.")
          .settingsCaption()
      }

      RefinementHotKeyView(store: store)
        .disabled(!store.hexSettings.refinementEnabled)

      RefinementModelView(store: store)
        .disabled(!store.hexSettings.refinementEnabled)

      refinementParameterControls
        .disabled(!store.hexSettings.refinementEnabled)
    }
    .enableInjection()
  }

  private var refinementParameterControls: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Temperature")
          Spacer()
          Text(String(format: "%.2f", store.hexSettings.refinementTemperature))
            .foregroundStyle(.secondary)
        }
        Slider(value: $store.hexSettings.refinementTemperature, in: 0...1, step: 0.05)
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Top-p")
          Spacer()
          Text(String(format: "%.2f", store.hexSettings.refinementTopP))
            .foregroundStyle(.secondary)
        }
        Slider(value: $store.hexSettings.refinementTopP, in: 0...1, step: 0.05)
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Max tokens")
          Spacer()
          Text("\(store.hexSettings.refinementMaxTokens)")
            .foregroundStyle(.secondary)
        }
        Stepper(value: $store.hexSettings.refinementMaxTokens, in: 64...4096, step: 64) {
          EmptyView()
        }
      }
    }
  }
}
