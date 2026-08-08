import DontUnplugThatShared
import SwiftUI

struct InstructionEditorView: View {
    @Binding var component: GuideComponent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
            HStack(spacing: AppTheme.standardSpacing) {
                Text(component.displayNumber, format: .number)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .frame(width: 48.0, height: 48.0)
                    .background(AppTheme.accent)
                    .clipShape(.circle)

                VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
                    Text("Selected component")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Component name", text: $component.name)
                        .font(.title2)
                        .bold()
                        .textFieldStyle(.roundedBorder)
                }
            }

            Divider()

            InstructionFieldView(
                title: "Startup",
                systemImage: "power",
                tint: AppTheme.safe,
                placeholder: "What should happen, and in what order?",
                text: $component.startupInstructions
            )

            InstructionFieldView(
                title: "Shutdown",
                systemImage: "moon.zzz.fill",
                tint: AppTheme.accent,
                placeholder: "How should this be turned off safely?",
                text: $component.shutdownInstructions
            )

            InstructionFieldView(
                title: "Never touch this",
                systemImage: "hand.raised.fill",
                tint: AppTheme.warning,
                placeholder: "What must stay connected or unchanged?",
                text: $component.neverTouchInstructions
            )
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.accentSoft, lineWidth: 1.0)
        }
    }
}
