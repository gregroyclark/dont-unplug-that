import DontUnplugThatShared
import SwiftUI

struct ComponentExplanationView: View {
    let component: GuideComponent
    @State var showsUnpluggingImpact = false

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

                VStack(alignment: .leading, spacing: 4.0) {
                    Label(
                        component.kind == .connection ? "Connection" : "Component",
                        systemImage: component.kind == .connection ? "cable.connector" : "shippingbox.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text(component.name)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(AppTheme.ink)
                }
            }

            explanationSection(
                title: "Likely purpose",
                systemImage: "lightbulb.fill",
                tint: AppTheme.safe,
                text: component.likelyPurpose
            )

            explanationSection(
                title: "Evidence: \(evidenceTitle)",
                systemImage: evidenceSystemImage,
                tint: evidenceTint,
                text: component.uncertaintyNotes
            )

            safetySection

            Button {
                showsUnpluggingImpact.toggle()
            } label: {
                Label(
                    showsUnpluggingImpact ? "Hide unplugging impact" : "What happens if I unplug this?",
                    systemImage: "powerplug.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48.0)
            }
            .buttonStyle(.borderedProminent)

            if showsUnpluggingImpact {
                explanationSection(
                    title: "Likely impact",
                    systemImage: "arrow.triangle.branch",
                    tint: AppTheme.accent,
                    text: component.unpluggingImpact
                )
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.accentSoft, lineWidth: 1.0)
        }
    }

    @ViewBuilder func explanationSection(
        title: String,
        systemImage: String,
        tint: Color,
        text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.ink)
        }
    }

    @ViewBuilder var safetySection: some View {
        if let warning = component.safetyWarning {
            explanationSection(
                title: "Don't unplug yet",
                systemImage: "hand.raised.fill",
                tint: AppTheme.warning,
                text: warning
            )
            .padding(AppTheme.standardSpacing)
            .background(AppTheme.accentSoft.opacity(0.72))
            .clipShape(.rect(cornerRadius: 14.0))
        } else {
            explanationSection(
                title: "Safety limit",
                systemImage: "exclamationmark.shield.fill",
                tint: AppTheme.warning,
                text: "No specific hazard is visible, but a photo cannot prove that this connection is safe to change."
            )
        }
    }

    var evidenceTitle: String {
        switch component.evidenceLevel {
        case .observed: "Observed"
        case .inferred: "Inferred"
        case .unclear: "Unclear"
        }
    }

    var evidenceSystemImage: String {
        switch component.evidenceLevel {
        case .observed: "eye.fill"
        case .inferred: "sparkles"
        case .unclear: "questionmark.diamond.fill"
        }
    }

    var evidenceTint: Color {
        switch component.evidenceLevel {
        case .observed: AppTheme.safe
        case .inferred: AppTheme.accent
        case .unclear: AppTheme.warning
        }
    }
}
