import SwiftUI

struct AppHeaderView: View {
    let itemCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            Label("Private on-device analysis", systemImage: "lock.shield.fill")
                .font(.subheadline)
                .bold()
                .foregroundStyle(AppTheme.accent)

            Text("Understand what you're looking at.")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(AppTheme.ink)

            Text("Photograph an unfamiliar setup. We'll explain what each part likely does and what may stop if it is disconnected.")
                .font(.body)
                .foregroundStyle(.secondary)

            if let itemCount {
                Label("^[\(itemCount) item](inflect: true) found", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.safe)
                    .accessibilityLabel("\(itemCount) items found")
            }
        }
    }
}
