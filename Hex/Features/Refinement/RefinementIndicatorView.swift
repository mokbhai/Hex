import Inject
import SwiftUI

struct RefinementIndicatorView: View {
  enum Status {
    case hidden
    case capturing
    case loadingModel
    case generating
    case pasting
    case error
  }

  @ObserveInjection var inject
  var status: Status

  private var labelText: String {
    switch status {
    case .hidden: return ""
    case .capturing: return "Capturing selection"
    case .loadingModel: return "Loading model"
    case .generating: return "Refining text"
    case .pasting: return "Replacing selection"
    case .error: return "Refinement failed"
    }
  }

  private var tint: Color {
    switch status {
    case .hidden: return .clear
    case .capturing: return .indigo
    case .loadingModel: return .blue
    case .generating: return .purple
    case .pasting: return .green
    case .error: return .red
    }
  }

  var body: some View {
    HStack(spacing: 8) {
      ProgressView()
        .tint(tint)
        .opacity(status == .hidden ? 0 : 1)
      Text(labelText)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      Capsule()
        .fill(tint.opacity(0.35))
        .shadow(color: tint.opacity(0.5), radius: 12)
    )
    .opacity(status == .hidden ? 0 : 1)
    .animation(.easeInOut(duration: 0.2), value: status)
    .enableInjection()
  }
}
