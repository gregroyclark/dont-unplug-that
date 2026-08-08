import DontUnplugThatShared
import Foundation

struct SyncCoordinator: Sendable {
    let repository: LocalGuideRepository
    let client: SyncClient
    let accountID: String

    func sync() async throws {
        guard try repository.syncOwnerIDs().allSatisfy({ $0 == accountID }) else {
            throw AuthClientError.accountMismatch
        }
        try enqueueLocalGuides()
        try await reconcile(client.snapshot())
        try await pushQueue()
        try await reconcile(client.snapshot())
    }

    func requestDelete(id: UUID) throws {
        guard var record = try repository.record(id: id) else { return }
        switch record.syncState.status {
        case .localOnly:
            try repository.remove(id: id)
        case .synced:
            guard let revision = record.syncState.revision else { return }
            record.syncState = .deletePending(revision, ownerID: accountID)
            try repository.update(record)
        case .dirty:
            guard let revision = record.syncState.revision else { return }
            record.syncState = .deletePending(revision, ownerID: accountID)
            try repository.update(record)
        case .pendingUpload:
            record.syncState = .deletePending(0, ownerID: accountID)
            try repository.update(record)
        case .deletePending, .conflicted:
            return
        }
    }

    func markDirty(id: UUID, guide: Guide) throws {
        guard var record = try repository.record(id: id),
              record.syncState.status == .synced,
              let revision = record.syncState.revision else { return }
        record.guide = guide
        record.syncState = .dirty(revision, ownerID: accountID)
        try repository.update(record)
    }

    func useCloud(id: UUID) async throws {
        guard let record = try repository.record(id: id),
              let conflict = record.syncState.conflict else { return }
        if let current = conflict.current {
            try await storeCloud(current, replacing: record)
        } else {
            try repository.remove(id: id)
        }
    }

    func overwriteCloud(id: UUID) async throws {
        guard var record = try repository.record(id: id),
              let current = record.syncState.conflict?.current else { return }
        record.syncState = .dirty(current.revision, ownerID: accountID)
        try repository.update(record)
        try await push(record)
    }

    @discardableResult
    func saveAsNew(id: UUID) throws -> LocalGuideRecord? {
        guard let record = try repository.record(id: id) else { return nil }
        let clone = try repository.cloneAsLocalOnly(record)
        try repository.remove(id: id)
        return clone
    }

    private func enqueueLocalGuides() throws {
        for var record in try repository.all() where record.syncState.status == .localOnly {
            record.syncState = .pendingUpload(ownerID: accountID)
            try repository.update(record)
        }
    }

    private func pushQueue() async throws {
        for record in try repository.all() {
            do {
                try await push(record)
            } catch APIClientError.conflict(let current) {
                var conflicted = record
                conflicted.syncState = .conflicted(
                    LocalGuideConflict(kind: .revision, current: current),
                    ownerID: accountID
                )
                try repository.update(conflicted)
            } catch APIClientError.deleted {
                var conflicted = record
                conflicted.syncState = .conflicted(
                    LocalGuideConflict(kind: .deleted, current: nil),
                    ownerID: accountID
                )
                try repository.update(conflicted)
            }
        }
    }

    private func push(_ record: LocalGuideRecord) async throws {
        switch record.syncState.status {
        case .pendingUpload:
            try await client.createPending(record)
            for photo in record.photos {
                let data = try Data(contentsOf: repository.photoURL(guideID: record.id, index: photo.index))
                try await client.uploadPhoto(guideID: record.id, photo: photo, data: data)
            }
            let active = try await client.activate(guideID: record.id)
            var updated = record
            updated.guide = active.guide
            updated.photos = active.photos
            updated.syncState = .synced(active.revision, ownerID: accountID)
            try repository.update(updated)
        case .dirty:
            guard let revision = record.syncState.revision else {
                throw APIClientError.invalidResponse
            }
            let active = try await client.update(record, baseRevision: revision)
            var updated = record
            updated.guide = active.guide
            updated.photos = active.photos
            updated.syncState = .synced(active.revision, ownerID: accountID)
            try repository.update(updated)
        case .deletePending:
            guard let revision = record.syncState.revision else {
                throw APIClientError.invalidResponse
            }
            if revision == 0 {
                try await client.cancelPending(guideID: record.id)
            } else {
                try await client.delete(guideID: record.id, baseRevision: revision)
            }
            try repository.remove(id: record.id)
        case .localOnly, .synced, .conflicted:
            return
        }
    }

