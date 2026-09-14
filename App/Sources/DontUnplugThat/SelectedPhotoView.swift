import SwiftUI

#if !SKIP && os(iOS)
import UIKit
#elseif !SKIP && os(macOS)
import AppKit
#endif

struct SelectedPhotoView: View {
    let url: URL?

    @ViewBuilder var body: some View {
        if let url {
            #if SKIP
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
                    .tint(AppTheme.accent)
            }
            #elseif os(iOS)
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                EquipmentPlaceholderView()
            }
            #elseif os(macOS)
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                EquipmentPlaceholderView()
            }
            #else
            EquipmentPlaceholderView()
            #endif
        } else {
            EquipmentPlaceholderView()
        }
    }
}

enum SelectedPhotoMetadata {
    static let fallbackAspectRatio = 4.0 / 3.0

    static func aspectRatio(for url: URL?) async -> Double {
        guard let url else {
            return fallbackAspectRatio
        }

        #if os(Android)
        return androidPhotoAspectRatio(urlString: url.absoluteString)
        #elseif os(iOS)
        guard let image = UIImage(contentsOfFile: url.path), image.size.height > 0 else {
            return fallbackAspectRatio
        }
        return image.size.width / image.size.height
        #elseif os(macOS)
        guard let image = NSImage(contentsOf: url), image.size.height > 0 else {
            return fallbackAspectRatio
        }
        return image.size.width / image.size.height
        #else
        return fallbackAspectRatio
        #endif
    }
}

#if SKIP
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.exifinterface.media.ExifInterface

func androidPhotoAspectRatio(urlString: String) -> Double {
    let context = ProcessInfo.processInfo.androidContext
    let uri = Uri.parse(urlString)
    do {
        guard let stream = context.contentResolver.openInputStream(uri) else { return 4.0 / 3.0 }
        defer { stream.close() }
        let options = BitmapFactory.Options()
        options.inJustDecodeBounds = true
        BitmapFactory.decodeStream(stream, nil, options)
        guard options.outWidth > 0, options.outHeight > 0 else { return 4.0 / 3.0 }
        guard let metadata = context.contentResolver.openInputStream(uri) else { return 4.0 / 3.0 }
        defer { metadata.close() }
        let orientation = ExifInterface(metadata).getAttributeInt(
            ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
        )
        let swapsAxes = orientation == ExifInterface.ORIENTATION_TRANSPOSE
            || orientation == ExifInterface.ORIENTATION_ROTATE_90
            || orientation == ExifInterface.ORIENTATION_TRANSVERSE
            || orientation == ExifInterface.ORIENTATION_ROTATE_270
        return swapsAxes
            ? Double(options.outHeight) / Double(options.outWidth)
            : Double(options.outWidth) / Double(options.outHeight)
    } catch {
        return 4.0 / 3.0
    }
}
#endif
