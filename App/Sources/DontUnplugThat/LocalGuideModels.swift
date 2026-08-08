import DontUnplugThatShared
import Foundation

enum LocalSyncStatus: String, Codable, Sendable {
    case localOnly
    case pendingUpload
    case synced
    case dirty
    case deletePending
    case conflicted
}

enum LocalConflictKind: String, Codable, Sendable {
    case revision
    case deleted
}

struct LocalGuideConflict: Codable, Equatable, Sendable {
    var kind: LocalConflictKind
    var current: SyncedGuide?
}

struct LocalGuideSyncState: Codable, Equatable, Sendable {
    var status: LocalSyncStatus
    var revision: Int?
    var conflict: LocalGuideConflict?
    var ownerID: String?

    static let localOnly = LocalGuideSyncState(status: .localOnly)
    static func pendingUpload(ownerID: String) -> LocalGuideSyncState {
        LocalGuideSyncState(status: .pendingUpload, ownerID: ownerID)
    }

    static func synced(_ revision: Int, ownerID: String) -> LocalGuideSyncState {
        LocalGuideSyncState(status: .synced, revision: revision, ownerID: ownerID)
    }

    static func dirty(_ baseRevision: Int, ownerID: String) -> LocalGuideSyncState {
        LocalGuideSyncState(status: .dirty, revision: baseRevision, ownerID: ownerID)
    }

    static func deletePending(_ baseRevision: Int, ownerID: String) -> LocalGuideSyncState {
        LocalGuideSyncState(status: .deletePending, revision: baseRevision, ownerID: ownerID)
    }

    static func conflicted(_ conflict: LocalGuideConflict, ownerID: String) -> LocalGuideSyncState {
        LocalGuideSyncState(status: .conflicted, revision: conflict.current?.revision, conflict: conflict, ownerID: ownerID)
    }

    init(status: LocalSyncStatus, revision: Int? = nil, conflict: LocalGuideConflict? = nil, ownerID: String? = nil) {
        self.status = status
        self.revision = revision
        self.conflict = conflict
        self.ownerID = ownerID
    }
}

struct LocalGuideRecord: Codable, Equatable, Identifiable, Sendable {
    var guide: Guide
    var photos: [SyncPhotoDescriptor]
    var syncState: LocalGuideSyncState
    var createdAt: Int64
    var updatedAt: Int64

    var id: UUID { guide.id }
}

struct ProcessedGuidePhoto: Sendable {
    var data: Data
    var descriptor: SyncPhotoDescriptor
}
