import Testing
import Foundation
@testable import PDFEditorCore

@Suite("AnnotationComments")
struct AnnotationCommentTests {

  // MARK: - Comment Model

  @Test("Comment has correct fields")
  func commentFields() {
    let comment = AnnotationComment(author: "Alice", content: "Looks good!")
    #expect(comment.author == "Alice")
    #expect(comment.content == "Looks good!")
    #expect(comment.isEdited == false)
    #expect(comment.parentCommentID == nil)
    #expect(comment.reactions.isEmpty)
  }

  @Test("Comment edit updates content and timestamp")
  func commentEdit() {
    var comment = AnnotationComment(author: "Bob", content: "Original")
    comment.edit(newContent: "Edited")
    #expect(comment.content == "Edited")
    #expect(comment.isEdited == true)
    #expect(comment.editedAt != nil)
  }

  @Test("Comment reaction toggle works")
  func commentReaction() {
    var comment = AnnotationComment(author: "Carol", content: "Nice!")
    comment.toggleReaction("👍")
    #expect(comment.reactions["👍"] == 1)
    comment.toggleReaction("👍")
    #expect(comment.reactions["👍"] == nil)
  }

  // MARK: - Thread Model

  @Test("Thread starts empty")
  func threadStartsEmpty() {
    let thread = CommentThread(markID: UUID())
    #expect(thread.comments.isEmpty)
    #expect(thread.isResolved == false)
    #expect(thread.commentCount == 0)
  }

  @Test("Add comment to thread")
  func addComment() {
    var thread = CommentThread(markID: UUID())
    let comment = thread.addComment(author: "Alice", content: "First comment")
    #expect(thread.comments.count == 1)
    #expect(comment.author == "Alice")
    #expect(thread.commentCount == 1)
  }

  @Test("Reply to comment")
  func replyToComment() {
    var thread = CommentThread(markID: UUID())
    let root = thread.addComment(author: "Alice", content: "Question?")
    let reply = thread.addComment(author: "Bob", content: "Answer!", parentCommentID: root.id)
    #expect(thread.comments.count == 2)
    #expect(reply.parentCommentID == root.id)
    #expect(thread.rootComments.count == 1)
    #expect(thread.replies(to: root.id).count == 1)
  }

  @Test("Delete comment removes it and its replies")
  func deleteComment() {
    var thread = CommentThread(markID: UUID())
    let root = thread.addComment(author: "Alice", content: "Root")
    thread.addComment(author: "Bob", content: "Reply", parentCommentID: root.id)
    thread.deleteComment(id: root.id)
    #expect(thread.comments.isEmpty) // Reply also removed
  }

  @Test("Thread authors are unique and sorted")
  func threadAuthors() {
    var thread = CommentThread(markID: UUID())
    thread.addComment(author: "Carol", content: "C")
    thread.addComment(author: "Alice", content: "A")
    thread.addComment(author: "Bob", content: "B")
    #expect(thread.authors == ["Alice", "Bob", "Carol"])
  }

  @Test("Resolve/unresolve thread")
  func resolveThread() {
    var thread = CommentThread(markID: UUID())
    #expect(thread.isResolved == false)
    thread.toggleResolved()
    #expect(thread.isResolved == true)
    thread.toggleResolved()
    #expect(thread.isResolved == false)
  }

  @Test("Thread summary")
  func threadSummary() {
    var thread = CommentThread(markID: UUID())
    #expect(thread.summary == "No comments")
    thread.addComment(author: "Alice", content: "Hi")
    #expect(thread.summary.contains("1 comment"))
    thread.addComment(author: "Bob", content: "Hello")
    #expect(thread.summary.contains("2 comments"))
    #expect(thread.summary.contains("Alice"))
    #expect(thread.summary.contains("Bob"))
  }

  // MARK: - Comment Store

