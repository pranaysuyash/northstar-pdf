import Foundation
import PDFEditorRecovery

@main
struct PDFRecoveryInterruptionHarness {
  static func main() async {
    let succeeded = await MainActor.run {
      if ProcessInfo.processInfo.environment[RecoveryInterruptionTestSupport.observerEnvironment] == "1" {
        return RecoveryInterruptionTestSupport.runObserver()
      }
      return RecoveryInterruptionTestSupport.runChild()
    }
    if !succeeded {
      FileHandle.standardError.write(Data("recovery interruption harness failed\n".utf8))
    }
  }
}
