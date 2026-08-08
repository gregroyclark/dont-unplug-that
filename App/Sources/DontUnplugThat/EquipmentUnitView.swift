import SwiftUI

struct EquipmentUnitView: View {
    let label: String
    let indicatorCount: Int

    var body: some View {
        HStack(spacing: AppTheme.compactSpacing) {
            Text(label)
                .font(.caption)
                .bold()
                .foregroundStyle(.white.opacity(0.62))

            Spacer()

            ForEach(0..<indicatorCount, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 3) ? AppTheme.accent : AppTheme.safe)
                    .frame(width: 6.0, height: 6.0)
            }
        }
        .padding(.horizontal, AppTheme.standardSpacing)
        .frame(maxWidth: .infinity, minHeight: 42.0)
        .background(Color(red: 0.20, green: 0.21, blue: 0.22))
        .clipShape(.rect(cornerRadius: 8.0))
    }
}
