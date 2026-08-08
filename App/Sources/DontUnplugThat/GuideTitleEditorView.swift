import SwiftUI

struct GuideTitleEditorView: View {
    @Binding var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
            Label("Guide name", systemImage: "tag")
                .font(.subheadline)
                .bold()
                .foregroundStyle(.secondary)

            TextField("Name this setup", text: $title)
                .font(.title3)
                .bold()
                .textFieldStyle(.roundedBorder)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
    }
}
