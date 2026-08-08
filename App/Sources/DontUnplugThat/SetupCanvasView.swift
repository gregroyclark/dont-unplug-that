import DontUnplugThatShared
import SwiftUI

struct SetupCanvasView: View {
    let components: [GuideComponent]
    @Binding var selectedDisplayNumber: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                EquipmentPlaceholderView()

                ForEach(components) { component in
                    AnnotationPinView(
                        component: component,
                        selectedDisplayNumber: $selectedDisplayNumber
                    )
                    .position(
                        x: clamped(component.location.x) * geometry.size.width,
                        y: clamped(component.location.y) * geometry.size.height
                    )
                }
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .background(AppTheme.canvas)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(.white.opacity(0.14), lineWidth: 1.0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Annotated equipment setup")
    }

    func clamped(_ coordinate: Double) -> Double {
        min(max(coordinate, 0.0), 1.0)
    }
}
