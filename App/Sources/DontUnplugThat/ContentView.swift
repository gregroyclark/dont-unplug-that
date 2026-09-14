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
    @State var modelCheckError: String?
    @State var isCheckingModel = false
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
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                        appNavigation

                        AppHeaderView(itemCount: guide?.components.count)

                        if photoURLs.isEmpty && analysisAvailability != .available {
                            analysisControls
                        }

                        PhotoCaptureView(
                            photoURLs: $photoURLs,
                            activePhotoIndex: $activePhotoIndex,
                            canCapture: analysisAvailability == .available
                        )
                        .disabled(isWorking)

                        if !photoURLs.isEmpty {
                            SetupCanvasView(
                                photoURL: activePhotoURL,
                                components: activePhotoComponents,
                                selectedDisplayNumber: $selectedDisplayNumber
                            )

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

                        savedGuidesSection
                        syncCard
                    }
                    .padding(AppTheme.pagePadding)
                    .frame(width: min(geometry.size.width, 640.0))
                    .frame(maxWidth: .infinity)
                }
            }
            .background(AppTheme.pageBackground)
            #if !os(macOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
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
            if newPhase == .active {
                Task {
                    await refreshAvailability()
                    if account != nil { await runSync() }
                }
            }
        }
        .task(id: analysisAvailability) {
            while analysisAvailability == .downloading {
                do { try await Task.sleep(nanoseconds: 5_000_000_000) }
                catch { return }
                guard !Task.isCancelled else { return }
                if scenePhase == .active { await refreshAvailability() }
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

    var appNavigation: some View {
        HStack(spacing: AppTheme.compactSpacing) {
            HStack(spacing: AppTheme.compactSpacing) {
                Image("DaylightBrand", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32.0, height: 32.0)
                    .accessibilityHidden(true)
                Text("Don’t Unplug That")
            }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4.0)
            Button("Saved guides") { showsLibrary = true }
                .font(.system(.caption, design: .rounded, weight: .medium))
                .frame(minHeight: 44.0)
        }
    }

    var savedGuidesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            Divider().overlay(AppTheme.separator)
            Text("Your saved guides")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .padding(.top, 8.0)

            if let record = savedGuides.first {
                Button { openGuide(record) } label: {
                    HStack(spacing: AppTheme.standardSpacing) {
                        SelectedPhotoView(url: repository.photoURLs(for: record).first)
                            .frame(width: 88.0, height: 66.0)
                            .clipped()
                            .clipShape(.rect(cornerRadius: 8.0))
                        Text(record.guide.title)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(AppTheme.ink)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        AppSymbol(systemName: "chevron.right")
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open saved guide: \(record.guide.title)")
            } else {
                Text("Your first guide starts with a photo. It will be saved here automatically.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
    }

    var syncCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
            Button { showsSyncSettings = true } label: {
                HStack(spacing: AppTheme.compactSpacing) {
                    AppSymbol(systemName: account == nil ? "lock" : "icloud")
                    Text(account == nil ? "Privacy & optional sync" : "Privacy & sync")
                    Spacer()
                    if isSyncing { ProgressView() }
                    AppSymbol(systemName: "chevron.right")
                }
                .font(.footnote)
                .frame(minHeight: 44.0)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.secondaryInk)
            if let syncMessage {
                Text(syncMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.warning)
            }
        }
    }

    @ViewBuilder var analysisControls: some View {
        VStack(alignment: .leading, spacing: AppTheme.standardSpacing) {
            if analysisAvailability != .available {
                AppLabel(analysisAvailability.title, systemImage: analysisAvailability.systemImage)
                    .font(.headline)
                    .foregroundStyle(analysisAvailability == .unavailable ? AppTheme.warning : AppTheme.accent)

                Text(analysisAvailability.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let modelCheckError {
                    Text(modelCheckError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Model service details: \(modelCheckError)")
                }

                Button(isCheckingModel ? "Checking model…" : "Check again") {
                    Task { await refreshAvailability() }
                }
                .disabled(isWorking || isCheckingModel)
            }

            if let errorMessage {
                AppLabel(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.warning)
                    .accessibilityLabel("Analysis error. \(errorMessage)")
            }

            if analysisAvailability == .downloadable || !photoURLs.isEmpty {
                Button(action: performPrimaryAction) {
                    HStack {
                        if isWorking {
                            ProgressView()
                                .tint(.white)
                        }
                        AppLabel(primaryActionTitle, systemImage: "sparkles")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50.0)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking || isCheckingModel || !canPerformPrimaryAction)
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.accentSoft)
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
        .background(AppTheme.accentSoft)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
    }

    var primaryActionTitle: String {
        if isWorking {
            return analysisAvailability == .downloadable ? "Preparing model" : "Analyzing photos"
        }
        return analysisAvailability == .downloadable ? "Download on-device model" : "Analyze on this device"
    }

    var canPerformPrimaryAction: Bool {
        analysisAvailability == .downloadable
            || (analysisAvailability == .available && !photoURLs.isEmpty)
    }

    func performPrimaryAction() {
        guard !isWorking, !isCheckingModel, canPerformPrimaryAction else { return }
        isWorking = true
        let inputPhotoURLs = photoURLs
        Task {
            errorMessage = nil
            defer { isWorking = false }

            do {
                if analysisAvailability == .downloadable {
                    try await OnDeviceAnalyzer.prepareModel()
                    await refreshAvailability()
                    return
                }

                let analyzedGuide = try await OnDeviceAnalyzer.analyze(photoURLs: inputPhotoURLs)
                _ = try await repository.saveAnalyzedGuide(
                    analyzedGuide,
                    sourcePhotoURLs: inputPhotoURLs
                )
                guard photoURLs == inputPhotoURLs else {
                    reloadLibrary()
                    return
                }
                guide = analyzedGuide
                displayedGuidePhotoURLs = inputPhotoURLs
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
        guard !isCheckingModel else { return }
        isCheckingModel = true
        defer { isCheckingModel = false }
        do {
            analysisAvailability = try await OnDeviceAnalyzer.availability()
            modelCheckError = nil
        } catch {
            analysisAvailability = .checkFailed
            // Availability errors contain service diagnostics, never photo inference content.
            modelCheckError = error.localizedDescription
        }
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
