import DontUnplugThatShared
import Foundation

#if !SKIP && compiler(>=6.4) && canImport(FoundationModels)
import FoundationModels
#endif

enum AnalysisAvailability: String, Sendable {
    case checking
    case available
    case downloadable
    case downloading
    case unsupportedOperatingSystem
    case deviceNotEligible
    case intelligenceDisabled
    case modelNotReady
    case unavailable

    var title: String {
        switch self {
        case .checking: "Checking on-device model"
        case .available: "Ready for private analysis"
        case .downloadable: "On-device model download required"
        case .downloading: "On-device model is downloading"
        case .unsupportedOperatingSystem: "Photo analysis requires a newer operating system"
        case .deviceNotEligible: "On-device analysis is not supported on this device"
        case .intelligenceDisabled: "Apple Intelligence is turned off"
        case .modelNotReady: "The on-device model is not ready"
        case .unavailable: "On-device analysis is unavailable"
        }
    }

    var message: String {
        switch self {
        case .checking: "This takes only a moment."
        case .available: "Photos stay on this device."
        case .downloadable: "Download Gemini Nano before analyzing photos."
        case .downloading: "Keep the app open while the model finishes downloading."
        case .unsupportedOperatingSystem: "Image understanding through Apple Foundation Models requires iOS 27 or later."
        case .deviceNotEligible: "Use an Apple Intelligence-capable device or an Android device supported by Gemini Nano."
        case .intelligenceDisabled: "Turn on Apple Intelligence in Settings, then return here."
        case .modelNotReady: "The system may still be downloading its model. Try again later."
        case .unavailable: "This device cannot currently run the required private model."
        }
    }

    var systemImage: String {
        switch self {
        case .available: "checkmark.shield.fill"
        case .checking, .downloadable, .downloading, .modelNotReady: "arrow.down.circle.fill"
        case .unsupportedOperatingSystem, .deviceNotEligible, .intelligenceDisabled, .unavailable: "exclamationmark.shield.fill"
        }
    }
}

enum OnDeviceAnalyzerError: LocalizedError {
    case invalidPhotoCount
    case modelUnavailable
    case invalidResponse
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .invalidPhotoCount: "Add between one and three photos before analyzing."
        case .modelUnavailable: "The on-device model is not ready. Check the message above and try again."
        case .invalidResponse: "The model could not build a reliable map from these photos. Add a clearer overview or label photo and try again."
        case .unsupportedPlatform: "On-device photo analysis is not supported on this platform."
        }
    }
}

struct AnalysisPayload: Codable, Sendable {
    var title: String
    var summary: String
    var items: [AnalysisItemPayload]
}

struct AnalysisItemPayload: Codable, Sendable {
    var name: String
    var kind: String
    var photoIndex: Int
    var x: Double
    var y: Double
    var likelyPurpose: String
    var unpluggingImpact: String
    var evidenceLevel: String
    var uncertaintyNotes: String
    var safetyWarning: String
}

enum OnDeviceAnalyzer {
    static let analysisPrompt = """
        Treat all attached photos as views of the same unfamiliar technical setup. Identify 5 to 12 important visible components or cable connections. For each item, identify the zero-based photo index where it is clearest and the center x/y location normalized from 0 to 1 in that photo: x=0 is the left edge, x=1 is the right edge, y=0 is the top edge, and y=1 is the bottom edge. Explain its likely purpose and the likely consequence if it is unplugged. Distinguish what is directly observed, inferred, or unclear. Never claim that something is safe to unplug. Add a specific safety warning for mains power, batteries, hidden destinations, active recording, high voltage, or any potentially cascading interruption; otherwise use an empty safety warning. Keep explanations short and grounded only in the photos.
        """

