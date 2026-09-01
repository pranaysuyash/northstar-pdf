import Foundation

/// Local-only command presentation preferences.
///
/// The store intentionally records semantic command IDs and a command-distance
/// age only. It does not retain document names, content, locations, timestamps,
/// or execution data.
/// Hosts can inject a suite for tests or a future per-user settings boundary.
@MainActor
public final class AdaptiveCommandHistory {
  public static let shared = AdaptiveCommandHistory()

  public let maximumRecentCommands: Int
  /// Maximum number of later command interactions before a recent hint expires.
  /// This is an interaction-distance policy, not a wall-clock profile.
  public let maximumRecentAge: Int

  private let defaults: UserDefaults
  private let recentKey: String
  private let recentEntriesKey: String
  private let pinnedKey: String
  private let enabledKey: String

  public init(
    defaults: UserDefaults = .standard,
    namespace: String = "pdfEditor.adaptiveCommands",
    maximumRecentCommands: Int = 8,
    maximumRecentAge: Int = 12
  ) {
    self.defaults = defaults
    self.recentKey = "\(namespace).recent"
    self.recentEntriesKey = "\(namespace).recentEntries"
    self.pinnedKey = "\(namespace).pinned"
    self.enabledKey = "\(namespace).enabled"
    self.maximumRecentCommands = max(1, maximumRecentCommands)
    self.maximumRecentAge = max(1, maximumRecentAge)
  }

  public var isPersonalizationEnabled: Bool {
    defaults.object(forKey: enabledKey) as? Bool ?? true
  }

  public func setPersonalizationEnabled(_ enabled: Bool) {
    defaults.set(enabled, forKey: enabledKey)
  }

  public var recentCommandIDs: [String] {
    recentEntries().map(\.id)
  }

  public var pinnedCommandIDs: [String] {
    defaults.stringArray(forKey: pinnedKey) ?? []
  }

  /// Records a command invocation without recording document or user data.
  public func record(_ commandID: AdaptiveCommandID) {
    guard isPersonalizationEnabled else { return }
    var entries = recentEntries().map { entry in
      RecentEntry(id: entry.id, age: entry.age + 1)
    }
    entries.removeAll { $0.id == commandID.rawValue }
    entries.insert(RecentEntry(id: commandID.rawValue, age: 0), at: 0)
    entries = Array(
      entries
        .filter { $0.age < maximumRecentAge }
        .prefix(maximumRecentCommands)
    )
    saveRecentEntries(entries)
  }

  public func setPinned(_ commandID: AdaptiveCommandID, isPinned: Bool) {
    var pinned = pinnedCommandIDs.filter { $0 != commandID.rawValue }
    if isPinned {
      pinned.append(commandID.rawValue)
    }
    defaults.set(pinned, forKey: pinnedKey)
  }

  public func clear() {
    defaults.removeObject(forKey: recentKey)
    defaults.removeObject(forKey: recentEntriesKey)
    defaults.removeObject(forKey: pinnedKey)
  }

  private struct RecentEntry: Codable {
    let id: String
    let age: Int
  }

  private func recentEntries() -> [RecentEntry] {
    if let data = defaults.data(forKey: recentEntriesKey),
      let decoded = try? JSONDecoder().decode([RecentEntry].self, from: data)
    {
      return decoded.filter { !$0.id.isEmpty && $0.age >= 0 }
    }

    // Migrate the first implementation's ID-only list without making the old
    // preference surface fail closed. Legacy entries start at age zero and
    // naturally expire as the user records new commands.
    return (defaults.stringArray(forKey: recentKey) ?? []).map {
      RecentEntry(id: $0, age: 0)
    }
  }

  private func saveRecentEntries(_ entries: [RecentEntry]) {
    let data = try? JSONEncoder().encode(entries)
    defaults.set(data, forKey: recentEntriesKey)
    defaults.removeObject(forKey: recentKey)
  }
}
