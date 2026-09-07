import SwiftUI

struct EquipmentPlaceholderView: View {
    var body: some View {
        VStack(spacing: AppTheme.standardSpacing) {
            Image(systemName: "photo")
                .font(.largeTitle)
            Text("Add a clear photo of the setup")
                .font(.headline)
            Text("Include labels and both ends of important cables when possible.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(AppTheme.secondaryInk)
        .padding(AppTheme.sectionSpacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvas)
    }
}
