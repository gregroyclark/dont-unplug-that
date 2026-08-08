import Foundation

public struct NormalizedCoordinate: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var isNormalized: Bool {
        (0.0...1.0).contains(x) && (0.0...1.0).contains(y)
    }
}

public enum GuideItemKind: String, Codable, CaseIterable, Hashable, Sendable {
    case component
    case connection
}

public enum EvidenceLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case observed
    case inferred
    case unclear
}

public struct GuideComponent: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var displayNumber: Int
    public var name: String
    public var kind: GuideItemKind
    public var photoIndex: Int
    public var location: NormalizedCoordinate
    public var likelyPurpose: String
    public var unpluggingImpact: String
    public var evidenceLevel: EvidenceLevel
    public var uncertaintyNotes: String
    public var safetyWarning: String?

    public init(
        id: UUID = UUID(),
        displayNumber: Int,
        name: String,
        kind: GuideItemKind = .component,
        photoIndex: Int = 0,
        location: NormalizedCoordinate,
        likelyPurpose: String,
        unpluggingImpact: String,
        evidenceLevel: EvidenceLevel,
        uncertaintyNotes: String,
        safetyWarning: String? = nil
    ) {
        self.id = id
        self.displayNumber = displayNumber
        self.name = name
        self.kind = kind
        self.photoIndex = photoIndex
        self.location = location
        self.likelyPurpose = likelyPurpose
        self.unpluggingImpact = unpluggingImpact
        self.evidenceLevel = evidenceLevel
        self.uncertaintyNotes = uncertaintyNotes
        self.safetyWarning = safetyWarning
    }
}

public struct Guide: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var summary: String
    public var components: [GuideComponent]

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        components: [GuideComponent]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.components = components
    }
}

public enum GuideImageMediaType: String, Codable, CaseIterable, Sendable {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case heic = "image/heic"
}

public struct GuidePhoto: Codable, Equatable, Sendable {
    public var base64EncodedImage: String
    public var mediaType: GuideImageMediaType

    public init(base64EncodedImage: String, mediaType: GuideImageMediaType) {
        self.base64EncodedImage = base64EncodedImage
        self.mediaType = mediaType
    }
}

public struct AnalyzeGuideRequest: Codable, Equatable, Sendable {
    public var photos: [GuidePhoto]

    public init(photos: [GuidePhoto]) {
        self.photos = photos
    }
}

public enum GuideAnalysisMode: String, Codable, Sendable {
    case fixture
    case onDevice = "on_device"
}

public struct AnalyzeGuideResponse: Codable, Equatable, Sendable {
    public var guide: Guide
    public var analysisMode: GuideAnalysisMode
    public var warnings: [String]

    public init(
        guide: Guide,
        analysisMode: GuideAnalysisMode,
        warnings: [String] = []
    ) {
        self.guide = guide
        self.analysisMode = analysisMode
        self.warnings = warnings
    }
}
