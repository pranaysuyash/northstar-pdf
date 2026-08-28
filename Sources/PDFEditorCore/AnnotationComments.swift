import Foundation

/// Threaded comments on annotation marks — the discussion layer for COLLABORATE.
///
/// First principle: comments are sidecar data, never embedded in the PDF.
/// They live alongside annotation marks in the JSON sidecar, survive PDF
/// version changes, and are portable across tools.
///
/// Each annotation mark can have zero or one comment thread.
/// A thread contains ordered comments with author attribution and timestamps.
///
/// Doctrine alignment:
/// - §3: Sidecar = non-destructive, no source modification
/// - §5: Every comment has author, timestamp, and full content
/// - §8: Comments are opt-in — no threads created until first comment
/// - §12: Privacy stays value-free — comments are user-authored content

// MARK: - Comment

/// A single comment on an annotation mark.
public struct AnnotationComment: Identifiable, Codable, Sendable {
  public let id: UUID
  /// Who wrote this comment.
  public let author: String
  /// The comment text.
  public var content: String
  /// When this comment was created.
  public let createdAt: Date
  /// When this comment was last edited (nil if never edited).
  public var editedAt: Date?
  /// Whether this comment has been edited.
  public var isEdited: Bool { editedAt != nil }
  /// Optional parent comment ID (for replies within a thread).
  public let parentCommentID: UUID?
  /// Reaction counts (emoji → count).
  public var reactions: [String: Int]

  public init(
    author: String,
    content: String,
    parentCommentID: UUID? = nil
  ) {
    self.id = UUID()
    self.author = author
    self.content = content
    self.createdAt = Date()
    self.editedAt = nil
    self.parentCommentID = parentCommentID
    self.reactions = [:]
  }

  /// Edit the comment content.
  public mutating func edit(newContent: String) {
    content = newContent
    editedAt = Date()
  }

  /// Add or remove a reaction.
  public mutating func toggleReaction(_ emoji: String) {
    let current = reactions[emoji] ?? 0
    if current > 0 {
      reactions[emoji] = current - 1
      if reactions[emoji] == 0 {
        reactions.removeValue(forKey: emoji)
      }
    } else {
      reactions[emoji] = 1
    }
  }
}

// MARK: - Comment Thread

/// A thread of comments attached to a specific annotation mark.
public struct CommentThread: Identifiable, Codable, Sendable {
  public let id: UUID
  /// The annotation mark this thread is attached to.
  public let markID: UUID
  /// All comments in this thread, ordered by creation date.
  public var comments: [AnnotationComment]
  /// Whether this thread is resolved (closed).
  public var isResolved: Bool
  /// When the thread was created.
  public let createdAt: Date
  /// When the thread was last updated.
  public var updatedAt: Date

  public init(markID: UUID) {
    self.id = UUID()
    self.markID = markID
    self.comments = []
    self.isResolved = false
    self.createdAt = Date()
    self.updatedAt = Date()
  }

  /// Add a comment to the thread.
  @discardableResult
  public mutating func addComment(author: String, content: String, parentCommentID: UUID? = nil) -> AnnotationComment {
    let comment = AnnotationComment(
      author: author,
      content: content,
      parentCommentID: parentCommentID
    )
    comments.append(comment)
    updatedAt = Date()
    return comment
  }

  /// Edit a comment.
  public mutating func editComment(id: UUID, newContent: String) {
    guard let index = comments.firstIndex(where: { $0.id == id }) else { return }
    comments[index].edit(newContent: newContent)
    updatedAt = Date()
  }

  /// Delete a comment.
  public mutating func deleteComment(id: UUID) {
    comments.removeAll { $0.id == id || $0.parentCommentID == id }
    updatedAt = Date()
  }

  /// Toggle a reaction on a comment.
  public mutating func toggleReaction(commentID: UUID, emoji: String) {
    guard let index = comments.firstIndex(where: { $0.id == commentID }) else { return }
    comments[index].toggleReaction(emoji)
    updatedAt = Date()
  }

  /// Resolve/unresolve the thread.
  public mutating func toggleResolved() {
    isResolved.toggle()
    updatedAt = Date()
  }

  /// Number of comments.
  public var commentCount: Int { comments.count }

  /// Top-level comments (not replies).
  public var rootComments: [AnnotationComment] {
    comments.filter { $0.parentCommentID == nil }
  }

  /// Replies to a specific comment.
  public func replies(to commentID: UUID) -> [AnnotationComment] {
    comments.filter { $0.parentCommentID == commentID }
  }

  /// All unique authors in this thread.
  public var authors: [String] {
    Array(Set(comments.map(\.author))).sorted()
  }

  /// Human-readable summary.
  public var summary: String {
    if comments.isEmpty { return "No comments" }
    let count = comments.count
    let authorList = authors.joined(separator: ", ")
    let suffix = count == 1 ? "" : "s"
    return "\(count) comment\(suffix) by \(authorList)"
  }
}

// MARK: - Comment Store

