import SwiftUI

/// Parses comment `createdAt` ISO8601 strings from the API.
private func commentCreatedDate(from iso: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: iso) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: iso)
}

private func relativeCommentAge(from commentDate: Date, now: Date = Date()) -> String {
    let cal = Calendar.current
    let startComment = cal.startOfDay(for: commentDate)
    let startNow = cal.startOfDay(for: now)
    guard let days = cal.dateComponents([.day], from: startComment, to: startNow).day else { return "" }
    if days <= 0 { return "Today" }
    if days < 14 { return "\(days) \(days == 1 ? "day" : "days") ago" }
    if days < 30 { let weeks = days / 7; return "\(weeks) \(weeks == 1 ? "week" : "weeks") ago" }
    let months = max(1, days / 30)
    return "\(months) \(months == 1 ? "month" : "months") ago"
}

struct CommentsView: View {
    let postId: String
    @StateObject private var vm: CommentsViewModel
    @FocusState private var fieldFocused: Bool

    init(postId: String) {
        self.postId = postId
        _vm = StateObject(wrappedValue: CommentsViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.isLoading {
                ProgressView()
                    .padding()
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if vm.comments.isEmpty && !vm.isLoading {
                        Text("No comments yet")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    ForEach(vm.comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(comment.username)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                if let date = commentCreatedDate(from: comment.createdAt) {
                                    Text(relativeCommentAge(from: date))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Text(comment.text)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }

            Divider()
            HStack(spacing: 8) {
                TextField("Add a comment...", text: $vm.newCommentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await vm.submitComment(postId: postId) }
                    }
                Button("Send") {
                    Task { await vm.submitComment(postId: postId) }
                }
                .buttonStyle(.bordered)
                .disabled(vm.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .task { await vm.loadComments(postId: postId) }
    }
}
