import DontUnplugThatShared
import Foundation

struct LocalGuideRepository: Sendable {
    private struct Index: Codable {
        var ids: [UUID]
    }

    let rootURL: URL
    private var fileManager: FileManager { FileManager.default }

    static func live() -> LocalGuideRepository {
        LocalGuideRepository(rootURL: URL.applicationSupportDirectory.appendingPathComponent("Guides", isDirectory: true))
    }

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    func all() throws -> [LocalGuideRecord] {
        let ids = try loadIndex().ids
        return try ids.compactMap { id in
            let url = recordURL(id)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return try JSONDecoder().decode(LocalGuideRecord.self, from: Data(contentsOf: url))
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func record(id: UUID) throws -> LocalGuideRecord? {
        let url = recordURL(id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(LocalGuideRecord.self, from: Data(contentsOf: url))
    }

    func photoURL(guideID: UUID, index: Int) -> URL {
        guideDirectory(guideID)
            .appendingPathComponent("photos", isDirectory: true)
            .appendingPathComponent("\(index).jpg")
    }

    func photoURLs(for record: LocalGuideRecord) -> [URL] {
        record.photos.map { photoURL(guideID: record.id, index: $0.index) }
    }

    func saveAnalyzedGuide(_ guide: Guide, sourcePhotoURLs: [URL]) async throws -> LocalGuideRecord {
        let photos = try await GuidePhotoDerivative.make(from: sourcePhotoURLs)
        return try save(guide: guide, photos: photos, state: .localOnly)
    }

    @discardableResult
    func save(
        guide: Guide,
        photos: [ProcessedGuidePhoto],
        state: LocalGuideSyncState,
        createdAt: Int64? = nil
    ) throws -> LocalGuideRecord {
        let descriptors = photos.map(\.descriptor)
        try PendingGuideUpload(guide: guide, photos: descriptors).validate()
        try ensureRoot()

        let now = millisecondsSince1970()
        let record = LocalGuideRecord(
            guide: guide,
            photos: descriptors,
            syncState: state,
            createdAt: createdAt ?? now,
            updatedAt: now
        )
        let finalDirectory = guideDirectory(guide.id)
        let stagingDirectory = rootURL.appendingPathComponent(".\(guide.id.uuidString).staging", isDirectory: true)
        if fileManager.fileExists(atPath: stagingDirectory.path) {
            try fileManager.removeItem(at: stagingDirectory)
        }
        let stagingPhotos = stagingDirectory.appendingPathComponent("photos", isDirectory: true)
        try fileManager.createDirectory(at: stagingPhotos, withIntermediateDirectories: true)
        for photo in photos {
            try photo.data.write(
                to: stagingPhotos.appendingPathComponent("\(photo.descriptor.index).jpg"),
                options: .atomic
            )
        }
        try JSONEncoder().encode(record).write(
            to: stagingDirectory.appendingPathComponent("guide.json"),
            options: .atomic
        )

        let backupDirectory = rootURL.appendingPathComponent(".\(guide.id.uuidString).backup", isDirectory: true)
        let hadExistingRecord = fileManager.fileExists(atPath: finalDirectory.path)
        if fileManager.fileExists(atPath: backupDirectory.path) {
            try fileManager.removeItem(at: backupDirectory)
        }
        if hadExistingRecord {
            try fileManager.moveItem(at: finalDirectory, to: backupDirectory)
        }
        do {
            try fileManager.moveItem(at: stagingDirectory, to: finalDirectory)
        } catch {
            if hadExistingRecord {
                try? fileManager.moveItem(at: backupDirectory, to: finalDirectory)
            }
            throw error
        }
        do {
            var index = try loadIndex()
            if !index.ids.contains(guide.id) {
                index.ids.append(guide.id)
            }
            try writeIndex(index)
        } catch {
            try? fileManager.removeItem(at: finalDirectory)
            if hadExistingRecord {
                try? fileManager.moveItem(at: backupDirectory, to: finalDirectory)
            }
            throw error
        }
        if hadExistingRecord {
            try? fileManager.removeItem(at: backupDirectory)
        }
        return record
    }

    func update(_ record: LocalGuideRecord) throws {
        guard fileManager.fileExists(atPath: guideDirectory(record.id).path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = record
        updated.updatedAt = millisecondsSince1970()
        try JSONEncoder().encode(updated).write(to: recordURL(record.id), options: .atomic)
    }

    func remove(id: UUID) throws {
        let directory = guideDirectory(id)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        var index = try loadIndex()
        index.ids.removeAll { $0 == id }
        try writeIndex(index)
    }

    func makeAllLocalOnly() throws {
        for var record in try all() {
            record.syncState = .localOnly
            try update(record)
        }
    }

    func syncOwnerIDs() throws -> Set<String> {
        Set(try all().compactMap(\.syncState.ownerID))
    }

    func cloneAsLocalOnly(_ record: LocalGuideRecord) throws -> LocalGuideRecord {
        var guide = record.guide
        guide.id = UUID()
        let photos = try record.photos.map { descriptor in
            let data = try Data(contentsOf: photoURL(guideID: record.id, index: descriptor.index))
            var localDescriptor = descriptor
            localDescriptor.downloadPath = nil
            return ProcessedGuidePhoto(data: data, descriptor: localDescriptor)
        }
        return try save(guide: guide, photos: photos, state: .localOnly)
    }

    private func ensureRoot() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        #if !SKIP && os(iOS)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: rootURL.path
        )
        #endif
    }

    private func guideDirectory(_ id: UUID) -> URL {
        rootURL.appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
    }

    private func recordURL(_ id: UUID) -> URL {
        guideDirectory(id).appendingPathComponent("guide.json")
    }

    private var indexURL: URL {
        rootURL.appendingPathComponent("index.json")
    }

    private func loadIndex() throws -> Index {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return Index(ids: [])
        }
        return try JSONDecoder().decode(Index.self, from: Data(contentsOf: indexURL))
    }

    private func writeIndex(_ index: Index) throws {
        try ensureRoot()
        try JSONEncoder().encode(index).write(to: indexURL, options: .atomic)
    }

    private func millisecondsSince1970() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1_000)
    }
}
