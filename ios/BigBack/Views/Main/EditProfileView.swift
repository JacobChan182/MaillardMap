import PhotosUI
import SwiftUI
import UIKit

struct EditProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private var api: APIClient { auth.api }

    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var profilePrivate = false
    /// Local avatar URL after successful upload, or existing profile URL.
    @State private var avatarPublicUrl: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    ProfileAvatarView(
                        url: avatarPublicUrl,
                        name: displayName.isEmpty ? (auth.currentUser?.username ?? "?") : displayName,
                        size: 88
                    )
                    Spacer()
                }
                .listRowBackground(Color.clear)

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Label("Choose profile photo", systemImage: "photo")
                }

                if avatarPublicUrl != nil {
                    Button("Remove photo", role: .destructive) {
                        avatarPublicUrl = nil
                    }
                }
            }

            Section("Display name") {
                TextField("How you appear to friends", text: $displayName)
                    .textInputAutocapitalization(.words)
                Text("Your username (@\(auth.currentUser?.username ?? "")) stays the same for login.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Bio") {
                TextField("Tell friends about you", text: $bio, axis: .vertical)
                    .lineLimit(3 ... 8)
                Text("\(bio.count)/200")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Private profile", isOn: $profilePrivate)
            } footer: {
                Text("Only accepted friends can see your posts. Your name and photo still appear when people search for you.")
                    .font(.caption)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(isBusy || auth.currentUser == nil)
            }
        }
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await syncFromAuth() }
        .onChange(of: pickerItem) { _, item in
            Task { await uploadPickedPhoto(item) }
        }
    }

    private func syncFromAuth() async {
        guard let id = auth.currentUser?.id else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let u = try await api.getUser(id: id)
            displayName = u.displayName ?? ""
            bio = u.bio ?? ""
            avatarPublicUrl = u.avatarUrl
            profilePrivate = u.profilePrivate == true
        } catch {
            displayName = auth.currentUser?.displayName ?? ""
            bio = auth.currentUser?.bio ?? ""
            avatarPublicUrl = auth.currentUser?.avatarUrl
            profilePrivate = auth.currentUser?.profilePrivate == true
        }
    }

    private func uploadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            guard let raw = try await item.loadTransferable(type: Data.self) else { return }
            let contentType = "image/jpeg"
            let uploadData: Data
            if let img = UIImage(data: raw) {
                let jpeg = await Task.detached(priority: .userInitiated) {
                    SocialImageCompression.jpegDataForProfileAvatar(img)
                }.value
                uploadData = jpeg ?? raw
            } else {
                uploadData = raw
            }
            let slot = try await api.presignAvatarUpload(contentType: contentType)
            guard let putURL = URL(string: slot.uploadUrl) else { return }
            try await api.uploadToPresignedURL(putURL, data: uploadData, contentType: contentType)
            avatarPublicUrl = slot.publicUrl
        } catch {
            errorMessage = error.localizedDescription
        }
        pickerItem = nil
    }

    private func save() async {
        guard let _ = auth.currentUser?.id else { return }
        guard bio.count <= 200 else {
            errorMessage = "Bio must be 200 characters or less."
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let u = try await api.updateMyProfile(
                displayName: displayName,
                avatarUrl: avatarPublicUrl,
                bio: bio,
                profilePrivate: profilePrivate
            )
            auth.replaceCurrentUser(u)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthViewModel())
    }
}
