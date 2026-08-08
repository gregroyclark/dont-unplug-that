import DontUnplugThatShared
import SwiftUI

struct ContentView: View {
    @State var photoURLs: [URL] = []
    @State var activePhotoIndex = 0
    @State var guide: Guide?
    @State var selectedDisplayNumber = 1
    @State var analysisAvailability = AnalysisAvailability.checking
    @State var isWorking = false
    @State var errorMessage: String?

    var selectedComponent: GuideComponent? {
        guide?.components.first { component in
            component.displayNumber == selectedDisplayNumber
        }
    }

    var activePhotoComponents: [GuideComponent] {
        guide?.components.filter { component in
            component.photoIndex == activePhotoIndex
        } ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    AppHeaderView(itemCount: guide?.components.count)

                    PhotoCaptureView(
                        photoURLs: $photoURLs,
                        activePhotoIndex: $activePhotoIndex
                    )

                    SetupCanvasView(
                        photoURL: activePhotoURL,
                        components: activePhotoComponents,
                        selectedDisplayNumber: $selectedDisplayNumber
                    )

                    if !photoURLs.isEmpty {
                        Text("Photo \(activePhotoIndex + 1) of \(photoURLs.count)")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        analysisControls
                    }

                    if let guide {
                        guideSummary(guide)

                        ComponentStripView(
                            components: guide.components,
                            selectedDisplayNumber: $selectedDisplayNumber,
                            activePhotoIndex: $activePhotoIndex
                        )

                        if let selectedComponent {
                            ComponentExplanationView(component: selectedComponent)
                                .id(selectedComponent.id)
                        }
                    }
                }
                .padding(AppTheme.pagePadding)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle("Don't Unplug That")
        }
        .tint(AppTheme.accent)
        .task {
            await refreshAvailability()
        }
        .onChange(of: photoURLs) { _ in
            guide = nil
            errorMessage = nil
            if activePhotoIndex >= photoURLs.count {
                activePhotoIndex = max(0, photoURLs.count - 1)
            }
        }
    }

    var activePhotoURL: URL? {
        guard photoURLs.indices.contains(activePhotoIndex) else {
            return nil
        }
        return photoURLs[activePhotoIndex]
    }

    @ViewBuilder var analysisControls: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            if analysisAvailability != .available {
                Label(analysisAvailability.title, systemImage: analysisAvailability.systemImage)
                    .font(.headline)
                    .foregroundStyle(analysisAvailability == .unavailable ? AppTheme.warning : AppTheme.accent)

                Text(analysisAvailability.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.warning)
                    .accessibilityLabel("Analysis error. \(errorMessage)")
            }

            Button(action: performPrimaryAction) {
                HStack {
                    if isWorking {
                        ProgressView()
                            .tint(.white)
                    }
                    Label(primaryActionTitle, systemImage: "sparkles")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 50.0)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorking || !canPerformPrimaryAction)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
    }

    @ViewBuilder func guideSummary(_ guide: Guide) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
            Text(guide.title)
                .font(.title2)
                .bold()
                .foregroundStyle(AppTheme.ink)
            Text(guide.summary)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
        .accessibilityElement(children: .combine)
    }

    var primaryActionTitle: String {
        if isWorking {
            return analysisAvailability == .downloadable ? "Preparing model" : "Analyzing photos"
        }
        return analysisAvailability == .downloadable ? "Download on-device model" : "Analyze on this device"
    }

    var canPerformPrimaryAction: Bool {
        analysisAvailability == .available || analysisAvailability == .downloadable
    }

    func performPrimaryAction() {
        Task {
            isWorking = true
            errorMessage = nil
            defer { isWorking = false }

            do {
                if analysisAvailability == .downloadable {
                    try await OnDeviceAnalyzer.prepareModel()
                    await refreshAvailability()
                    return
                }

                let analyzedGuide = try await OnDeviceAnalyzer.analyze(photoURLs: photoURLs)
                guide = analyzedGuide
                if let firstComponent = analyzedGuide.components.first {
                    selectedDisplayNumber = firstComponent.displayNumber
                    activePhotoIndex = firstComponent.photoIndex
                }
            } catch {
                errorMessage = error.localizedDescription
                await refreshAvailability()
            }
        }
    }

    func refreshAvailability() async {
        analysisAvailability = await OnDeviceAnalyzer.availability()
    }
}

#Preview {
    ContentView()
}
