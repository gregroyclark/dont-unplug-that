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

    func testAnalyzeReturnsEditableFixtureGuide() async throws {
        let application = try await Application.make(.testing)
        try configure(application)

        let request = AnalyzeGuideRequest(
            base64EncodedImage: Data("fixture".utf8).base64EncodedString(),
            mediaType: .jpeg,
            suggestedTitle: "Sanctuary rack"
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
                    XCTAssertEqual(analysis.guide.title, "Sanctuary rack")
                    XCTAssertTrue((5...12).contains(analysis.guide.components.count))
                    XCTAssertTrue(
                        analysis.guide.components.allSatisfy { $0.location.isNormalized }
                    )
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

    func testAnalyzeRejectsEmptyImage() async throws {
        let application = try await Application.make(.testing)
        try configure(application)

        let request = AnalyzeGuideRequest(base64EncodedImage: "", mediaType: .png)

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
