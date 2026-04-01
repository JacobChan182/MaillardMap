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

    private let api: APIClient

    let maxPhotos = 3
    let maxCommentLength = 200

    init(api: APIClient = .live()) {
        self.api = api
    }

    var commentValid: Bool {
        !comment.isEmpty && comment.count <= maxCommentLength
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

        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            // TODO: Upload to S3 for real photo URLs
            let photoUrls = selectedPhotos.indices.map { i in
                "https://placeholder/bigback/photo-\(i).jpg"
            }

            let req = CreatePostRequest(
                foursquare_id: restaurant.foursquareId,
                comment: comment,
                photo_urls: selectedPhotos.isEmpty ? nil : photoUrls
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
        errorMessage = nil
        didPost = false
    }
}
