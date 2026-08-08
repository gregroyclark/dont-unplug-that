import DontUnplugThatShared
import SwiftUI

struct ComponentChipView: View {
    let component: GuideComponent
    @Binding var selectedDisplayNumber: Int

    var isSelected: Bool {
        selectedDisplayNumber == component.displayNumber
    }

    var body: some View {
        Button(action: selectComponent) {
            HStack(spacing: AppTheme.compactSpacing) {
                Text(component.displayNumber, format: .number)
                    .bold()
                    .foregroundStyle(isSelected ? .white : AppTheme.accent)
                    .frame(width: 32.0, height: 32.0)
                    .background(isSelected ? AppTheme.accent : AppTheme.accentSoft)
                    .clipShape(.circle)

                Text(component.name)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppTheme.standardSpacing)
            .frame(minHeight: 48.0)
            .background(isSelected ? AppTheme.cardBackground : .white.opacity(0.62))
            .clipShape(.capsule)
            .overlay {
                Capsule()
                    .stroke(isSelected ? AppTheme.accent : .clear, lineWidth: 2.0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Component \(component.displayNumber), \(component.name)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    func selectComponent() {
        selectedDisplayNumber = component.displayNumber
    }
}
