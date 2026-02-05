import ComposableArchitecture
import HexCore
import Inject
import SwiftUI

struct RefinementModelView: View {
  @ObserveInjection var inject
  @Bindable var store: StoreOf<SettingsFeature>

  private var modelBinding: Binding<String> {
    Binding<String>(
      get: { store.hexSettings.refinementModelIdentifier ?? "" },
      set: { newValue in
        store.hexSettings.refinementModelIdentifier = newValue.isEmpty ? nil : newValue
      }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Refinement model", systemImage: "shippingbox")
        .font(.headline)

      TextField("Hugging Face model id (e.g. mlx-community/phi-3-mini-4k-instruct)", text: modelBinding)
        .textFieldStyle(.roundedBorder)

      Text("Models download to Library/Application Support/com.kitlangton.Hex/models/llm.")
        .settingsCaption()
    }
    .enableInjection()
  }
}
