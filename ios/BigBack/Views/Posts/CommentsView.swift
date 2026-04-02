import SwiftUI

// MARK: - @mentions in comment body (Instagram-style)

private struct MentionTextPart {
    let str: String
    let isMention: Bool
}

private func splitMentionParts(_ s: String) -> [MentionTextPart] {
    let re = try! NSRegularExpression(pattern: #"@[a-zA-Z0-9_]{3,32}"#, options: [])
    let ns = s as NSString
    let full = NSRange(location: 0, length: ns.length)
    var out: [MentionTextPart] = []
    var last = 0
    for m in re.matches(in: s, options: [], range: full) {
        if m.range.location > last {
            out.append(MentionTextPart(str: ns.substring(with: NSRange(location: last, length: m.range.location - last)), isMention: false))
        }
        out.append(MentionTextPart(str: ns.substring(with: m.range), isMention: true))
        last = m.range.location + m.range.length
    }
    if last < ns.length {
        out.append(MentionTextPart(str: ns.substring(from: last), isMention: false))
    }
    return out
}

private struct MentionStyledText: View {
    let text: String
    var font: Font = .footnote

    var body: some View {
        let parts = splitMentionParts(text)
        parts.reduce(Text("")) { acc, p in
            let segment: String = {
                if p.isMention, p.str.hasPrefix("@"), p.str.count > 1 {
                    return String(p.str.dropFirst())
                }
                return p.str
            }()
            return acc + Text(segment).foregroundStyle(p.isMention ? Color.orange : Color.primary)
        }
        .font(font)
    }
}

// MARK: - Relative time

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

// MARK: - Thread row

private struct CommentThreadBlock: View {
    let comment: Comment
    let all: [Comment]
    let depth: Int
    let onReply: (Comment) -> Void

    /// Public-facing label only (never the login username).
    private func commentAuthorLabel(_ c: Comment) -> String {
        let n = c.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? "User" : n
    }

    private var children: [Comment] {
        all.filter { $0.parentId == comment.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            commentRow
            ForEach(children) { child in
                CommentThreadBlock(comment: child, all: all, depth: depth + 1, onReply: onReply)
                    .padding(.leading, 20)
            }
        }
    }

    private var commentRow: some View {
        let author = commentAuthorLabel(comment)
        return HStack(alignment: .top, spacing: 8) {
            ProfileAvatarLink(
                userId: comment.userId,
                url: comment.avatarUrl,
                name: author,
                size: 28
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(author)
                        .font(.caption)
                        .fontWeight(.semibold)
                    if let date = commentCreatedDate(from: comment.createdAt) {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(relativeCommentAge(from: date))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 8)
                    Button("Reply") {
                        onReply(comment)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                }
                MentionStyledText(text: comment.text, font: .footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Mention picker (@)

private struct MentionPickerSheet: View {
    @Binding var targetText: String
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [User] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                }
                ForEach(results) { user in
                    HStack(alignment: .center, spacing: 12) {
                        ProfileAvatarLink(
                            userId: user.id,
                            url: user.avatarUrl,
                            name: userListTitle(user),
                            size: 36
                        )
                        Button {
                            targetText += "@\(user.username) "
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(userListTitle(user))
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Mention someone")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search by username")
            .onChange(of: query) { _, newVal in
                Task { await search(newVal) }
            }
        }
    }

    private func search(_ q: String) async {
        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 1 else {
            results = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            results = try await APIClient.live().searchUsers(query: t)
        } catch {
            results = []
        }
    }

    private func userListTitle(_ u: User) -> String {
        let n = u.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? u.username : n
    }
}

// MARK: - Comments screen

struct CommentsView: View {
    let postId: String
    @StateObject private var vm: CommentsViewModel
    @FocusState private var fieldFocused: Bool
    @State private var replyingTo: Comment?
    @State private var showMentionPicker = false

    init(postId: String) {
        self.postId = postId
        _vm = StateObject(wrappedValue: CommentsViewModel())
    }

    private var topLevelComments: [Comment] {
        vm.comments
            .filter { $0.parentId == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.isLoading {
                ProgressView()
                    .padding()
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if vm.comments.isEmpty && !vm.isLoading {
                        Text("No comments yet")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    ForEach(topLevelComments) { comment in
                        CommentThreadBlock(comment: comment, all: vm.comments, depth: 0) { target in
                            startReply(to: target)
                        }
                    }
                }
                .padding(.vertical)
            }

            if let err = vm.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()

            if let r = replyingTo {
                HStack {
                    Text("Replying to \(replyAuthorLabel(r))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            HStack(spacing: 8) {
                Button {
                    showMentionPicker = true
                } label: {
                    Image(systemName: "at")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)

                TextField(replyingTo == nil ? "Add a comment..." : "Reply...", text: $vm.newCommentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await send() }
                    }
                Button("Send") {
                    Task { await send() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(vm.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSubmitting)
            }
            .padding()
        }
        .sheet(isPresented: $showMentionPicker) {
            MentionPickerSheet(targetText: $vm.newCommentText)
        }
        .task { await vm.loadComments(postId: postId) }
    }

    private func replyAuthorLabel(_ c: Comment) -> String {
        let n = c.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? "User" : n
    }

    private func startReply(to comment: Comment) {
        replyingTo = comment
        fieldFocused = true
    }

    private func send() async {
        let parentId = replyingTo?.id
        let ok = await vm.submitComment(postId: postId, parentCommentId: parentId)
        if ok { replyingTo = nil }
    }
}
