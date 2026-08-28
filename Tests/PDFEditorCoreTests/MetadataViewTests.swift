import Foundation
import Testing
@testable import PDFEditorCore

@Suite("DocumentMetadata")
struct MetadataViewTests {
  @Test("DocumentMetadata holds all fields")
  func fieldsExist() {
    let meta = DocumentMetadata(
      fileName: "test.pdf",
      fileSize: 1024,
      pageCount: 5,
      title: "Test Document",
      author: "Author Name",
      subject: "Subject",
      creator: "Creator",
      producer: "Producer",
      creationDate: Date(timeIntervalSince1970: 1000),
      modificationDate: Date(timeIntervalSince1970: 2000),
      isEncrypted: false,
      permissions: DocumentMetadata.Permissions(
        canPrint: true,
        canCopy: true,
        canModify: false,
        canAddAnnotations: true
      )
    )
    #expect(meta.fileName == "test.pdf")
    #expect(meta.fileSize == 1024)
    #expect(meta.pageCount == 5)
    #expect(meta.title == "Test Document")
    #expect(meta.author == "Author Name")
    #expect(meta.isEncrypted == false)
    #expect(meta.permissions?.canModify == false)
  }

  @Test("DocumentMetadata defaults to unknown for missing fields")
  func defaults() {
    let meta = DocumentMetadata(fileName: "empty.pdf", fileSize: 0, pageCount: 0)
    #expect(meta.title == "Unknown")
    #expect(meta.author == "Unknown")
    #expect(meta.isEncrypted == false)
    #expect(meta.permissions == nil)
  }

  @Test("File size formatting")
  func fileSizeFormat() {
    let meta = DocumentMetadata(fileName: "test.pdf", fileSize: 1_536_000, pageCount: 10)
    #expect(meta.formattedFileSize.contains("MB") || meta.formattedFileSize.contains("KB"))
  }
}
