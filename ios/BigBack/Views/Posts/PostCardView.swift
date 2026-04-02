import SwiftUI
import UIKit

/// Shows one remote image aspect-fitted to the scroll view width (no cropping at 1×) with pinch zoom and pan.
private final class AspectFitZoomScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private var loadedURLString: String?
    private var dataTask: URLSessionDataTask?
    /// Tracks width used for layout so a change (e.g. rotation) resets zoom.
    private var laidOutWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        bouncesZoom = true
        showsHorizontalScrollIndicator = true
        showsVerticalScrollIndicator = true
        backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError() }

    func loadPhoto(urlString: String) {
        guard loadedURLString != urlString else { return }
        loadedURLString = urlString
        dataTask?.cancel()
        imageView.image = nil
        zoomScale = 1
        contentInset = .zero
        laidOutWidth = 0
        invalidateIntrinsicContentSize()

        guard let url = URL(string: urlString) else { return }
        dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let img = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                guard self?.loadedURLString == urlString else { return }
                self?.imageView.image = img
                self?.setNeedsLayout()
                self?.layoutIfNeeded()
            }
        }
        dataTask?.resume()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, imageView.image != nil else { return }
        if abs(bounds.width - laidOutWidth) > 0.5 {
            resetToAspectFitLayout()
        }
    }

    private func resetToAspectFitLayout() {
        guard let img = imageView.image, bounds.width > 0 else { return }
        laidOutWidth = bounds.width
        zoomScale = 1
        contentInset = .zero
        let w = bounds.width
        let h = w * img.size.height / img.size.width
        imageView.frame = CGRect(x: 0, y: 0, width: w, height: h)
        contentSize = CGSize(width: w, height: h)
        recenterImage()
        invalidateIntrinsicContentSize()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        recenterImage()
    }

    /// Keeps the image centered when smaller than the viewport; 1× height matches aspect-fit image height.
    private func recenterImage() {
        let iv = imageView
        let W = bounds.width
        let H = bounds.height
        let w = iv.frame.width
        let h = iv.frame.height
        var x: CGFloat = 0
        var y: CGFloat = 0
        if w < W { x = floor((W - w) * 0.5) }
        if h < H { y = floor((H - h) * 0.5) }
        iv.frame.origin = CGPoint(x: x, y: y)
    }

    override var intrinsicContentSize: CGSize {
        guard let img = imageView.image else {
            return CGSize(width: UIView.noIntrinsicMetric, height: 160)
        }
        let parentW: CGFloat
        if bounds.width > 0 {
            parentW = bounds.width
        } else if let sw = superview?.bounds.width, sw > 0 {
            parentW = sw
        } else {
            return CGSize(width: UIView.noIntrinsicMetric, height: 160)
        }
        let fittedH = parentW * img.size.height / img.size.width
        return CGSize(width: UIView.noIntrinsicMetric, height: fittedH)
    }
}

private struct PostDetailZoomablePhoto: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> AspectFitZoomScrollView {
        AspectFitZoomScrollView()
    }

    func updateUIView(_ uiView: AspectFitZoomScrollView, context: Context) {
        uiView.loadPhoto(urlString: urlString)
    }
}

/// Parses post `createdAt` ISO8601 strings from the API (with or without fractional seconds).
private func postCreatedDate(from iso: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: iso) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: iso)
}

/// Relative age for feed cards: days (<14), then weeks (<30 days), then months (<365 days), then years.
private func relativePostAge(from postDate: Date, now: Date = Date()) -> String {
    let cal = Calendar.current
    let startPost = cal.startOfDay(for: postDate)
    let startNow = cal.startOfDay(for: now)
    guard let days = cal.dateComponents([.day], from: startPost, to: startNow).day else {
        return ""
    }
    if days <= 0 {
        return "Today"
    }
    if days < 14 {
        return "\(days) \(days == 1 ? "day" : "days") ago"
    }
    if days < 30 {
        let weeks = days / 7
        return "\(weeks) \(weeks == 1 ? "week" : "weeks") ago"
    }
    if days < 365 {
        let months = max(1, days / 30)
        return "\(months) \(months == 1 ? "month" : "months") ago"
    }
    let years = max(1, days / 365)
    return "\(years) \(years == 1 ? "year" : "years") ago"
}

/// Feed: stacked peek cards with cropped thumbnails. Detail: full-width aspect-fit images with pinch zoom.
private struct PostCardStackedPhotos: View {
    let photos: [PostPhoto]
    var variant: PostCardVariant = .feed

    private var sorted: [PostPhoto] {
        photos.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        switch variant {
        case .feed:
            feedStack
        case .detail:
            detailList
        }
    }