/// Manages comment threads across all marks in a document.
@MainActor
public final class CommentStore: ObservableObject {
  /// All comment threads, keyed by mark ID.
  @Published public var threads: [UUID: CommentThread] = [:]

  /// The document ID these comments belong to.
  public private(set) var documentID: String = ""

  private let storageKey = "com.pdfeditor.annotation.comments"

  public init() {}

  // MARK: - Document Binding

  /// Bind to a document ID.
  public func bind(toDocumentID documentID: String) {
    self.documentID = documentID
    load()
  }

  // MARK: - Thread Management

  /// Get or create a thread for a mark.
  public func thread(for markID: UUID) -> CommentThread {
    threads[markID] ?? CommentThread(markID: markID)
  }

  /// Add a comment to a mark's thread.
  @discardableResult
  public func addComment(
    to markID: UUID,
    author: String,
    content: String,
    parentCommentID: UUID? = nil
  ) -> AnnotationComment {
    var thread = threads[markID] ?? CommentThread(markID: markID)
    let comment = thread.addComment(
      author: author,
      content: content,
      parentCommentID: parentCommentID
    )
    threads[markID] = thread
    save()
    return comment
  }

  /// Edit a comment.
  public func editComment(commentID: UUID, markID: UUID, newContent: String) {
    guard var thread = threads[markID] else { return }
    thread.editComment(id: commentID, newContent: newContent)
    threads[markID] = thread
    save()
  }

  /// Delete a comment.
  public func deleteComment(commentID: UUID, markID: UUID) {
    guard var thread = threads[markID] else { return }
    thread.deleteComment(id: commentID)
    if thread.comments.isEmpty {
      threads.removeValue(forKey: markID)
    } else {
      threads[markID] = thread
    }
    save()
  }

  /// Toggle a reaction on a comment.
  public func toggleReaction(commentID: UUID, markID: UUID, emoji: String) {
    guard var thread = threads[markID] else { return }
    thread.toggleReaction(commentID: commentID, emoji: emoji)
    threads[markID] = thread
    save()
  }

  /// Resolve/unresolve a thread.
  public func toggleResolved(markID: UUID) {
    guard var thread = threads[markID] else { return }
    thread.toggleResolved()
    threads[markID] = thread
    save()
  }

  /// Delete an entire thread.
  public func deleteThread(markID: UUID) {
    threads.removeValue(forKey: markID)
    save()
  }

  // MARK: - Query

  /// Marks that have comment threads.
  public var markIDsWithComments: [UUID] {
    Array(threads.keys).sorted()
  }

  /// Total comment count across all threads.
  public var totalCommentCount: Int {
    threads.values.reduce(0) { $0 + $1.commentCount }
  }

  /// Unresolved threads.
  public var unresolvedThreads: [CommentThread] {
    threads.values.filter { !$0.isResolved }.sorted { $0.updatedAt > $1.updatedAt }
  }

  /// Resolved threads.
  public var resolvedThreads: [CommentThread] {
    threads.values.filter { $0.isResolved }.sorted { $0.updatedAt > $1.updatedAt }
  }

  /// Threads with the most comments.
  public func threadsByActivity(limit: Int = 10) -> [CommentThread] {
    threads.values.sorted { $0.commentCount > $1.commentCount }.prefix(limit).map { $0 }
  }

  /// All unique authors across all threads.
  public var allAuthors: [String] {
    Array(Set(threads.values.flatMap(\.authors))).sorted()
  }

  /// Comment statistics for the document.
  public var statistics: CommentStatistics {
    let all = Array(threads.values)
    return CommentStatistics(
      totalThreads: all.count,
      totalComments: totalCommentCount,
      resolvedCount: all.filter(\.isResolved).count,
      unresolvedCount: all.filter { !$0.isResolved }.count,
      authorCount: allAuthors.count,
      mostActiveThread: threadsByActivity(limit: 1).first
    )
  }

  // MARK: - Persistence

  private func save() {
    guard let data = try? JSONEncoder().encode(threads) else { return }
    UserDefaults.standard.set(data, forKey: storageKey + ".\(documentID)")
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey + ".\(documentID)"),
          let loaded = try? JSONDecoder().decode([UUID: CommentThread].self, from: data)
    else { return }
    threads = loaded
  }

  /// Clear all comments (for testing).
  public func clearAll() {
    threads = [:]
    UserDefaults.standard.removeObject(forKey: storageKey + ".\(documentID)")
  }
}

// MARK: - Comment Statistics

/// Aggregated comment statistics for a document.
public struct CommentStatistics: Sendable {
  public let totalThreads: Int
  public let totalComments: Int
  public let resolvedCount: Int
  public let unresolvedCount: Int
  public let authorCount: Int
  public let mostActiveThread: CommentThread?

  public var resolutionRate: Double {
    guard totalThreads > 0 else { return 0 }
    return Double(resolvedCount) / Double(totalThreads)
  }

  public var description: String {
    "\(totalComments) comments across \(totalThreads) threads (\(resolvedCount) resolved)"
  }
}
