import DontUnplugThatShared
import SwiftUI

struct ComponentStripView: View {
    let components: [GuideComponent]
    @Binding var selectedDisplayNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            HStack {
                Text("Components")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Text("Tap to edit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                HStack(spacing: AppTheme.compactSpacing) {
                    ForEach(components) { component in
                        ComponentChipView(
                            component: component,
                            selectedDisplayNumber: $selectedDisplayNumber
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
