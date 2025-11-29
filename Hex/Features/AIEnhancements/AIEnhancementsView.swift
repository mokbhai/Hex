import ComposableArchitecture
import HexCore
import Inject
import SwiftUI

struct AIEnhancementsView: View {
	@ObserveInjection var inject
	@Bindable var store: StoreOf<AIEnhancementsFeature>

	var body: some View {
		Form {
			// Select Text Hotkey Section
			Section {
				Label {
					VStack(alignment: .leading, spacing: 2) {
						Text("Select Text Hotkey")
							.font(.subheadline.weight(.semibold))
						Text("Assign a shortcut to replace selected text with a preset message.")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				} icon: {
					Image(systemName: "text.cursor")
				}

				let selectHotkey = store.hexSettings.selectTextHotkey

				let key = store.isSettingSelectTextHotkey ? nil : selectHotkey?.key
				let modifiers = store.isSettingSelectTextHotkey ? store.currentSelectTextModifiers : (selectHotkey?.modifiers ?? .init(modifiers: []))

				HStack {
					Spacer()
					ZStack {
						HotKeyView(modifiers: modifiers, key: key, isActive: store.isSettingSelectTextHotkey)

						if !store.isSettingSelectTextHotkey, selectHotkey == nil {
							Text("Not set")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
					.contentShape(Rectangle())
					.onTapGesture {
						store.send(.startSettingSelectTextHotkey)
					}
					Spacer()
				}

				if store.isSettingSelectTextHotkey {
					Text("Use at least one modifier (⌘, ⌥, ⇧, ⌃) plus a key.")
						.font(.caption)
						.foregroundStyle(.secondary)
				} else if selectHotkey != nil {
					Button {
						store.send(.clearSelectTextHotkey)
					} label: {
						Label("Clear shortcut", systemImage: "xmark.circle")
					}
					.buttonStyle(.borderless)
					.font(.caption)
					.foregroundStyle(.secondary)
				}
			} footer: {
				Text("When activated, this hotkey will replace the currently selected text with \"Hello world\".")
					.font(.footnote)
					.foregroundColor(.secondary)
			}

			// Additional AI Enhancements can be added here in the future
			Section {
				Label {
					VStack(alignment: .leading, spacing: 2) {
						Text("AI Enhancements")
							.font(.subheadline.weight(.semibold))
						Text("More AI-powered features coming soon.")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				} icon: {
					Image(systemName: "sparkles")
				}
			}
		}
		.formStyle(.grouped)
		.task {
			await store.send(.task).finish()
		}
		.enableInjection()
	}
}