import SwiftUI

struct BlendView: View {
    @EnvironmentObject var vm: BlendViewModel

    private func blendFriendTitle(_ f: Friendship) -> String {
        let n = f.friendDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? (f.friendUsername ?? f.friendId) : n
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Blend your tastes with friends")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("Select friends to find restaurants you'll all love")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Friend selection
                Section {
                    if vm.availableFriends.isEmpty {
                        Text("No friends yet. Add friends to blend tastes.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(vm.availableFriends) { friendship in
                        let friendId = friendship.friendId
                        let title = blendFriendTitle(friendship)
                        Button {
                            if vm.selectedFriendIds.contains(friendId) {
                                vm.selectedFriendIds.remove(friendId)
                            } else {
                                vm.selectedFriendIds.insert(friendId)
                            }
                        } label: {
                            HStack {
                                Image(systemName: vm.selectedFriendIds.contains(friendId)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                .foregroundStyle(vm.selectedFriendIds.contains(friendId) ? .orange : .secondary)

                                ProfileAvatarView(url: friendship.friendAvatarUrl, name: title, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title)
                                        .foregroundStyle(.primary)
                                    if let u = friendship.friendUsername {
                                        Text("@\(u)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Select Friends")
                }

                // Blend button
                Button {
                    Task { await vm.blend() }
                } label: {
                    Label("Blend", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .disabled(vm.isLoading || vm.selectedFriendIds.isEmpty)
                .overlay {
                    if vm.isLoading {
                        ProgressView()
                    }
                }

                // Results
                if !vm.recommendations.isEmpty {
                    Section {
                        ForEach(vm.recommendations.indices, id: \.self) { i in
                            let rec = vm.recommendations[i]
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("#\(i + 1)")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(i < 3 ? .orange : .secondary)

                                    VStack(alignment: .leading) {
                                        Text(rec.name)
                                            .font(.headline)
                                        if let cuisine = rec.cuisine {
                                            Text(cuisine)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()
                                }

                                HStack {
                                    Label("Score: \(rec.score)", systemImage: "fork.knife")
                                    Spacer()
                                    Label(String(format: "%.1f km away", rec.distance),
                                          systemImage: "location")
                                }
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    } header: {
                        Text("Recommendations")
                    }
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Spacer()
            }
            .padding()
        }
    }
}
