import Foundation

public let maximumGuidePhotoCount = 3
public let maximumGuidePhotoByteCount = 5 * 1024 * 1024
public let maximumGuidePhotoDimension = 2048

public enum GuideSyncValidationError: Error, Equatable, Sendable {
    case invalidRevision
    case invalidGuide
    case invalidPhotoCount
    case invalidPhotoIndex
    case invalidPhotoMediaType
    case invalidPhotoSize
    case invalidPhotoDimensions
    case invalidPhotoDigest
}

public struct SyncPhotoDescriptor: Codable, Equatable, Sendable {
    public var index: Int
    public var mediaType: GuideImageMediaType
    public var byteCount: Int
    public var sha256: String
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var downloadPath: String?

    public init(
        index: Int,
        mediaType: GuideImageMediaType = .jpeg,
        byteCount: Int,
        sha256: String,
        pixelWidth: Int,
        pixelHeight: Int,
        downloadPath: String? = nil
    ) {
        self.index = index
        self.mediaType = mediaType
        self.byteCount = byteCount
        self.sha256 = sha256
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.downloadPath = downloadPath
    }

    public func validate(expectedIndex: Int) throws {
        guard index == expectedIndex else {
            throw GuideSyncValidationError.invalidPhotoIndex
        }
        guard mediaType == .jpeg else {
            throw GuideSyncValidationError.invalidPhotoMediaType
        }
        guard (1...maximumGuidePhotoByteCount).contains(byteCount) else {
            throw GuideSyncValidationError.invalidPhotoSize
        }
        guard (1...maximumGuidePhotoDimension).contains(pixelWidth),
              (1...maximumGuidePhotoDimension).contains(pixelHeight) else {
            throw GuideSyncValidationError.invalidPhotoDimensions
        }
        guard !sha256.isEmpty, Data(base64Encoded: sha256)?.count == 32 else {
            throw GuideSyncValidationError.invalidPhotoDigest
        }
    }
}

public enum SyncedGuideState: String, Codable, Sendable {
    case pending
    case active
}

public struct SyncedGuide: Codable, Equatable, Sendable {
    public var guide: Guide
    public var revision: Int
    public var state: SyncedGuideState
    public var serverModifiedAt: Int64
    public var photos: [SyncPhotoDescriptor]

    public init(
        guide: Guide,
        revision: Int,
        state: SyncedGuideState = .active,
        serverModifiedAt: Int64,
        photos: [SyncPhotoDescriptor]
    ) {
        self.guide = guide
        self.revision = revision
        self.state = state
        self.serverModifiedAt = serverModifiedAt
        self.photos = photos
    }

    public func validate() throws {
        guard revision > 0, state == .active else {
            throw GuideSyncValidationError.invalidRevision
        }
        try validateGuide(guide, photos: photos)
    }
}

public struct GuideTombstone: Codable, Equatable, Sendable {
    public var id: UUID
    public var revision: Int
    public var deletedAt: Int64

    public init(id: UUID, revision: Int, deletedAt: Int64) {
        self.id = id
        self.revision = revision
        self.deletedAt = deletedAt
    }

    public func validate() throws {
        guard revision > 0 else {
            throw GuideSyncValidationError.invalidRevision
        }
    }
}

public struct GuideSyncSnapshot: Codable, Equatable, Sendable {
    public var guides: [SyncedGuide]
    public var tombstones: [GuideTombstone]

    public init(guides: [SyncedGuide], tombstones: [GuideTombstone]) {
        self.guides = guides
        self.tombstones = tombstones
    }

    public func validate() throws {
        try guides.forEach { try $0.validate() }
        try tombstones.forEach { try $0.validate() }
    }
}

public struct PendingGuideUpload: Codable, Equatable, Sendable {
    public var guide: Guide
    public var photos: [SyncPhotoDescriptor]

    public init(guide: Guide, photos: [SyncPhotoDescriptor]) {
        self.guide = guide
        self.photos = photos
    }

    public func validate() throws {
        try validateGuide(guide, photos: photos)
    }
}

public struct GuideUpdate: Codable, Equatable, Sendable {
    public var guide: Guide

    public init(guide: Guide) {
        self.guide = guide
    }
}

public struct GuideRevisionResponse: Codable, Equatable, Sendable {
    public var revision: Int

    public init(revision: Int) {
        self.revision = revision
    }
}

public struct GuideSyncErrorEnvelope: Codable, Equatable, Sendable {
    public var error: GuideSyncError

    public init(error: GuideSyncError) {
        self.error = error
    }
}

public struct GuideSyncError: Codable, Equatable, Sendable {
    public var code: String
    public var message: String
    public var current: SyncedGuide?

    public init(code: String, message: String, current: SyncedGuide? = nil) {
        self.code = code
        self.message = message
        self.current = current
    }
}

public enum AuthProvider: String, Codable, CaseIterable, Sendable {
    case apple
    case google
}

public struct MobileAuthExchangeRequest: Codable, Equatable, Sendable {
    public var code: String
    public var state: String
    public var codeVerifier: String

    public init(code: String, state: String, codeVerifier: String) {
        self.code = code
        self.state = state
        self.codeVerifier = codeVerifier
    }
}

public struct Account: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var email: String
    public var provider: AuthProvider

    public init(id: String, name: String, email: String, provider: AuthProvider) {
        self.id = id
        self.name = name
        self.email = email
        self.provider = provider
    }
}

private func validateGuide(_ guide: Guide, photos: [SyncPhotoDescriptor]) throws {
    guard (1...maximumGuidePhotoCount).contains(photos.count) else {
        throw GuideSyncValidationError.invalidPhotoCount
    }
    for (index, photo) in photos.enumerated() {
        try photo.validate(expectedIndex: index)
    }
    guard !guide.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !guide.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          (5...12).contains(guide.components.count),
          guide.components.allSatisfy({ component in
              photos.indices.contains(component.photoIndex) && component.location.isNormalized
          }) else {
        throw GuideSyncValidationError.invalidGuide
    }
}
