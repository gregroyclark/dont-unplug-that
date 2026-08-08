import SwiftUI

struct EquipmentPlaceholderView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.16, blue: 0.18),
                    AppTheme.canvas,
                    Color(red: 0.10, green: 0.07, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: AppTheme.standardSpacing) {
                VStack(spacing: AppTheme.compactSpacing) {
                    EquipmentUnitView(label: "POWER", indicatorCount: 3)
                    EquipmentUnitView(label: "AUDIO", indicatorCount: 5)
                    EquipmentUnitView(label: "NETWORK", indicatorCount: 7)
                    EquipmentUnitView(label: "BACKUP", indicatorCount: 4)
                }

                VStack(spacing: AppTheme.standardSpacing) {
                    RoundedRectangle(cornerRadius: 14.0)
                        .fill(Color(red: 0.19, green: 0.20, blue: 0.22))
                        .overlay {
                            Image(systemName: "desktopcomputer")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.64))
                        }

                    RoundedRectangle(cornerRadius: 14.0)
                        .fill(Color(red: 0.12, green: 0.13, blue: 0.14))
                        .overlay {
                            VStack(spacing: AppTheme.compactSpacing) {
                                Image(systemName: "cable.connector")
                                Text("SIGNAL")
                                    .font(.caption)
                                    .bold()
                            }
                            .foregroundStyle(.white.opacity(0.58))
                        }
                }
                .frame(maxWidth: 112.0)
            }
            .padding(AppTheme.sectionSpacing)

            VStack {
                HStack {
                    Spacer()
                    Label("Demo setup", systemImage: "photo")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppTheme.standardSpacing)
                        .padding(.vertical, AppTheme.compactSpacing)
                        .background(.black.opacity(0.52))
                        .clipShape(.capsule)
                }
                Spacer()
            }
            .padding(AppTheme.standardSpacing)
        }
        .accessibilityHidden(true)
    }
}
