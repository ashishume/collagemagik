import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// A one-tap look for a photo.
enum PhotoFilter: String, CaseIterable, Identifiable, Codable {
    case none, vivid, warm, cool, fade, film, chrome, vintage, mono, noir
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Original"
        case .vivid: "Vivid"
        case .warm: "Warm"
        case .cool: "Cool"
        case .fade: "Fade"
        case .film: "Film"
        case .chrome: "Chrome"
        case .vintage: "Vintage"
        case .mono: "Mono"
        case .noir: "Noir"
        }
    }
}

/// How a photo in a cell is coloured: a filter, then four fine adjustments (each -1...1, 0 = unchanged).
/// Photos only; a video plays as it is.
struct PhotoLook: Equatable, Codable, Hashable {
    var filter: PhotoFilter = .none
    var brightness: Double = 0
    var contrast: Double = 0
    var saturation: Double = 0
    var warmth: Double = 0

    var isOriginal: Bool { filter == .none && brightness == 0 && contrast == 0 && saturation == 0 && warmth == 0 }
    var key: String { "\(filter.rawValue)|\(brightness)|\(contrast)|\(saturation)|\(warmth)" }
}

/// Applies a `PhotoLook`. The live preview and every export go through here, so a look shows exactly as it exports.
enum PhotoLookRenderer {
    private static let ci = CIContext(options: [.cacheIntermediates: false])
    private static let cache: NSCache<NSString, CGImage> = {
        let c = NSCache<NSString, CGImage>()
        c.countLimit = 40
        return c
    }()

    /// `image` with `look` applied. `key` names the picture (its id), so a result is reused until the look changes.
    static func apply(_ image: CGImage, _ look: PhotoLook, key: String) -> CGImage {
        guard !look.isOriginal else { return image }
        let k = "\(key)|\(image.width)x\(image.height)|\(look.key)" as NSString
        if let hit = cache.object(forKey: k) { return hit }
        let input = CIImage(cgImage: image)
        var out = filtered(input, look.filter)
        out = adjusted(out, look)
        guard let made = ci.createCGImage(out.cropped(to: input.extent), from: input.extent) else { return image }
        cache.setObject(made, forKey: k)
        return made
    }

    /// The same for the preview's UIImage.
    static func apply(_ image: UIImage, _ look: PhotoLook, key: String) -> UIImage {
        guard !look.isOriginal, let cg = image.cgImage else { return image }
        return UIImage(cgImage: apply(cg, look, key: key), scale: image.scale, orientation: image.imageOrientation)
    }

    private static func filtered(_ img: CIImage, _ f: PhotoFilter) -> CIImage {
        switch f {
        case .none:
            return img
        case .vivid:
            let v = CIFilter.vibrance()
            v.inputImage = img
            v.amount = 0.6
            let c = CIFilter.colorControls()
            c.inputImage = v.outputImage
            c.saturation = 1.18
            c.contrast = 1.08
            return c.outputImage ?? img
        case .warm:
            return temperature(img, shift: 1)
        case .cool:
            return temperature(img, shift: -1)
        case .fade:
            let c = CIFilter.colorControls()
            c.inputImage = img
            c.contrast = 0.82
            c.saturation = 0.78
            let lift = CIFilter.colorMatrix()
            lift.inputImage = c.outputImage
            lift.biasVector = CIVector(x: 0.07, y: 0.065, z: 0.06, w: 0)
            return lift.outputImage ?? img
        case .film:
            return effect(img, CIFilter.photoEffectInstant())
        case .chrome:
            return effect(img, CIFilter.photoEffectChrome())
        case .vintage:
            let t = effect(img, CIFilter.photoEffectTransfer())
            let v = CIFilter.vignette()
            v.inputImage = t
            v.intensity = 0.6
            v.radius = Float(max(img.extent.width, img.extent.height) * 0.0012)
            return v.outputImage ?? t
        case .mono:
            return effect(img, CIFilter.photoEffectMono())
        case .noir:
            return effect(img, CIFilter.photoEffectNoir())
        }
    }

    private static func effect(_ img: CIImage, _ f: some CIFilter & CIPhotoEffect) -> CIImage {
        f.inputImage = img
        return f.outputImage ?? img
    }

    /// Warmer (+) or cooler (-): the white point moves towards amber or blue.
    private static func temperature(_ img: CIImage, shift: Double) -> CIImage {
        let t = CIFilter.temperatureAndTint()
        t.inputImage = img
        t.neutral = CIVector(x: 6500, y: 0)
        // a lower target white point renders the picture warmer (checked against exports: + is amber, - is blue)
        t.targetNeutral = CIVector(x: 6500 - shift * 1500, y: 0)
        return t.outputImage ?? img
    }

    private static func adjusted(_ img: CIImage, _ l: PhotoLook) -> CIImage {
        var out = img
        if l.brightness != 0 || l.contrast != 0 || l.saturation != 0 {
            let c = CIFilter.colorControls()
            c.inputImage = out
            c.brightness = Float(l.brightness * 0.22)
            c.contrast = Float(1 + l.contrast * 0.35)
            c.saturation = Float(max(0, 1 + l.saturation))
            out = c.outputImage ?? out
        }
        if l.warmth != 0 { out = temperature(out, shift: l.warmth) }
        return out
    }
}
