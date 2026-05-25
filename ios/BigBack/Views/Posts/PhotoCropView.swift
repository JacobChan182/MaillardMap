import SwiftUI
import UIKit

// MARK: - Aspect ratio

enum CropAspectRatio: CaseIterable, Hashable {
    case landscape  // 16:9
    case square     // 1:1
    case portrait   // 9:16

    var widthOverHeight: CGFloat {
        switch self {
        case .landscape: return 16.0 / 9.0
        case .square:    return 1.0
        case .portrait:  return 9.0 / 16.0
        }
    }

    var label: String {
        switch self {
        case .landscape: return "16:9"
        case .square:    return "1:1"
        case .portrait:  return "9:16"
        }
    }

    var icon: String {
        switch self {
        case .landscape: return "rectangle"
        case .square:    return "square"
        case .portrait:  return "rectangle.portrait"
        }
    }
}

// MARK: - Crop sheet

struct PhotoCropSheet: View {
    let image: UIImage
    let photoNumber: Int
    let totalPhotos: Int
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var ratio: CropAspectRatio = .portrait
    @State private var scrollView: CropScrollView?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let cropRect = cropWindow(ratio: ratio, in: geo.size)
                ZStack {
                    Color.black
                    CropScrollViewRepresentable(
                        image: image,
                        cropRect: cropRect,
                        onReady: { sv in scrollView = sv }
                    )
                    CropOverlay(cropRect: cropRect)
                        .allowsHitTesting(false)
                }
            }
            .background(.black)
            .navigationTitle(totalPhotos > 1 ? "Photo \(photoNumber) of \(totalPhotos)" : "Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") {
                        guard let img = scrollView?.croppedImage() else { return }
                        onConfirm(img)
                    }
                    .foregroundStyle(.orange)
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                ratioBar
                    .background(.black)
            }
        }
    }

    private var ratioBar: some View {
        HStack(spacing: 0) {
            ForEach(CropAspectRatio.allCases, id: \.self) { r in
                Button {
                    withAnimation(.snappy(duration: 0.22)) { ratio = r }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: r.icon)
                            .font(.title2)
                        Text(r.label)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(ratio == r ? .orange : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cropWindow(ratio r: CropAspectRatio, in size: CGSize) -> CGRect {
        let hPad: CGFloat = 20
        let vPad: CGFloat = 16
        var w = size.width - hPad * 2
        var h = w / r.widthOverHeight
        let maxH = size.height - vPad * 2
        if h > maxH {
            h = maxH
            w = h * r.widthOverHeight
        }
        return CGRect(
            x: (size.width - w) / 2,
            y: (size.height - h) / 2,
            width: w, height: h
        )
    }
}

// MARK: - Overlay (semi-transparent mask with hole + rule-of-thirds grid)

private struct CropOverlay: View {
    let cropRect: CGRect

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.55)))
            ctx.blendMode = .clear
            ctx.fill(
                RoundedRectangle(cornerRadius: 3).path(in: cropRect),
                with: .color(.black)
            )
            ctx.blendMode = .normal
            ctx.stroke(
                RoundedRectangle(cornerRadius: 3).path(in: cropRect),
                with: .color(.white.opacity(0.85)),
                style: StrokeStyle(lineWidth: 1.5)
            )
            let gridColor = GraphicsContext.Shading.color(.white.opacity(0.22))
            for i in 1..<3 {
                let f = CGFloat(i) / 3
                var v = Path()
                let gx = cropRect.minX + cropRect.width * f
                v.move(to: CGPoint(x: gx, y: cropRect.minY))
                v.addLine(to: CGPoint(x: gx, y: cropRect.maxY))
                ctx.stroke(v, with: gridColor, lineWidth: 0.75)

                var h = Path()
                let gy = cropRect.minY + cropRect.height * f
                h.move(to: CGPoint(x: cropRect.minX, y: gy))
                h.addLine(to: CGPoint(x: cropRect.maxX, y: gy))
                ctx.stroke(h, with: gridColor, lineWidth: 0.75)
            }
        }
    }
}

