import SkipKit
import SwiftUI

struct PhotoCaptureView: View {
    @Binding var photoURLs: [URL]
    @Binding var activePhotoIndex: Int

    @State var showsCamera = false
    @State var showsLibrary = false
    @State var capturedPhotoURL: URL?
    @State var pickedLibraryURLs: [URL] = []

    var canAddPhotos: Bool {
        photoURLs.count < 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4.0) {
                    Text("Photos")
                        .font(.title2)
                        .bold()
                    Text("Add up to three angles. Photo 1 is the best overview.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(photoURLs.count)/3")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(AppTheme.accent)
            }

            if !photoURLs.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: AppTheme.compactSpacing) {
                        ForEach(0..<photoURLs.count, id: \.self) { index in
                            Button {
                                activePhotoIndex = index
                            } label: {
                                SelectedPhotoView(url: photoURLs[index])
                                    .frame(width: 86.0, height: 64.0)
                                    .clipped()
                                    .clipShape(.rect(cornerRadius: 12.0))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12.0)
                                            .stroke(index == activePhotoIndex ? AppTheme.accent : .clear, lineWidth: 3.0)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Photo \(index + 1) of \(photoURLs.count)")
                            .accessibilityValue(index == activePhotoIndex ? "Selected" : "Not selected")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            HStack(spacing: AppTheme.compactSpacing) {
                Button {
                    showsCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity, minHeight: 44.0)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAddPhotos)
                .withMediaPicker(
                    type: .camera,
                    isPresented: $showsCamera,
                    selectedImageURL: $capturedPhotoURL
                )

                Button {
                    showsLibrary = true
                } label: {
                    Label("Choose", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity, minHeight: 44.0)
                }
                .buttonStyle(.bordered)
                .disabled(!canAddPhotos)
                .withMediaPicker(
                    type: .library,
                    isPresented: $showsLibrary,
                    allowsMultipleSelection: true,
                    selectedImageURLs: $pickedLibraryURLs
                )
            }

            if !photoURLs.isEmpty {
                Button(role: .destructive) {
                    removeActivePhoto()
                } label: {
                    Label("Remove selected photo", systemImage: "trash")
                        .frame(minHeight: 44.0)
                }
                .buttonStyle(.plain)
            }

            Label("Photos are analyzed on this device.", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
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
        guard photoURLs.indices.contains(activePhotoIndex) else {
            return
        }
        photoURLs.remove(at: activePhotoIndex)
        activePhotoIndex = min(activePhotoIndex, max(0, photoURLs.count - 1))
    }
}
