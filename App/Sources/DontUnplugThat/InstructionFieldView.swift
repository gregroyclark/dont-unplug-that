import SwiftUI

struct InstructionFieldView: View {
    let title: String
    let systemImage: String
    let tint: Color
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
        }
    }
}
