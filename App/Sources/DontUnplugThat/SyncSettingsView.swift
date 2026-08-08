import DontUnplugThatShared
import Foundation
import SkipAuthenticationServices
import SwiftUI

struct SyncSettingsView: View {
    @Environment(\.dismiss) var dismiss
    #if !os(Android)
    let browserAuthenticator = BrowserAuthenticator()
    #endif

    @Binding var account: Account?
    @Binding var isSyncing: Bool
    let baseURL: URL?
    let repository: LocalGuideRepository
    let didChange: () -> Void
    let syncNow: () async throws -> Void

    @State var isWorking = false
    @State var message: String?
    @State var confirmsDeletion = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Privacy") {
                    Text("Analysis always stays on this device. Sync uploads private, resized JPEG copies with photo metadata removed. Sync is optional and is not end-to-end encrypted.")
                }

                if let account {
                    Section("Account") {
                        LabeledContent("Signed in", value: account.email)
                        LabeledContent("Provider", value: account.provider.rawValue.capitalized)
                        Button("Sync now") { run { try await syncNow() } }
                            .disabled(isWorking || isSyncing)
                        Button("Sign out") { run { try await signOut() } }
                            .disabled(isWorking || isSyncing)
                    }
                    Section("Delete account") {
                        if confirmsDeletion {
                            Text("This permanently deletes synced guides and photos. Guides saved on this device stay here.")
                                .foregroundStyle(AppTheme.warning)
                            Button("Permanently delete account", role: .destructive) {
                                run { try await deleteAccount() }
                            }
                            .disabled(isWorking || isSyncing)
                        } else {
                            Button("Delete account", role: .destructive) {
                                confirmsDeletion = true
                            }
                            .disabled(isWorking || isSyncing)
                        }
                    }
                } else {
                    Section("Turn on Sync") {
                        Text("Use the same provider on your other devices. Provider linking is not available yet.")
                        Button { run { try await signIn(.apple) } } label: {
                            Label("Continue with Apple", systemImage: "apple.logo")
                        }
                        .disabled(isWorking || isSyncing || baseURL == nil)
                        Button { run { try await signIn(.google) } } label: {
                            Label("Continue with Google", systemImage: "person.crop.circle.badge.checkmark")
                        }
                        .disabled(isWorking || isSyncing || baseURL == nil)
                        if baseURL == nil {
                            Text("Sync is not configured in this build.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.warning)
                        }
                    }
                }

                if isWorking {
                    ProgressView()
                }
                if let message {
                    Text(message)
                        .foregroundStyle(AppTheme.warning)
                }
            }
            .navigationTitle("Sync")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        Task {
            guard !isWorking, !isSyncing else { return }
            isWorking = true
            isSyncing = true
            message = nil
            defer {
                isWorking = false
                isSyncing = false
            }
            do {
                try await operation()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func signIn(_ provider: AuthProvider) async throws {
        guard let baseURL else { throw AuthClientError.syncUnavailable }
        let client = AuthClient(baseURL: baseURL)
        let signedIn = try await client.signIn(provider: provider) { url in
            try await authenticate(url)
        }
        guard try repository.syncOwnerIDs().allSatisfy({ $0 == signedIn.id }) else {
            try? await client.signOut()
            throw AuthClientError.accountMismatch
        }
        account = signedIn
        try await syncNow()
        didChange()
    }

    private func authenticate(_ url: URL) async throws -> URL {
        #if os(Android)
        return try await WebAuthenticationSession().authenticate(
            using: url,
            callbackURLScheme: SyncConfiguration.callbackScheme,
            preferredBrowserSession: .ephemeral
        )
        #else
        return try await browserAuthenticator.authenticate(url)
        #endif
    }

    private func signOut() async throws {
        guard let baseURL else { throw AuthClientError.syncUnavailable }
        try await AuthClient(baseURL: baseURL).signOut()
        account = nil
        didChange()
    }

    private func deleteAccount() async throws {
        guard let baseURL else { throw AuthClientError.syncUnavailable }
        try await AuthClient(baseURL: baseURL).deleteAccount()
        try repository.makeAllLocalOnly()
        account = nil
        didChange()
    }
}