  @Test("Add comment creates thread")
  @MainActor
  func addCommentCreatesThread() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let markID = UUID()
    let comment = store.addComment(to: markID, author: "Alice", content: "Great highlight!")
    #expect(store.threads.count == 1)
    #expect(comment.author == "Alice")
    #expect(store.totalCommentCount == 1)
  }

  @Test("Multiple comments on same mark")
  @MainActor
  func multipleComments() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let markID = UUID()
    store.addComment(to: markID, author: "Alice", content: "First")
    store.addComment(to: markID, author: "Bob", content: "Second")
    let thread = store.thread(for: markID)
    #expect(thread.commentCount == 2)
  }

  @Test("Reply to existing comment")
  @MainActor
  func replyInStore() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let markID = UUID()
    let root = store.addComment(to: markID, author: "Alice", content: "Question?")
    store.addComment(to: markID, author: "Bob", content: "Answer!", parentCommentID: root.id)
    let thread = store.thread(for: markID)
    #expect(thread.rootComments.count == 1)
    #expect(thread.replies(to: root.id).count == 1)
  }

  @Test("Edit comment in store")
  @MainActor
  func editInStore() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let markID = UUID()
    let comment = store.addComment(to: markID, author: "Alice", content: "Original")
    store.editComment(commentID: comment.id, markID: markID, newContent: "Edited")
    let thread = store.thread(for: markID)
    #expect(thread.comments.first?.content == "Edited")
    #expect(thread.comments.first?.isEdited == true)
  }

  @Test("Delete comment in store")
  @MainActor
  func deleteInStore() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let markID = UUID()
    let comment = store.addComment(to: markID, author: "Alice", content: "Delete me")
    store.deleteComment(commentID: comment.id, markID: markID)
    #expect(store.threads[markID] == nil) // Thread removed when empty
    #expect(store.totalCommentCount == 0)
  }

  @Test("Reaction toggle in store")
  @MainActor
  func reactionInStore() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let markID = UUID()
    let comment = store.addComment(to: markID, author: "Alice", content: "Nice!")
    store.toggleReaction(commentID: comment.id, markID: markID, emoji: "👍")
    let thread = store.thread(for: markID)
    #expect(thread.comments.first?.reactions["👍"] == 1)
  }

  @Test("Resolve/unresolve in store")
  @MainActor
  func resolveInStore() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let markID = UUID()
    store.addComment(to: markID, author: "Alice", content: "Discuss")
    store.toggleResolved(markID: markID)
    #expect(store.thread(for: markID).isResolved == true)
    #expect(store.unresolvedThreads.isEmpty)
    #expect(store.resolvedThreads.count == 1)
  }

  @Test("Query: threads by activity")
  @MainActor
  func threadsByActivity() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let m1 = UUID()
    let m2 = UUID()
    store.addComment(to: m1, author: "A", content: "1")
    store.addComment(to: m1, author: "B", content: "2")
    store.addComment(to: m1, author: "C", content: "3")
    store.addComment(to: m2, author: "A", content: "1")
    let active = store.threadsByActivity(limit: 1)
    #expect(active.first?.markID == m1)
    #expect(active.first?.commentCount == 3)
  }

  @Test("Query: all authors")
  @MainActor
  func allAuthors() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    store.addComment(to: UUID(), author: "Bob", content: "B")
    store.addComment(to: UUID(), author: "Alice", content: "A")
    #expect(store.allAuthors == ["Alice", "Bob"])
  }

  @Test("Statistics aggregate correctly")
  @MainActor
  func statistics() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    store.addComment(to: UUID(), author: "A", content: "1")
    store.addComment(to: UUID(), author: "A", content: "2")
    store.addComment(to: UUID(), author: "B", content: "3")
    let markID = UUID()
    store.addComment(to: markID, author: "C", content: "4")
    store.toggleResolved(markID: markID)
    let stats = store.statistics
    #expect(stats.totalThreads == 4)
    #expect(stats.totalComments == 4)
    #expect(stats.resolvedCount == 1)
    #expect(stats.unresolvedCount == 3)
    #expect(stats.authorCount == 3)
  }

  @Test("Delete thread removes it entirely")
  @MainActor
  func deleteThread() {
    let store = CommentStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let markID = UUID()
    store.addComment(to: markID, author: "A", content: "1")
    store.addComment(to: markID, author: "B", content: "2")
    store.deleteThread(markID: markID)
    #expect(store.threads.isEmpty)
    #expect(store.totalCommentCount == 0)
  }
}
