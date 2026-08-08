import SwiftUI

struct EquipmentPlaceholderView: View {
    var body: some View {
        VStack(spacing: AppTheme.standardSpacing) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
            Text("Add a clear photo of the setup")
                .font(.headline)
            Text("Include labels and both ends of important cables when possible.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.78))
        .padding(AppTheme.sectionSpacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvas)
    }
}
