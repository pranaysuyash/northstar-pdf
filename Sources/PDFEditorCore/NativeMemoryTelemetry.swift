#if os(macOS)
import Darwin
#endif

/// A value-only observation of the current native process memory footprint.
///
/// These counters are measurements, not authoritative accounting of document
/// cost or allocator ownership. A caller must explicitly opt in at the sampling
/// call site, and should keep the returned value with its own benchmark record.
public struct NativeMemorySnapshot: Codable, Equatable, Sendable {
  /// Resident bytes reported by the process task information API.
  public let residentBytes: UInt64

  /// Virtual address-space bytes reported by the process task information API.
  public let virtualBytes: UInt64

  /// Physical footprint bytes reported by the macOS resource-usage API, when
  /// that secondary observation is available.
  public let physicalFootprintBytes: UInt64?

  public init(
    residentBytes: UInt64,
    virtualBytes: UInt64,
    physicalFootprintBytes: UInt64? = nil
  ) {
    self.residentBytes = residentBytes
    self.virtualBytes = virtualBytes
    self.physicalFootprintBytes = physicalFootprintBytes
  }
}

/// An opt-in, stateless bridge to native macOS process-memory counters.
///
/// This type does not retain samples, cache results, emit logs, or alter the
/// existing performance telemetry recorder. It exposes only numeric counters
/// for the current process and never receives document or user data.
public enum NativeMemoryTelemetry {
  /// Captures one best-effort observation when `enabled` is explicitly true.
  ///
  /// The primary task-information call must succeed for a snapshot to exist.
  /// The physical-footprint field is optional because the secondary resource
  /// usage call may be unavailable or fail independently.
  public static func snapshot(enabled: Bool = false) -> NativeMemorySnapshot? {
    guard enabled else { return nil }

#if os(macOS)
    var taskInfo = proc_taskinfo()
    let taskInfoSize = MemoryLayout<proc_taskinfo>.stride
    let taskInfoResult = withUnsafeMutablePointer(to: &taskInfo) { pointer in
      proc_pidinfo(
        getpid(),
        PROC_PIDTASKINFO,
        0,
        pointer,
        Int32(taskInfoSize)
      )
    }

    guard taskInfoResult == Int32(taskInfoSize) else { return nil }

    var resourceUsage = rusage_info_v4()
    let resourceUsageResult = withUnsafeMutablePointer(to: &resourceUsage) {
      pointer in
      pointer.withMemoryRebound(to: (rusage_info_t?).self, capacity: 1) { rusagePointer in
        proc_pid_rusage(getpid(), RUSAGE_INFO_V4, rusagePointer)
      }
    }

    return NativeMemorySnapshot(
      residentBytes: taskInfo.pti_resident_size,
      virtualBytes: taskInfo.pti_virtual_size,
      physicalFootprintBytes: resourceUsageResult == 0
        ? resourceUsage.ri_phys_footprint
        : nil
    )
#else
    return nil
#endif
  }
}
