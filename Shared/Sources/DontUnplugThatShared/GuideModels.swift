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

public struct GuideComponent: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var displayNumber: Int
    public var name: String
    public var location: NormalizedCoordinate
    public var startupInstructions: String
    public var shutdownInstructions: String
    public var neverTouchInstructions: String

    public init(
        id: UUID = UUID(),
        displayNumber: Int,
        name: String,
        location: NormalizedCoordinate,
        startupInstructions: String = "",
        shutdownInstructions: String = "",
        neverTouchInstructions: String = ""
    ) {
        self.id = id
        self.displayNumber = displayNumber
        self.name = name
        self.location = location
        self.startupInstructions = startupInstructions
        self.shutdownInstructions = shutdownInstructions
        self.neverTouchInstructions = neverTouchInstructions
    }
}

public struct Guide: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var components: [GuideComponent]

    public init(
        id: UUID = UUID(),
        title: String,
        components: [GuideComponent]
    ) {
        self.id = id
        self.title = title
        self.components = components
    }
}

public enum GuideImageMediaType: String, Codable, CaseIterable, Sendable {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case heic = "image/heic"
}

public struct AnalyzeGuideRequest: Codable, Equatable, Sendable {
    public var base64EncodedImage: String
    public var mediaType: GuideImageMediaType
    public var suggestedTitle: String?

    public init(
        base64EncodedImage: String,
        mediaType: GuideImageMediaType,
        suggestedTitle: String? = nil
    ) {
        self.base64EncodedImage = base64EncodedImage
        self.mediaType = mediaType
        self.suggestedTitle = suggestedTitle
    }
}

public enum GuideAnalysisMode: String, Codable, Sendable {
    case fixture
    case artificialIntelligence
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