    private func reconcile(_ snapshot: GuideSyncSnapshot) async throws {
        for tombstone in snapshot.tombstones {
            guard var local = try repository.record(id: tombstone.id) else { continue }
            switch local.syncState.status {
            case .synced, .deletePending:
                try repository.remove(id: local.id)
            case .localOnly, .pendingUpload, .dirty:
                local.syncState = .conflicted(
                    LocalGuideConflict(kind: .deleted, current: nil),
                    ownerID: accountID
                )
                try repository.update(local)
            case .conflicted:
                break
            }
        }

        for cloud in snapshot.guides {
            guard let local = try repository.record(id: cloud.guide.id) else {
                try await storeCloud(cloud, replacing: nil)
                continue
            }
            switch local.syncState.status {
            case .synced:
                guard let localRevision = local.syncState.revision else {
                    throw APIClientError.invalidResponse
                }
                if cloud.revision > localRevision {
                    try await storeCloud(cloud, replacing: local)
                } else if cloud.revision < localRevision {
                    var conflicted = local
                    conflicted.syncState = .conflicted(
                        LocalGuideConflict(kind: .revision, current: cloud),
                        ownerID: accountID
                    )
                    try repository.update(conflicted)
                }
            case .pendingUpload:
                if sameContent(local, cloud) {
                    var synced = local
                    synced.guide = cloud.guide
                    synced.photos = cloud.photos
                    synced.syncState = .synced(cloud.revision, ownerID: accountID)
                    try repository.update(synced)
                } else {
                    var conflicted = local
                    conflicted.syncState = .conflicted(
                        LocalGuideConflict(kind: .revision, current: cloud),
                        ownerID: accountID
                    )
                    try repository.update(conflicted)
                }
            case .dirty, .deletePending:
                if local.syncState.revision != cloud.revision {
                    var conflicted = local
                    conflicted.syncState = .conflicted(
                        LocalGuideConflict(kind: .revision, current: cloud),
                        ownerID: accountID
                    )
                    try repository.update(conflicted)
                }
            case .localOnly:
                var conflicted = local
                conflicted.syncState = .conflicted(
                    LocalGuideConflict(kind: .revision, current: cloud),
                    ownerID: accountID
                )
                try repository.update(conflicted)
            case .conflicted:
                break
            }
        }
    }

    private func storeCloud(_ cloud: SyncedGuide, replacing local: LocalGuideRecord?) async throws {
        var photos: [ProcessedGuidePhoto] = []
        for descriptor in cloud.photos {
            let localURL = local.map { repository.photoURL(guideID: $0.id, index: descriptor.index) }
            var localData: Data?
            if let localURL {
                localData = try? Data(contentsOf: localURL)
            }
            let data: Data
            if let candidate = localData,
               candidate.count == descriptor.byteCount,
               PortableDigest.sha256Base64(candidate) == descriptor.sha256 {
                data = candidate
            } else if let path = descriptor.downloadPath {
                data = try await client.downloadPhoto(path: path, expected: descriptor)
            } else {
                throw APIClientError.invalidResponse
            }
            photos.append(ProcessedGuidePhoto(data: data, descriptor: descriptor))
        }
        _ = try repository.save(
            guide: cloud.guide,
            photos: photos,
            state: .synced(cloud.revision, ownerID: accountID),
            createdAt: local?.createdAt
        )
    }

    private func sameContent(_ local: LocalGuideRecord, _ cloud: SyncedGuide) -> Bool {
        guard local.guide == cloud.guide, local.photos.count == cloud.photos.count else {
            return false
        }
        return zip(local.photos, cloud.photos).allSatisfy { localPhoto, cloudPhoto in
            localPhoto.index == cloudPhoto.index &&
                localPhoto.sha256 == cloudPhoto.sha256 &&
                localPhoto.byteCount == cloudPhoto.byteCount
        }
    }
}
