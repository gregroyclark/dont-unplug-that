import SwiftUI

struct AppHeaderView: View {
    let componentCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            Label("Editable demo", systemImage: "pencil.and.list.clipboard")
                .font(.subheadline)
                .bold()
                .foregroundStyle(AppTheme.accent)

            Text("Make the complicated setup simple.")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(AppTheme.ink)

            Text("Tap a numbered pin, then leave the next person exact startup, shutdown, and hands-off instructions.")
                .font(.body)
                .foregroundStyle(.secondary)

            Label("^[\(componentCount) component](inflect: true) mapped", systemImage: "checkmark.seal.fill")
                .font(.subheadline)
                .foregroundStyle(AppTheme.safe)
                .accessibilityLabel("\(componentCount) components mapped")
        }
    }
}
