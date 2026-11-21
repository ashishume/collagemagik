import ImageIO
import SwiftUI
import UIKit

/// Images are decoded only when they are shown, at the size they are shown, and kept in caches that iOS can empty under
/// memory pressure. Two kinds:
/// - **photo previews** for the live editor (`MediaItem.preview`): decoded from the photo's file the first time a cell
///   shows it, so photos waiting in the tray cost only their small thumbnail;
/// - **files on disk** (draft thumbnails, exports, carousel slides): `AsyncFileImage` decodes them off the main thread,
///   downsampled to the size of the view.
enum ImagePipeline {
    /// Longest side of a photo preview: enough for the largest cell on screen (iPad gets more).
    static let previewPixels: Int = UIDevice.current.userInterfaceIdiom == .pad ? 1600 : 1280

    private static let previews: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 140 * 1024 * 1024 // about 30 phone previews
        return c
    }()

    private static let files: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 60 * 1024 * 1024
        return c
    }()

    private static func cost(_ img: UIImage) -> Int {
        guard let cg = img.cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }

    /// The live-preview copy of a photo, decoded from its file on first use (and again only if it was evicted).
    static func preview(id: String, url: URL) -> UIImage? {
        let key = id as NSString
        if let hit = previews.object(forKey: key) { return hit }
        guard let img = downsample(url, maxPixels: previewPixels) else { return nil }
        previews.setObject(img, forKey: key, cost: cost(img))
        return img
    }

    /// Decodes previews ahead of time, off the main thread (the pictures that were just placed in cells).
    static func warm(_ items: [(id: String, url: URL)]) {
        let missing = items.filter { previews.object(forKey: $0.id as NSString) == nil }
        guard !missing.isEmpty else { return }
        Task.detached(priority: .utility) {
            for m in missing { _ = preview(id: m.id, url: m.url) }
        }
    }

    /// A file's picture, at most `maxPixels` on its longest side.
    static func file(_ url: URL, maxPixels: Int, version: String = "") -> UIImage? {
        let key = "\(url.path)|\(maxPixels)|\(version)" as NSString
        if let hit = files.object(forKey: key) { return hit }
        guard let img = downsample(url, maxPixels: maxPixels) else { return nil }
        files.setObject(img, forKey: key, cost: cost(img))
        return img
    }

    static func cachedFile(_ url: URL, maxPixels: Int, version: String = "") -> UIImage? {
        files.object(forKey: "\(url.path)|\(maxPixels)|\(version)" as NSString)
    }

    /// ImageIO thumbnailing: reads only what it needs from the file and never decodes the full-size picture.
    static func downsample(_ url: URL, maxPixels: Int) -> UIImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOpts) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// A picture file shown at `height` points tall (or fitting `maxSide`), decoded in the background at that size.
/// Shows a soft placeholder until it is ready; nothing is decoded until the view is on screen.
struct AsyncFileImage: View {
    let url: URL
    /// The longest side the view will be, in points.
    let maxSide: CGFloat
    var contentMode: ContentMode = .fit
    /// Changes when the file is rewritten under the same name (a draft's thumbnail), so the new picture is shown.
    var version: String = ""
    @Environment(\.displayScale) private var scale
    @State private var image: UIImage?

    private var pixels: Int { Int((maxSide * scale).rounded(.up)) }

    var body: some View {
        Group {
            if let img = image ?? ImagePipeline.cachedFile(url, maxPixels: pixels, version: version) {
                Image(uiImage: img).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(.white.opacity(0.06))
            }
        }
        .task(id: "\(url.path)|\(version)") {
            guard ImagePipeline.cachedFile(url, maxPixels: pixels, version: version) == nil else { return }
            let u = url, px = pixels, v = version
            let img = await Task.detached(priority: .userInitiated) { ImagePipeline.file(u, maxPixels: px, version: v) }.value
            withAnimation(.easeOut(duration: 0.15)) { image = img }
        }
    }
}
