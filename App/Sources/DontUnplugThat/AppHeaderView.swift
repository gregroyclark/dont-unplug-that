import SwiftUI

struct AppHeaderView: View {
    let itemCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            Text(itemCount == nil ? "What are we\nlooking at?" : "Your setup, explained.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(itemCount == nil
                 ? "Start with a photo. We’ll help you make sense of it."
                 : "Tap a numbered item to understand its part in the picture.")
                .font(.body)
                .foregroundStyle(AppTheme.secondaryInk)

            if let itemCount {
                Label("^[\(itemCount) item](inflect: true) found", systemImage: "viewfinder")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityLabel("\(itemCount) items found")
            }
        }
    }
}
