import SwiftUI
import PhotosUI
import UIKit

struct CreatePostView: View {
    @ObservedObject var vm: CreatePostViewModel
    @Binding var showRestaurantPicker: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Restaurant selector
                Button {
                    showRestaurantPicker = true
                } label: {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.orange)
                        if let r = vm.selectedRestaurant {
                            Text(r.name)
                                .foregroundStyle(.primary)
                        } else {
                            Text("Select restaurant")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                }

                StarRatingPicker(rating: $vm.visitRating)

                // Photos (thumbnails in main body; PhotosPicker label stays Sendable-safe)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Photos")
                            .font(.headline)
                        Spacer()
                        Text(vm.progressString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !vm.selectedPhotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(vm.selectedPhotos.indices, id: \.self) { i in
                                    Image(uiImage: vm.selectedPhotos[i])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .frame(height: 120)
                    }

                    PhotosPicker(
                        selection: $vm.selectedPhotoItems,
                        maxSelectionCount: vm.maxPhotos,
                        matching: .images
                    ) {
                        Label("Add or change photos", systemImage: "photo.badge.plus")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    .onChange(of: vm.selectedPhotoItems) { _, items in
                        Task { await vm.loadPhotos(from: items) }
                    }
                }

                // Comment
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Comment")
                            .font(.headline)
                        Spacer()
                        Text(vm.charCount)
                            .font(.caption)
                            .foregroundStyle(vm.commentValid ? Color.secondary : Color.red)
                    }

                    TextEditor(text: $vm.comment)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)

                    Text("Max \(vm.maxCommentLength) characters")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Post button
                Button {
                    Task { await vm.post() }
                } label: {
                    Text("Post")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .disabled(!vm.canSubmit || vm.isPosting)
                .overlay {
                    if vm.isPosting {
                        ProgressView()
                    }
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }
}