    static func availability() async -> AnalysisAvailability {
        #if os(Android)
        let status = await androidModelStatus()
        return AnalysisAvailability(rawValue: status) ?? .unavailable
        #elseif !SKIP && compiler(>=6.4) && canImport(FoundationModels)
        if #available(iOS 27.0, macOS 27.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                guard model.capabilities.contains(.vision),
                      model.capabilities.contains(.guidedGeneration) else {
                    return .unavailable
                }
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .intelligenceDisabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            case .unavailable:
                return .unavailable
            }
        }
        return .unsupportedOperatingSystem
        #else
        return .unavailable
        #endif
    }

    static func prepareModel() async throws {
        #if os(Android)
        try await downloadAndroidModel()
        #else
        throw OnDeviceAnalyzerError.modelUnavailable
        #endif
    }

    static func analyze(photoURLs: [URL]) async throws -> Guide {
        guard (1...3).contains(photoURLs.count) else {
            throw OnDeviceAnalyzerError.invalidPhotoCount
        }

        #if os(Android)
        let response = try await analyzeWithGeminiNano(
            photoURLStrings: photoURLs.map(\.absoluteString),
            prompt: androidPrompt
        )
        return try guide(fromJSON: response, photoCount: photoURLs.count)
        #elseif !SKIP && compiler(>=6.4) && canImport(FoundationModels)
        if #available(iOS 27.0, macOS 27.0, *) {
            return try await analyzeWithAppleFoundationModels(photoURLs: photoURLs)
        }
        throw OnDeviceAnalyzerError.unsupportedPlatform
        #else
        throw OnDeviceAnalyzerError.unsupportedPlatform
        #endif
    }

    static func guide(fromJSON response: String, photoCount: Int) throws -> Guide {
        let cleanedResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedResponse.data(using: .utf8) else {
            throw OnDeviceAnalyzerError.invalidResponse
        }
        let payload = try JSONDecoder().decode(AnalysisPayload.self, from: data)
        return try guide(from: payload, photoCount: photoCount)
    }

    static func guide(from payload: AnalysisPayload, photoCount: Int) throws -> Guide {
        guard photoCount > 0, (5...12).contains(payload.items.count) else {
            throw OnDeviceAnalyzerError.invalidResponse
        }

        let components = payload.items.enumerated().map { index, item in
            let warning = item.safetyWarning.trimmingCharacters(in: .whitespacesAndNewlines)
            let uncertainty = item.uncertaintyNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            let kind = GuideItemKind(
                rawValue: item.kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            ) ?? .component
            let evidence = EvidenceLevel(
                rawValue: item.evidenceLevel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            ) ?? .unclear
            let safetyWarning: String? = if !warning.isEmpty {
                warning
            } else if evidence == .unclear {
                "The available photos do not identify this item clearly enough to change it. Add a close-up or ask a qualified technician."
            } else {
                nil
            }

            return GuideComponent(
                displayNumber: index + 1,
                name: nonempty(item.name, fallback: "Unidentified item \(index + 1)"),
                kind: kind,
                photoIndex: min(max(item.photoIndex, 0), photoCount - 1),
                location: NormalizedCoordinate(x: clamped(item.x), y: clamped(item.y)),
                likelyPurpose: nonempty(item.likelyPurpose, fallback: "The purpose could not be determined from these photos."),
                unpluggingImpact: nonempty(item.unpluggingImpact, fallback: "The effect of unplugging this item could not be determined."),
                evidenceLevel: evidence,
                uncertaintyNotes: uncertainty.isEmpty ? "The model could not verify this item from the available photos." : uncertainty,
                safetyWarning: safetyWarning
            )
        }

        return Guide(
            title: nonempty(payload.title, fallback: "Unfamiliar setup"),
            summary: nonempty(payload.summary, fallback: "The model found several connected items, but the photos do not prove the full signal or power path."),
            components: components
        )
    }

    static func nonempty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    static func clamped(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    static let androidPrompt = """
        Analyze one to three photos of the same unfamiliar technical setup. Return JSON only, without Markdown, in exactly this shape:
        {"title":"string","summary":"string","items":[{"name":"string","kind":"component or connection","photoIndex":0,"x":0.5,"y":0.5,"likelyPurpose":"string","unpluggingImpact":"string","evidenceLevel":"observed, inferred, or unclear","uncertaintyNotes":"string","safetyWarning":"string or empty"}]}
        Return 5 to 12 important visible items. Coordinates are the item's center normalized from 0 to 1 in the selected zero-based photo: x=0 is the left edge, x=1 is the right edge, y=0 is the top edge, and y=1 is the bottom edge. Explain likely purpose and what may happen if unplugged. Never claim that unplugging is safe. Always state uncertainty. Add a safety warning for mains power, batteries, hidden destinations, active recording, high voltage, or cascading interruption. Ground every claim only in the photos.
        """
}

