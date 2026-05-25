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

                // Photos
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Photos")
                            .font(.headline)
                        Spacer()
                        Text(vm.progressString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        // Existing photo thumbnails with remove button
                        ForEach(vm.selectedPhotos.indices, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: vm.selectedPhotos[i])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(10)
                                    .clipped()
                                Button {
                                    vm.removePhoto(at: i)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.black.opacity(0.6))
                                        .font(.system(size: 20))
                                        .padding(4)
                                }
                            }
                        }

                        // Add-one slot (shows when room remains)
                        if vm.selectedPhotos.count < vm.maxPhotos {
                            if vm.selectedPhotos.isEmpty {
                                // Initial: full-width multi-select picker
                                PhotosPicker(
                                    selection: $vm.selectedPhotoItems,
                                    maxSelectionCount: vm.maxPhotos,
                                    matching: .images
                                ) {
                                    Label("Add photos", systemImage: "photo.badge.plus")
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .cornerRadius(12)
                                }
                                .onChange(of: vm.selectedPhotoItems) { _, items in
                                    Task { await vm.loadPhotos(from: items) }
                                }
                            } else {
                                // Subsequent: single-photo add slot
                                PhotosPicker(
                                    selection: $vm.addPhotoItems,
                                    maxSelectionCount: 1,
                                    matching: .images
                                ) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(uiColor: .secondarySystemBackground))
                                            .frame(width: 100, height: 100)
                                        Image(systemName: "plus")
                                            .font(.title2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .onChange(of: vm.addPhotoItems) { _, items in
                                    guard let item = items.first else { return }
                                    Task { await vm.addSinglePhoto(from: item) }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Replace-all link when photos exist
                    if !vm.selectedPhotos.isEmpty {
                        PhotosPicker(
                            selection: $vm.selectedPhotoItems,
                            maxSelectionCount: vm.maxPhotos,
                            matching: .images
                        ) {
                            Text("Replace all photos")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .onChange(of: vm.selectedPhotoItems) { _, items in
                            Task { await vm.loadPhotos(from: items) }
                        }
                    }
                }
                // Crop sheet — driven by cropQueue regardless of which picker triggered it
                .fullScreenCover(
                    isPresented: Binding(
                        get: { !vm.cropQueue.isEmpty },
                        set: { presented in
                            if !presented && !vm.cropQueue.isEmpty {
                                vm.cancelCrops()
                            }
                        }
                    )
                ) {
                    if let img = vm.cropQueue.first {
                        PhotoCropSheet(
                            image: img,
                            photoNumber: vm.cropPhotoNumber,
                            totalPhotos: vm.cropQueueTotal,
                            onConfirm: { vm.confirmCrop($0) },
                            onCancel: { vm.cancelCrops() }
                        )
                        .id(vm.cropQueue.count)
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
