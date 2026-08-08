import DontUnplugThatShared
import Foundation
import XCTest
import XCTVapor
@testable import DontUnplugThatServer

final class RoutesTests: XCTestCase {
    func testHealthReportsOK() async throws {
        let application = try await Application.make(.testing)
        try configure(application)

        do {
            try await application.test(.GET, "health") { response async throws in
                XCTAssertEqual(response.status, .ok)
                let health = try response.content.decode(HealthResponse.self)
                XCTAssertEqual(health, HealthResponse(status: "ok"))
            }
            try await application.asyncShutdown()
        } catch {
            try? await application.asyncShutdown()
            throw error
        }
    }

    func testAnalyzeReturnsExplanationFixtureGuide() async throws {
        let application = try await Application.make(.testing)
        try configure(application)

        let encodedPhoto = Data("fixture".utf8).base64EncodedString()
        let request = AnalyzeGuideRequest(
            photos: [
                GuidePhoto(base64EncodedImage: encodedPhoto, mediaType: .jpeg),
                GuidePhoto(base64EncodedImage: encodedPhoto, mediaType: .png)
            ]
        )

        do {
            try await application.test(
                .POST,
                "v1/guides/analyze",
                beforeRequest: { outgoingRequest async throws in
                    try outgoingRequest.content.encode(request)
                },
                afterResponse: { response async throws in
                    XCTAssertEqual(response.status, .ok)
                    let analysis = try response.content.decode(AnalyzeGuideResponse.self)
                    XCTAssertEqual(analysis.analysisMode, .fixture)
                    XCTAssertEqual(analysis.guide.title, "Unfamiliar live-audio rack")
                    XCTAssertFalse(analysis.guide.summary.isEmpty)
                    XCTAssertTrue((5...12).contains(analysis.guide.components.count))
                    XCTAssertTrue(
                        analysis.guide.components.allSatisfy { $0.location.isNormalized }
                    )
                    XCTAssertTrue(
                        analysis.guide.components.allSatisfy {
                            request.photos.indices.contains($0.photoIndex)
                        }
                    )
                    XCTAssertTrue(analysis.guide.components.contains { $0.photoIndex == 1 })
                    XCTAssertEqual(
                        Set(analysis.guide.components.map(\.kind)),
                        Set(GuideItemKind.allCases)
                    )
                    XCTAssertEqual(
                        Set(analysis.guide.components.map(\.evidenceLevel)),
                        Set(EvidenceLevel.allCases)
                    )
                    XCTAssertTrue(
                        analysis.guide.components.allSatisfy {
                            !$0.likelyPurpose.isEmpty
                                && !$0.unpluggingImpact.isEmpty
                                && !$0.uncertaintyNotes.isEmpty
                        }
                    )
                    XCTAssertTrue(
                        analysis.guide.components.contains { $0.safetyWarning != nil }
                    )
                    XCTAssertTrue(
                        analysis.guide.components
                            .filter { $0.evidenceLevel == .unclear }
                            .allSatisfy { $0.safetyWarning != nil }
                    )
                    XCTAssertFalse(
                        analysis.guide.components
                            .map(\.uncertaintyNotes)
                            .joined(separator: " ")
                            .lowercased()
                            .contains("confidence")
                    )
                    let warnings = analysis.warnings.joined(separator: " ").lowercased()
                    XCTAssertTrue(warnings.contains("on-device"))
                    XCTAssertTrue(warnings.contains("qualified professional"))
                    XCTAssertTrue(warnings.contains("plumbing"))
                    XCTAssertTrue(warnings.contains("pressure"))
                    XCTAssertEqual(
                        analysis.guide.components.map(\.displayNumber),
                        Array(1...6)
                    )
                }
            )
            try await application.asyncShutdown()
        } catch {
            try? await application.asyncShutdown()
            throw error
        }
    }

    func testAnalyzeRejectsBlankPhoto() async throws {
        let application = try await Application.make(.testing)
        try configure(application)

        let request = AnalyzeGuideRequest(
            photos: [GuidePhoto(base64EncodedImage: "", mediaType: .png)]
        )

        do {
            try await application.test(
                .POST,
                "v1/guides/analyze",
                beforeRequest: { outgoingRequest async throws in
                    try outgoingRequest.content.encode(request)
                },
                afterResponse: { response async in
                    XCTAssertEqual(response.status, .badRequest)
                }
            )
            try await application.asyncShutdown()
        } catch {
            try? await application.asyncShutdown()
            throw error
        }
    }

    func testAnalyzeRejectsNoPhotos() async throws {
        let application = try await Application.make(.testing)
        try configure(application)

        let request = AnalyzeGuideRequest(photos: [])

        do {
            try await application.test(
                .POST,
                "v1/guides/analyze",
                beforeRequest: { outgoingRequest async throws in
                    try outgoingRequest.content.encode(request)
                },
                afterResponse: { response async in
                    XCTAssertEqual(response.status, .badRequest)
                }
            )
            try await application.asyncShutdown()
        } catch {
            try? await application.asyncShutdown()
            throw error
        }
    }
}
