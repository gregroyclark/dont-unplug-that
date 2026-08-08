import DontUnplugThatShared
import Foundation

#if !SKIP && os(iOS)
import UIKit
#elseif !SKIP && os(macOS)
import AppKit
#endif

enum GuidePhotoDerivativeError: LocalizedError {
    case invalidPhoto
    case couldNotEncode
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidPhoto: "A selected photo could not be read."
        case .couldNotEncode: "A private sync copy of a photo could not be created."
        case .tooLarge: "A photo is still larger than 5 MiB after safe resizing."
        }
    }
}

enum GuidePhotoDerivative {
    static func make(from urls: [URL]) async throws -> [ProcessedGuidePhoto] {
        guard (1...maximumGuidePhotoCount).contains(urls.count) else {
            throw GuidePhotoDerivativeError.invalidPhoto
        }
        var photos: [ProcessedGuidePhoto] = []
        for (index, url) in urls.enumerated() {
            #if SKIP
            let rendered = try makeAndroidDerivative(urlString: url.absoluteString)
            #elseif os(iOS)
            let rendered = try makeIOSDerivative(url: url)
            #elseif os(macOS)
            let rendered = try makeMacDerivative(url: url)
            #else
            throw GuidePhotoDerivativeError.invalidPhoto
            #endif
            guard rendered.data.count <= maximumGuidePhotoByteCount else {
                throw GuidePhotoDerivativeError.tooLarge
            }
            photos.append(
                ProcessedGuidePhoto(
                    data: rendered.data,
                    descriptor: SyncPhotoDescriptor(
                        index: index,
                        byteCount: rendered.data.count,
                        sha256: PortableDigest.sha256Base64(rendered.data),
                        pixelWidth: rendered.width,
                        pixelHeight: rendered.height
                    )
                )
            )
        }
        return photos
    }
}

private struct RenderedPhoto {
    var data: Data
    var width: Int
    var height: Int
}

#if !SKIP && os(iOS)
private func makeIOSDerivative(url: URL) throws -> RenderedPhoto {
    guard let image = UIImage(contentsOfFile: url.path), let cgImage = image.cgImage else {
        throw GuidePhotoDerivativeError.invalidPhoto
    }
    let rotated = image.imageOrientation == .left || image.imageOrientation == .leftMirrored || image.imageOrientation == .right || image.imageOrientation == .rightMirrored
    let sourceWidth = rotated ? cgImage.height : cgImage.width
    let sourceHeight = rotated ? cgImage.width : cgImage.height
    var size = boundedSize(width: sourceWidth, height: sourceHeight)

    while true {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(
            size: CGSize(width: size.width, height: size.height),
            format: format
        ).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height)))
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height)))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.82) else {
            throw GuidePhotoDerivativeError.couldNotEncode
        }
        if data.count <= maximumGuidePhotoByteCount {
            return RenderedPhoto(data: data, width: Int(size.width), height: Int(size.height))
        }
        guard min(size.width, size.height) > 640 else {
            throw GuidePhotoDerivativeError.tooLarge
        }
        size = (size.width * 0.8, size.height * 0.8)
    }
}
#elseif !SKIP && os(macOS)
private func makeMacDerivative(url: URL) throws -> RenderedPhoto {
    guard let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 else {
        throw GuidePhotoDerivativeError.invalidPhoto
    }
    var size = boundedSize(width: Int(image.size.width), height: Int(image.size.height))
    while true {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 3,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw GuidePhotoDerivativeError.couldNotEncode
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.white.setFill()
        NSRect(origin: .zero, size: NSSize(width: size.width, height: size.height)).fill()
        image.draw(in: NSRect(origin: .zero, size: NSSize(width: size.width, height: size.height)))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
            throw GuidePhotoDerivativeError.couldNotEncode
        }
        if data.count <= maximumGuidePhotoByteCount {
            return RenderedPhoto(data: data, width: Int(size.width), height: Int(size.height))
        }
        guard min(size.width, size.height) > 640 else {
            throw GuidePhotoDerivativeError.tooLarge
        }
        size = (size.width * 0.8, size.height * 0.8)
    }
}
#endif

#if !SKIP
private func boundedSize(width: Int, height: Int) -> (width: Double, height: Double) {
    let scale = min(1.0, Double(maximumGuidePhotoDimension) / Double(max(width, height)))
    return (max(1.0, Double(width) * scale), max(1.0, Double(height) * scale))
}
#endif

#if SKIP
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.net.Uri
import android.os.Build
import androidx.exifinterface.media.ExifInterface

private func makeAndroidDerivative(urlString: String) throws -> RenderedPhoto {
    let context = ProcessInfo.processInfo.androidContext
    let uri = Uri.parse(urlString)
    var bitmap: Bitmap
    if Build.VERSION.SDK_INT >= Build.VERSION_CODES.P {
        bitmap = ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri))
    } else {
        let stream = context.contentResolver.openInputStream(uri)
        guard let stream, let decoded = BitmapFactory.decodeStream(stream) else {
            stream?.close()
            throw GuidePhotoDerivativeError.invalidPhoto
        }
        stream.close()
        bitmap = orientedBitmap(decoded, uri: uri)
    }

    let scale = min(1.0, Double(maximumGuidePhotoDimension) / Double(max(bitmap.width, bitmap.height)))
    if scale < 1.0 {
        bitmap = Bitmap.createScaledBitmap(
            bitmap,
            max(1, Int(Double(bitmap.width) * scale)),
            max(1, Int(Double(bitmap.height) * scale)),
            true
        )
    }
    while true {
        let output = java.io.ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 82, output)
        let data = Data(platformValue: output.toByteArray())
        if data.count <= maximumGuidePhotoByteCount {
            return RenderedPhoto(data: data, width: bitmap.width, height: bitmap.height)
        }
        guard min(bitmap.width, bitmap.height) > 640 else {
            throw GuidePhotoDerivativeError.tooLarge
        }
        bitmap = Bitmap.createScaledBitmap(
            bitmap,
            max(1, Int(Double(bitmap.width) * 0.8)),
            max(1, Int(Double(bitmap.height) * 0.8)),
            true
        )
    }
}

private func orientedBitmap(_ bitmap: Bitmap, uri: Uri) -> Bitmap {
    let context = ProcessInfo.processInfo.androidContext
    guard let stream = context.contentResolver.openInputStream(uri) else {
        return bitmap
    }
    defer { stream.close() }
    let orientation = ExifInterface(stream).getAttributeInt(
        ExifInterface.TAG_ORIENTATION,
        ExifInterface.ORIENTATION_NORMAL
    )
    let matrix = Matrix()
    switch orientation {
    case ExifInterface.ORIENTATION_FLIP_HORIZONTAL:
        matrix.setScale(-1.0, 1.0)
    case ExifInterface.ORIENTATION_ROTATE_180:
        matrix.setRotate(180.0)
    case ExifInterface.ORIENTATION_FLIP_VERTICAL:
        matrix.setScale(1.0, -1.0)
    case ExifInterface.ORIENTATION_TRANSPOSE:
        matrix.setRotate(90.0)
        matrix.postScale(-1.0, 1.0)
    case ExifInterface.ORIENTATION_ROTATE_90:
        matrix.setRotate(90.0)
    case ExifInterface.ORIENTATION_TRANSVERSE:
        matrix.setRotate(-90.0)
        matrix.postScale(-1.0, 1.0)
    case ExifInterface.ORIENTATION_ROTATE_270:
        matrix.setRotate(-90.0)
    default:
        return bitmap
    }
    return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
}
#endif
