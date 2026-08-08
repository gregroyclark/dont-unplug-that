import DontUnplugThatShared
import Foundation
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase

    @State var photoURLs: [URL] = []
    @State var displayedGuidePhotoURLs: [URL] = []
    @State var activePhotoIndex = 0
    @State var guide: Guide?
    @State var selectedDisplayNumber = 1
    @State var analysisAvailability = AnalysisAvailability.checking
    @State var isWorking = false
    @State var errorMessage: String?
    @State var savedGuides: [LocalGuideRecord] = []
    @State var account: Account?
    @State var showsLibrary = false
    @State var showsSyncSettings = false
    @State var isSyncing = false
    @State var syncMessage: String?

    let repository = LocalGuideRepository.live()

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

                    syncCard

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
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showsLibrary = true
                    } label: {
                        Label("Saved guides", systemImage: "books.vertical")
                    }
                    Button {
                        showsSyncSettings = true
                    } label: {
                        Label("Sync settings", systemImage: account == nil ? "icloud.slash" : "icloud")
                    }
                }
            }
        }
        .tint(AppTheme.accent)
        .task {
            await refreshAvailability()
            reloadLibrary()
            await restoreAccount()
        }
        .onChange(of: photoURLs) { _, newURLs in
            if newURLs != displayedGuidePhotoURLs {
                guide = nil
            }
            errorMessage = nil
            if activePhotoIndex >= photoURLs.count {
                activePhotoIndex = max(0, photoURLs.count - 1)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, account != nil {
                Task { await runSync() }
            }
        }
        .sheet(isPresented: $showsLibrary) {
            GuideLibraryView(
                records: savedGuides,
                repository: repository,
                isSyncing: isSyncing,
                open: openGuide,
                delete: deleteGuide,
                resolve: resolveConflict
            )
        }
        .sheet(isPresented: $showsSyncSettings) {
            SyncSettingsView(
                account: $account,
                isSyncing: $isSyncing,
                baseURL: SyncConfiguration.apiBaseURL,
                repository: repository,
                didChange: reloadLibrary,
                syncNow: syncWhileLocked
            )
        }
    }

    var activePhotoURL: URL? {
        guard photoURLs.indices.contains(activePhotoIndex) else {
            return nil
        }
        return photoURLs[activePhotoIndex]
    }

    @ViewBuilder var syncCard: some View {
        HStack(spacing: AppTheme.standardSpacing) {
            Image(systemName: account == nil ? "icloud.slash" : "icloud.and.arrow.up")
                .foregroundStyle(account == nil ? .secondary : AppTheme.safe)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(account == nil ? "Optional cross-device sync" : "Sync is on")
                    .font(.subheadline)
                    .bold()
                Text(syncMessage ?? (account == nil
                    ? "Analysis stays on device. Turn on Sync only if you want your guides elsewhere."
                    : "Private resized photo copies sync with your guides."))
                    .font(.caption)
                    .foregroundStyle(syncMessage == nil ? .secondary : AppTheme.warning)
            }
            Spacer()
            if isSyncing {
                ProgressView()
            } else {
                Button(account == nil ? "Turn on Sync" : "Sync") {
                    if account == nil {
                        showsSyncSettings = true
                    } else {
                        Task { await runSync() }
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
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
                _ = try await repository.saveAnalyzedGuide(
                    analyzedGuide,
                    sourcePhotoURLs: photoURLs
                )
                guide = analyzedGuide
                displayedGuidePhotoURLs = photoURLs
                reloadLibrary()
                if let firstComponent = analyzedGuide.components.first {
                    selectedDisplayNumber = firstComponent.displayNumber
                    activePhotoIndex = firstComponent.photoIndex
                }
                if account != nil {
                    await runSync()
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

    func reloadLibrary() {
        do {
            savedGuides = try repository.all()
        } catch {
            syncMessage = "Saved guides could not be loaded."
        }
    }

    func restoreAccount() async {
        guard let baseURL = SyncConfiguration.apiBaseURL,
              (try? SecureSessionStore().token()) != nil else { return }
        do {
            let restored = try await AuthClient(baseURL: baseURL).account()
            guard try repository.syncOwnerIDs().allSatisfy({ $0 == restored.id }) else {
                try? await AuthClient(baseURL: baseURL).signOut()
                throw AuthClientError.accountMismatch
            }
            account = restored
            await runSync()
        } catch let error as AuthClientError {
            if case .server(let status, _) = error, status == 401 {
                try? SecureSessionStore().clear()
            }
            syncMessage = error.localizedDescription
        } catch {
            syncMessage = "Sync will retry when the service is reachable."
        }
    }

    func runSync() async {
        guard let account, let baseURL = SyncConfiguration.apiBaseURL, !isSyncing else { return }
        isSyncing = true
        syncMessage = nil
        defer { isSyncing = false }
        do {
            try await syncWhileLocked(account: account, baseURL: baseURL)
        } catch {
            syncMessage = error.localizedDescription
        }
    }

    func syncWhileLocked() async throws {
        guard let account, let baseURL = SyncConfiguration.apiBaseURL else {
            throw AuthClientError.syncUnavailable
        }
        try await syncWhileLocked(account: account, baseURL: baseURL)
    }

    private func syncWhileLocked(account: Account, baseURL: URL) async throws {
        try await SyncCoordinator(
            repository: repository,
            client: SyncClient(baseURL: baseURL),
            accountID: account.id
        ).sync()
        reloadLibrary()
    }

    func openGuide(_ record: LocalGuideRecord) {
        let urls = repository.photoURLs(for: record)
        displayedGuidePhotoURLs = urls
        photoURLs = urls
        guide = record.guide
        activePhotoIndex = 0
        selectedDisplayNumber = record.guide.components.first?.displayNumber ?? 1
    }

    func deleteGuide(_ record: LocalGuideRecord) {
        Task {
            guard !isSyncing else { return }
            isSyncing = true
            defer { isSyncing = false }
            do {
                if let baseURL = SyncConfiguration.apiBaseURL, let account {
                    try SyncCoordinator(
                        repository: repository,
                        client: SyncClient(baseURL: baseURL),
                        accountID: account.id
                    ).requestDelete(id: record.id)
                    try await syncWhileLocked(account: account, baseURL: baseURL)
                } else {
                    try repository.remove(id: record.id)
                }
                reloadLibrary()
            } catch {
                syncMessage = error.localizedDescription
            }
        }
    }

    func resolveConflict(_ record: LocalGuideRecord, choice: ConflictResolution) {
        Task {
            guard let baseURL = SyncConfiguration.apiBaseURL, let account else { return }
            guard !isSyncing else { return }
            isSyncing = true
            defer { isSyncing = false }
            let coordinator = SyncCoordinator(
                repository: repository,
                client: SyncClient(baseURL: baseURL),
                accountID: account.id
            )
            do {
                switch choice {
                case .useCloud:
                    try await coordinator.useCloud(id: record.id)
                case .overwriteCloud:
                    try await coordinator.overwriteCloud(id: record.id)
                case .saveAsNew:
                    _ = try coordinator.saveAsNew(id: record.id)
                }
                try await syncWhileLocked(account: account, baseURL: baseURL)
            } catch {
                syncMessage = error.localizedDescription
            }
        }
    }
}
