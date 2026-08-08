import DontUnplugThatShared
import SwiftUI

struct SetupCanvasView: View {
    let photoURL: URL?
    let components: [GuideComponent]
    @Binding var selectedDisplayNumber: Int
    @State var photoAspectRatio = SelectedPhotoMetadata.fallbackAspectRatio

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SelectedPhotoView(url: photoURL)

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
        .aspectRatio(photoAspectRatio, contentMode: .fit)
        .background(AppTheme.canvas)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(.white.opacity(0.14), lineWidth: 1.0)
        }
        .accessibilityLabel("Annotated equipment setup")
        .task(id: photoURL) {
            photoAspectRatio = await SelectedPhotoMetadata.aspectRatio(for: photoURL)
        }
    }

    func clamped(_ coordinate: Double) -> Double {
        min(max(coordinate, 0.0), 1.0)
    }
}
