import SwiftUI

struct GuideLibraryView: View {
    @Environment(\.dismiss) var dismiss

    let records: [LocalGuideRecord]
    let repository: LocalGuideRepository
    let isSyncing: Bool
    let open: (LocalGuideRecord) -> Void
    let delete: (LocalGuideRecord) -> Void
    let resolve: (LocalGuideRecord, ConflictResolution) -> Void

    var body: some View {
        NavigationStack {
            List {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No saved guides",
                        systemImage: "books.vertical",
                        description: Text("Analyze a setup and it will appear here.")
                    )
                }
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
                        Button {
                            open(record)
                            dismiss()
                        } label: {
                            HStack(spacing: AppTheme.standardSpacing) {
                                SelectedPhotoView(url: repository.photoURLs(for: record).first)
                                    .frame(width: 72.0, height: 54.0)
                                    .clipped()
                                    .clipShape(.rect(cornerRadius: 10.0))
                                VStack(alignment: .leading, spacing: 3.0) {
                                    Text(record.guide.title)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(statusText(record.syncState.status))
                                        .font(.caption)
                                        .foregroundStyle(record.syncState.status == .conflicted ? AppTheme.warning : .secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        if let conflict = record.syncState.conflict {
                            GuideConflictView(conflict: conflict, isDisabled: isSyncing) { choice in
                                resolve(record, choice)
                            }
                        } else if record.syncState.status == .localOnly ||
                                    record.syncState.status == .pendingUpload ||
                                    record.syncState.status == .synced ||
                                    record.syncState.status == .dirty {
                            Button(role: .destructive) {
                                delete(record)
                            } label: {
                                Label("Delete guide", systemImage: "trash")
                            }
                            .font(.caption)
                            .disabled(isSyncing)
                        }
                    }
                    .padding(.vertical, 4.0)
                }
            }
            .navigationTitle("Saved Guides")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func statusText(_ status: LocalSyncStatus) -> String {
        switch status {
        case .localOnly: "On this device"
        case .pendingUpload: "Waiting to sync"
        case .synced: "Synced"
        case .dirty: "Waiting to sync changes"
        case .deletePending: "Waiting to delete"
        case .conflicted: "Needs your choice"
        }
    }
}