#if !SKIP && compiler(>=6.4) && canImport(FoundationModels)
@available(iOS 27.0, macOS 27.0, *)
@Generable
struct AppleAnalysisPayload {
    var title: String
    var summary: String
    @Guide(description: "The 5 to 12 most important visible components or connections", .count(5...12))
    var items: [AppleAnalysisItemPayload]

    var commonPayload: AnalysisPayload {
        AnalysisPayload(
            title: title,
            summary: summary,
            items: items.map(\.commonPayload)
        )
    }
}

@available(iOS 27.0, macOS 27.0, *)
@Generable
struct AppleAnalysisItemPayload {
    var name: String
    @Guide(description: "Whether this visible item is a component or connection", .anyOf(["component", "connection"]))
    var kind: String
    @Guide(description: "Zero-based index of the attached photo where this item is clearest", .range(0...2))
    var photoIndex: Int
    @Guide(description: "Horizontal center from 0 at the left edge to 1 at the right edge", .range(0.0...1.0))
    var x: Double
    @Guide(description: "Vertical center from 0 at the top edge to 1 at the bottom edge", .range(0.0...1.0))
    var y: Double
    var likelyPurpose: String
    var unpluggingImpact: String
    @Guide(description: "How the conclusion is supported", .anyOf(["observed", "inferred", "unclear"]))
    var evidenceLevel: String
    var uncertaintyNotes: String
    var safetyWarning: String

    var commonPayload: AnalysisItemPayload {
        AnalysisItemPayload(
            name: name,
            kind: kind,
            photoIndex: photoIndex,
            x: x,
            y: y,
            likelyPurpose: likelyPurpose,
            unpluggingImpact: unpluggingImpact,
            evidenceLevel: evidenceLevel,
            uncertaintyNotes: uncertaintyNotes,
            safetyWarning: safetyWarning
        )
    }
}

@available(iOS 27.0, macOS 27.0, *)
extension OnDeviceAnalyzer {
    static func analyzeWithAppleFoundationModels(photoURLs: [URL]) async throws -> Guide {
        let model = SystemLanguageModel.default
        guard model.availability == .available,
              model.capabilities.contains(.vision),
              model.capabilities.contains(.guidedGeneration) else {
            throw OnDeviceAnalyzerError.modelUnavailable
        }

        let session = LanguageModelSession(
            model: model,
            instructions: analysisPrompt
        )
        let attachments = photoURLs.enumerated().map { index, url in
            Attachment(imageURL: url).label("Photo \(index)")
        }
        let response = try await session.respond(generating: AppleAnalysisPayload.self) {
            analysisPrompt
            attachments
        }
        return try guide(from: response.content.commonPayload, photoCount: photoURLs.count)
    }
}
#endif

#if SKIP
import android.graphics.BitmapFactory
import android.net.Uri
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.content
import com.google.mlkit.genai.prompt.generateContentRequest
import java.lang.IllegalStateException

func androidModelStatus() async -> String {
    let model = Generation.getClient()
    defer { model.close() }
    do {
        let status = try await model.checkStatus()
        switch status {
        case FeatureStatus.AVAILABLE:
            return "available"
        case FeatureStatus.DOWNLOADABLE:
            return "downloadable"
        case FeatureStatus.DOWNLOADING:
            return "downloading"
        default:
            return "unavailable"
        }
    } catch {
        return "unavailable"
    }
}

func downloadAndroidModel() async throws {
    let model = Generation.getClient()
    defer { model.close() }
    try await model.download().collect { status in
        if let failed = status as? DownloadStatus.DownloadFailed {
            throw failed.e
        }
    }
}

func analyzeWithGeminiNano(photoURLStrings: [String], prompt: String) async throws -> String {
    let context = ProcessInfo.processInfo.androidContext
    let bitmaps = try photoURLStrings.map { urlString in
        let stream = context.contentResolver.openInputStream(Uri.parse(urlString))
        guard let stream, let bitmap = BitmapFactory.decodeStream(stream) else {
            throw IllegalStateException("Could not read an attached photo")
        }
        stream.close()
        return bitmap
    }
    let model = Generation.getClient()
    defer { model.close() }
    let requestContent = content {
        image(bitmaps[0])
        if bitmaps.count > 1 {
            image(bitmaps[1])
        }
        if bitmaps.count > 2 {
            image(bitmaps[2])
        }
        text(prompt)
    }
    let response = try await model.generateContent(generateContentRequest(requestContent))
    return response.candidates[0].text
}
#endif
