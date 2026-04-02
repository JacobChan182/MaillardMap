import UIKit

/// Instagram-style export: aggressive but visually acceptable JPEG, capped dimensions to trim upload size and decode cost.
enum SocialImageCompression {
    /// Profile photos: square center crop, max edge similar to IG (small on disk, sharp in circles).
    private static let profileMaxEdgePx: CGFloat = 512
    private static let profileJpegQuality: CGFloat = 0.82

    /// Feed photos: classic IG max long edge 1080px.
    private static let postMaxLongEdgePx: CGFloat = 1080
    private static let postJpegQuality: CGFloat = 0.77

    /// Square avatar: center crop → `profileMaxEdgePx`, then JPEG.
    static func jpegDataForProfileAvatar(_ image: UIImage) -> Data? {
        let square = squareCenterCropped(image, maxEdgePx: profileMaxEdgePx)
        return square.jpegData(compressionQuality: profileJpegQuality)
    }

    /// Post image: preserve aspect, cap long edge to `postMaxLongEdgePx`, then JPEG.
    static func jpegDataForPostPhoto(_ image: UIImage) -> Data? {
        let scaled = scalePreservingAspect(image, maxLongEdgePx: postMaxLongEdgePx)
        return scaled.jpegData(compressionQuality: postJpegQuality)
    }

    // MARK: - Geometry

    private static func normalizedOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func squareCenterCropped(_ image: UIImage, maxEdgePx: CGFloat) -> UIImage {
        let img = normalizedOrientation(image)
        guard let cg = img.cgImage else { return img }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let side = min(w, h)
        let x = (w - side) / 2
        let y = (h - side) / 2
        let rect = CGRect(x: x, y: y, width: side, height: side).integral
        guard let cropped = cg.cropping(to: rect) else { return img }

        let target = min(side, maxEdgePx)
        guard target > 0 else { return img }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let outSize = CGSize(width: target, height: target)
        let renderer = UIGraphicsImageRenderer(size: outSize, format: format)
        let square = UIImage(cgImage: cropped, scale: 1, orientation: .up)
        return renderer.image { _ in
            square.draw(in: CGRect(origin: .zero, size: outSize))
        }
    }

    private static func scalePreservingAspect(_ image: UIImage, maxLongEdgePx: CGFloat) -> UIImage {
        let img = normalizedOrientation(image)
        let pxW = img.size.width * img.scale
        let pxH = img.size.height * img.scale
        let long = max(pxW, pxH)
        guard long > maxLongEdgePx else { return img }

        let s = maxLongEdgePx / long
        let outW = max(1, floor(pxW * s))
        let outH = max(1, floor(pxH * s))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH), format: format)
        return renderer.image { _ in
            img.draw(in: CGRect(x: 0, y: 0, width: outW, height: outH))
        }
    }
}
