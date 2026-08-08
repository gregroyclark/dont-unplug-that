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
                    .tint(.white)
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

func androidPhotoAspectRatio(urlString: String) -> Double {
    let context = ProcessInfo.processInfo.androidContext
    let stream = context.contentResolver.openInputStream(Uri.parse(urlString))
    guard let stream, let bitmap = BitmapFactory.decodeStream(stream), bitmap.height > 0 else {
        stream?.close()
        return 4.0 / 3.0
    }
    stream.close()
    return Double(bitmap.width) / Double(bitmap.height)
}
#endif
