import DontUnplugThatShared
import SwiftUI

struct AnnotationPinView: View {
    let component: GuideComponent
    @Binding var selectedDisplayNumber: Int

    var isSelected: Bool {
        selectedDisplayNumber == component.displayNumber
    }

    var body: some View {
        Button(action: selectComponent) {
            Text(component.displayNumber, format: .number)
                .font(.headline)
                .bold()
                .foregroundStyle(isSelected ? .white : AppTheme.ink)
                .frame(width: 44.0, height: 44.0)
                .background(isSelected ? AppTheme.accent : .white)
                .clipShape(.circle)
                .overlay {
                    Circle()
                        .stroke(isSelected ? .white : AppTheme.accent, lineWidth: isSelected ? 3.0 : 2.0)
                }
                .shadow(color: .black.opacity(0.34), radius: 5.0, y: 2.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Component \(component.displayNumber), \(component.name)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Shows this component's instructions")
    }

    func selectComponent() {
        selectedDisplayNumber = component.displayNumber
    }
}