// MARK: - UIViewRepresentable bridge

private struct CropScrollViewRepresentable: UIViewRepresentable {
    let image: UIImage
    let cropRect: CGRect
    let onReady: (CropScrollView) -> Void

    func makeUIView(context: Context) -> CropContainer {
        let sv = CropScrollView(image: image)
        let container = CropContainer(scrollView: sv)
        onReady(sv)
        return container
    }

    func updateUIView(_ container: CropContainer, context: Context) {
        container.pendingCropRect = cropRect
        container.setNeedsLayout()
    }
}

// MARK: - Container view (ensures layout is valid before configuring)

final class CropContainer: UIView {
    private let scrollView: CropScrollView
    var pendingCropRect: CGRect = .zero

    init(scrollView: CropScrollView) {
        self.scrollView = scrollView
        super.init(frame: .zero)
        backgroundColor = .clear
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }
        scrollView.frame = bounds
        if !pendingCropRect.isEmpty {
            scrollView.configure(cropRect: pendingCropRect, areaSize: bounds.size)
        }
    }
}

// MARK: - Scroll view (pan + zoom within crop area)

final class CropScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private let img: UIImage
    private var baseSize: CGSize = .zero
    private var lastCropRect: CGRect = .zero
    private var lastAreaSize: CGSize = .zero

    init(image: UIImage) {
        self.img = Self.normalize(image)
        super.init(frame: .zero)
        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        clipsToBounds = true
        backgroundColor = .clear
        decelerationRate = .fast
        imageView.image = img
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Sizes the imageView to fill `areaSize` at zoom 1.0, then centers the image over `cropRect`.
    func configure(cropRect: CGRect, areaSize: CGSize) {
        guard cropRect != lastCropRect || areaSize != lastAreaSize else { return }
        lastCropRect = cropRect
        lastAreaSize = areaSize

        let imgSize = img.size
        guard imgSize.width > 0, areaSize.width > 0 else { return }

        let scale = max(areaSize.width / imgSize.width, areaSize.height / imgSize.height)
        baseSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
        imageView.frame = CGRect(origin: .zero, size: baseSize)
        contentSize = baseSize
        minimumZoomScale = 1.0
        maximumZoomScale = 4.0
        zoomScale = 1.0

        let ox = baseSize.width / 2 - cropRect.midX
        let oy = baseSize.height / 2 - cropRect.midY
        let maxX = max(0, contentSize.width - bounds.width)
        let maxY = max(0, contentSize.height - bounds.height)
        contentOffset = CGPoint(x: min(max(0, ox), maxX), y: min(max(0, oy), maxY))
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    /// Extracts the pixels visible within `lastCropRect` at the current scroll/zoom state.
    func croppedImage() -> UIImage? {
        guard let cg = img.cgImage, baseSize.width > 0 else { return nil }

        let z = zoomScale
        // cropRect is in scroll view frame coords; add contentOffset to get content coords.
        // Divide by z to get base (zoom-1) imageView coords.
        let bx = (lastCropRect.minX + contentOffset.x) / z
        let by = (lastCropRect.minY + contentOffset.y) / z
        let bw = lastCropRect.width / z
        let bh = lastCropRect.height / z

        let sx = CGFloat(cg.width) / baseSize.width
        let sy = CGFloat(cg.height) / baseSize.height

        let pixRect = CGRect(x: bx * sx, y: by * sy, width: bw * sx, height: bh * sy).integral
        let imgBounds = CGRect(x: 0, y: 0, width: CGFloat(cg.width), height: CGFloat(cg.height))
        let clamped = pixRect.intersection(imgBounds)
        guard clamped.width > 1, clamped.height > 1 else { return nil }
        guard let cropped = cg.cropping(to: clamped) else { return nil }
        return UIImage(cgImage: cropped, scale: img.scale, orientation: .up)
    }

    private static func normalize(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: fmt).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
