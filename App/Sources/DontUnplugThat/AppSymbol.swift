import SwiftUI

/// Use the website's Phosphor assets where SF Symbols are unavailable.
struct AppSymbol: View {
    let systemName: String

    var body: some View {
        #if os(Android)
        Image(systemName, bundle: .module)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24.0, height: 24.0)
            .accessibilityHidden(true)
        #else
        Image(systemName: systemName)
        #endif
    }
}

struct AppLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            AppSymbol(systemName: systemImage)
        }
    }
}
