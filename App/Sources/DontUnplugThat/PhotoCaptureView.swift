import SkipKit
import SwiftUI

struct PhotoCaptureView: View {
    @Binding var photoURLs: [URL]
    @Binding var activePhotoIndex: Int

    @State var showsCamera = false
    @State var showsLibrary = false
    @State var capturedPhotoURL: URL?
    @State var pickedLibraryURLs: [URL] = []

    var canAddPhotos: Bool { photoURLs.count < 3 }

    private func photoThumbnail(at index: Int) -> some View {
        let label = "Photo " + String(index + 1) + " of " + String(photoURLs.count)
        return Button {
            activePhotoIndex = index
        } label: {
            SelectedPhotoView(url: photoURLs[index])
                .frame(width: 86.0, height: 64.0)
                .clipped()
                .clipShape(.rect(cornerRadius: 10.0))
                .overlay {
                    RoundedRectangle(cornerRadius: 10.0)
                        .stroke(index == activePhotoIndex ? AppTheme.accent : .clear, lineWidth: 3.0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityValue(index == activePhotoIndex ? "Selected" : "Not selected")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            if photoURLs.isEmpty {
                Image("WelcomeSetup", bundle: .module)
                    .resizable()
                    .aspectRatio(1.25, contentMode: .fit)
                    .overlay(alignment: .top) {
                        Text("Example setup")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                            .padding(.top, 18.0)
                    }
                    .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
                    .accessibilityLabel("Example setup: a speaker, a plant, and a cable")
            } else {
                HStack {
                    Text("Your photos")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Spacer()
                    Text("\(photoURLs.count) of 3")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: AppTheme.standardSpacing) {
                        ForEach(0..<photoURLs.count, id: \.self) { index in
                            photoThumbnail(at: index)
                        }
                    }
                    .padding(3.0)
                }
                .scrollIndicators(.hidden)
            }

            Button { showsCamera = true } label: {
                AppLabel(photoURLs.isEmpty ? "Take a photo" : "Add another angle", systemImage: "camera")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 44.0)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            #if !os(Android)
            .buttonBorderShape(.roundedRectangle(radius: 10.0))
            #endif
            .disabled(!canAddPhotos)
            .withMediaPicker(type: .camera, isPresented: $showsCamera, selectedImageURL: $capturedPhotoURL)

            Button { showsLibrary = true } label: {
                AppLabel("Choose photos", systemImage: "photo.on.rectangle")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 44.0)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canAddPhotos ? AppTheme.accent : AppTheme.secondaryInk)
            .disabled(!canAddPhotos)
            .withMediaPicker(type: .library, isPresented: $showsLibrary,
                             allowsMultipleSelection: true, selectedImageURLs: $pickedLibraryURLs)

            Text(canAddPhotos ? "Up to 3 angles. Analyzed on this device." : "All 3 angles added. Ready to analyze.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if !photoURLs.isEmpty {
                Button(role: .destructive) { removeActivePhoto() } label: {
                    AppLabel("Remove selected photo", systemImage: "trash")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, minHeight: 44.0)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(AppTheme.ink)
        .onChange(of: capturedPhotoURL) { newURL in
            if let newURL {
                appendPhotos([newURL])
                capturedPhotoURL = nil
            }
        }
        .onChange(of: pickedLibraryURLs) { newURLs in
            if !newURLs.isEmpty {
                appendPhotos(newURLs)
                pickedLibraryURLs = []
            }
        }
    }

    func appendPhotos(_ newURLs: [URL]) {
        let remainingCount = max(0, 3 - photoURLs.count)
        photoURLs.append(contentsOf: newURLs.prefix(remainingCount))
        activePhotoIndex = max(0, photoURLs.count - 1)
    }

    func removeActivePhoto() {
        guard photoURLs.indices.contains(activePhotoIndex) else { return }
        photoURLs.remove(at: activePhotoIndex)
        activePhotoIndex = min(activePhotoIndex, max(0, photoURLs.count - 1))
    }
}
