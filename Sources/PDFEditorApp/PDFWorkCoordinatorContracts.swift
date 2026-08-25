//
//  PDFWorkCoordinatorContracts.swift
//  PDFEditorApp
//
//  Value-only policy contracts for a future native work coordinator.
//

/// Monotonically increasing identity for a coordinator request.
///
/// A newer generation wins publication races. The generation carries no
/// document identity or document data.
struct PDFWorkRequestGeneration: Comparable, Equatable, Hashable, Sendable {
  let rawValue: UInt64

  static let initial = Self(rawValue: 0)

  init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  var next: Self {
    precondition(rawValue < UInt64.max, "PDF work request generation overflow")
    return Self(rawValue: rawValue + 1)
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

/// The bounded kinds of native work governed by the coordinator contract.
enum PDFWorkKind: String, Codable, Equatable, Hashable, Sendable {
  case open
  case export
}

/// Lifecycle of one coordinator request.
enum PDFWorkLifecycle: String, Codable, Equatable, Hashable, Sendable {
  case created
  case running
  case superseded
  case canceled
  case failed
  case completed

  var isTerminal: Bool {
    switch self {
    case .superseded, .canceled, .failed, .completed:
      true
    case .created, .running:
      false
    }
  }

  /// Returns whether the next lifecycle state is allowed by the contract.
  func canTransition(to next: Self) -> Bool {
    switch (self, next) {
    case (.created, .running),
         (.created, .superseded),
         (.created, .canceled),
         (.created, .failed),
         (.running, .superseded),
         (.running, .canceled),
         (.running, .failed),
         (.running, .completed):
      true
    default:
      false
    }
  }
}

/// Policy result produced immediately before a work result could be exposed.
enum PDFWorkPublicationDecision: String, Codable, Equatable, Hashable, Sendable {
  case publish
  case rejectStale
  case rejectCanceled
  case rejectFailed
  case rejectIncomplete

  var allowsPublication: Bool {
    self == .publish
  }
}
