import DontUnplugThatShared
import Foundation
import Testing
@testable import DontUnplugThat

#if os(iOS)
import UIKit

@MainActor
@Test("Photo derivative is bounded JPEG without private metadata segments")
func derivativeBoundsAndStripsMetadata() async throws {
    let root = URL.temporaryDirectory.appendingPathComponent("dut-derivative-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source.png")
    let image = UIGraphicsImageRenderer(size: CGSize(width: 3_000, height: 1_000)).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 3_000, height: 1_000))
    }
    try #require(image.pngData()).write(to: source)

    let photo = try #require(await GuidePhotoDerivative.make(from: [source]).first)

    #expect(photo.descriptor.pixelWidth == 2_048)
    #expect(photo.descriptor.pixelHeight < photo.descriptor.pixelWidth)
    #expect(photo.data.count <= maximumGuidePhotoByteCount)
    #expect(photo.data[0] == 0xff && photo.data[1] == 0xd8)
    #expect(!containsPrivateJPEGMetadata(photo.data))
}

private func containsPrivateJPEGMetadata(_ data: Data) -> Bool {
    var offset = 2
    while offset + 3 < data.count {
        guard data[offset] == 0xff else { return true }
        let marker = data[offset + 1]
        if marker == 0xd9 || marker == 0xda { return false }
        if marker == 0x00 || marker == 0x01 || (0xd0...0xd7).contains(marker) {
            offset += 2
            continue
        }
        let length = Int(data[offset + 2]) * 256 + Int(data[offset + 3])
        if length < 2 || offset + 2 + length > data.count { return true }
        if marker == 0xe1 || marker == 0xe2 || marker == 0xed || marker == 0xfe {
            return true
        }
        offset += 2 + length
    }
    return false
}
#endif
