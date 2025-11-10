import SwiftUI

/// View for displaying calculator results
/// Shows calculation results and provides copy-to-clipboard functionality
///
/// Used by User Story 3: Voice Productivity Tools (T053)
struct CalculatorResultView: View {
    let result: Calculator.CalculationResult
    @State private var isCopied = false

    var body: some View {
        VStack(spacing: 16) {
            // Expression
            VStack(alignment: .leading, spacing: 4) {
                Text("Expression")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(result.expression)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }

            Divider()

            // Result
            VStack(alignment: .leading, spacing: 4) {
                Text("Result")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack {
                    Text(result.displayText)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)

                    Spacer()

                    Button(action: copyToClipboard) {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundColor(isCopied ? .green : .blue)
                    }
                    .help("Copy to clipboard")
                }
            }

            // Additional info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Value", systemImage: "number.square")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.10g", result.result))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                if result.result == Double(Int(result.result)) {
                    HStack {
                        Label("Integer", systemImage: "number.square.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(String(Int(result.result)))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func copyToClipboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result.displayText, forType: .string)
        #endif

        withAnimation {
            isCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isCopied = false
            }
        }
    }
}

/// Extended calculator view with history
struct CalculatorHistoryView: View {
    let results: [Calculator.CalculationResult]
    let onSelectResult: (Calculator.CalculationResult) -> Void

    var body: some View {
        List {
            ForEach(Array(results.enumerated()), id: \.element.expression) { index, result in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.expression)
                            .font(.system(size: 14, design: .monospaced))
                            .lineLimit(1)

                        Text("= \(result.displayText)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .onTapGesture {
                    onSelectResult(result)
                }
            }
        }
    }
}

/// Quick calculation suggestion view
struct CalculatorSuggestionView: View {
    let suggestions: [String]
    let onSelectSuggestion: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested Operations")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            Wrap(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: { onSelectSuggestion(suggestion) }) {
                        Text(suggestion)
                            .font(.system(size: 12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Wrap layout helper for flexible button layout
struct Wrap: Layout {
    let spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > (proposal.width ?? 0) && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(
            width: proposal.width ?? currentX,
            height: currentY + lineHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedSize(size)
            )

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    CalculatorResultView(
        result: Calculator.CalculationResult(
            expression: "25% of 250",
            result: 62.5
        )
    )
}