    private var feedStack: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.82, 330)
            let height: CGFloat = 190
            let peek: CGFloat = 22
            ZStack {
                if sorted.count > 1 {
                    feedPhotoView(urlString: sorted[1].url, width: width, height: height)
                        .scaleEffect(0.93)
                        .rotationEffect(.degrees(3))
                        .offset(x: peek + 6)
                        .zIndex(0)
                }
                feedPhotoView(urlString: sorted[0].url, width: width, height: height)
                    .shadow(color: .black.opacity(0.14), radius: 4, x: 3, y: 0)
                    .zIndex(1)
            }
            .frame(width: geo.size.width, height: height, alignment: .center)
        }
        .frame(height: 190)
        .frame(maxWidth: .infinity)
    }

    private var detailList: some View {
        VStack(spacing: 16) {
            ForEach(sorted) { photo in
                PostDetailZoomablePhoto(urlString: photo.url)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private func feedPhotoView(urlString: String, width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Color.gray.opacity(0.3)
            case .empty:
                Color.gray.opacity(0.2)
            @unknown default:
                Color.gray.opacity(0.3)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

enum PostCardVariant {
    /// Feed / profile lists: capped caption, card chrome, optional comments sheet.
    case feed
    /// Full-screen post detail: full caption, no card border.
    case detail
}

struct PostCardView: View {
    let post: Post
    /// Return updated post after toggling like, or `nil` on failure / no local change.
    let onLike: (String) async -> Post?
    var onRestaurantTap: (() -> Void)?
    var variant: PostCardVariant = .feed
    /// When set, tapping the card (or comment affordance) opens post detail instead of a sheet.
    var onOpenDetail: (() -> Void)? = nil

    @State private var showComments = false

    private var commentCountForDisplay: Int {
        post.commentCount
    }

    private var likeCountLabel: String {
        post.likeCount == 1 ? "1 Like" : "\(post.likeCount) Likes"
    }

    private var commentCountLabel: String {
        commentCountForDisplay == 1 ? "1 Comment" : "\(commentCountForDisplay) Comments"
    }

    private var authorDisplayName: String {
        let n = post.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? post.username : n
    }

    init(
        post: Post,
        onLike: @escaping (String) async -> Post?,
        onRestaurantTap: (() -> Void)? = nil,
        variant: PostCardVariant = .feed,
        onOpenDetail: (() -> Void)? = nil
    ) {
        self.post = post
        self.onLike = onLike
        self.onRestaurantTap = onRestaurantTap
        self.variant = variant
        self.onOpenDetail = onOpenDetail
    }

    private var useCommentsSheet: Bool {
        variant == .feed && onOpenDetail == nil
    }

    private func openCommentsOrDetail() {
        if let onOpenDetail {
            onOpenDetail()
        } else if variant == .feed {
            showComments = true
        }
    }

    private var commentsSheetPresented: Binding<Bool> {
        Binding(
            get: { showComments && useCommentsSheet },
            set: { newVal in
                if !newVal { showComments = false }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ProfileAvatarLink(
                    userId: post.userId,
                    url: post.avatarUrl,
                    name: authorDisplayName,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 0) {
                    Text(authorDisplayName)
                        .font(.headline)
                    if post.displayName != nil,
                       let dn = post.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !dn.isEmpty,
                       dn.caseInsensitiveCompare(post.username) != .orderedSame {
                        Text("@\(post.username)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let onRestaurantTap {
                    Button(action: onRestaurantTap) {
                        Text(post.restaurantName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(post.restaurantName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let r = post.rating {
                HStack {
                    Spacer(minLength: 0)
                    StarRatingDisplay(rating: r, starSize: 15)
                    Spacer(minLength: 0)
                }
            }

            if !post.photos.isEmpty {
                PostCardStackedPhotos(photos: post.photos, variant: variant)
                    .padding(.vertical, 6)
            }

            if let comment = post.comment, !comment.isEmpty {
                Text(comment)
                    .font(.body)
                    .lineLimit(variant == .feed ? 3 : nil)
            }

            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 16) {
                    Button {
                        Task { _ = await onLike(post.id) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: post.liked ? "heart.fill" : "heart")
                                .foregroundStyle(post.liked ? .red : .secondary)
                            Text(likeCountLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)

                    Button(action: openCommentsOrDetail) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.bubble")
                                .foregroundStyle(.secondary)
                            Text(commentCountLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 8)
                if let created = postCreatedDate(from: post.createdAt) {
                    Text(relativePostAge(from: created))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.top, 2)
        }
        .padding(variant == .feed ? 16 : 0)
        .padding(.bottom, variant == .detail ? 8 : 0)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: variant == .feed ? 12 : 0))
        .overlay {
            if variant == .feed {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.gray.opacity(0.35), lineWidth: 1)
            }
        }
        .shadow(color: variant == .feed ? .black.opacity(0.12) : .clear, radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if onOpenDetail != nil { openCommentsOrDetail() }
        }
        .sheet(isPresented: commentsSheetPresented) {
            NavigationStack {
                CommentsView(postId: post.id)
                    .navigationTitle("Comments")
                    .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }
}
