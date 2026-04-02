import Foundation
import UIKit
import SwiftUI
import PhotosUI

@MainActor
final class CreatePostViewModel: ObservableObject {
    @Published var selectedRestaurant: Restaurant?
    @Published var comment = ""
    @Published var selectedPhotos: [UIImage] = []
    @Published var selectedPhotoItems: [PhotosPickerItem] = []
    @Published var errorMessage: String?
    @Published var isPosting = false
    @Published var didPost = false
    /// Half-star rating 0.5…5; required before posting.
    @Published var visitRating: Double?

    private let api: APIClient

    let maxPhotos = 3
    let maxCommentLength = 200

    init(api: APIClient = .live()) {
        self.api = api
    }

    var commentValid: Bool {
        !comment.isEmpty && comment.count <= maxCommentLength
    }

    var canSubmit: Bool {
        commentValid && selectedRestaurant != nil && visitRating != nil
    }

    var progressString: String {
        "\(selectedPhotos.count)/\(maxPhotos) photos"
    }

    var charCount: String {
        "\(comment.count)/\(maxCommentLength)"
    }

    func loadPhotos(from items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                images.append(img)
            }
        }
        selectedPhotos = Array(images.prefix(maxPhotos))
    }

    func post() async {
        guard let restaurant = selectedRestaurant else {
            errorMessage = "Select a restaurant first"
            return
        }
        guard !comment.isEmpty else {
            errorMessage = "Add a comment"
            return
        }
        guard comment.count <= maxCommentLength else {
            errorMessage = "Comment too long (max \(maxCommentLength) chars)"
            return
        }
        guard selectedPhotos.count <= maxPhotos else {
            errorMessage = "Too many photos (max \(maxPhotos))"
            return
        }
        guard let rating = visitRating else {
            errorMessage = "Add a star rating"
            return
        }

        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            let photoUrls: [String]?
            if selectedPhotos.isEmpty {
                photoUrls = nil
            } else {
                let contentType = "image/jpeg"
                let slots = try await api.presignPhotoUploads(contentType: contentType, count: selectedPhotos.count)
                guard slots.count == selectedPhotos.count else {
                    errorMessage = "Upload failed: unexpected server response"
                    return
                }
                var urls: [String] = []
                urls.reserveCapacity(slots.count)
                for (i, slot) in slots.enumerated() {
                    let photo = selectedPhotos[i]
                    let compressed = await Task.detached(priority: .userInitiated) {
                        SocialImageCompression.jpegDataForPostPhoto(photo)
                    }.value
                    guard let data = compressed else {
                        errorMessage = "Could not prepare photo \(i + 1)"
                        return
                    }
                    guard let putURL = URL(string: slot.uploadUrl) else {
                        errorMessage = "Invalid upload URL"
                        return
                    }
                    try await api.uploadToPresignedURL(putURL, data: data, contentType: contentType)
                    urls.append(slot.publicUrl)
                }
                photoUrls = urls
            }

            let req = CreatePostRequest(
                foursquare_id: restaurant.foursquareId,
                comment: comment,
                photo_urls: photoUrls,
                rating: rating
            )
            _ = try await api.createPost(req)
            didPost = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        selectedRestaurant = nil
        comment = ""
        selectedPhotos = []
        selectedPhotoItems = []
        visitRating = nil
        errorMessage = nil
        didPost = false
    }
}
