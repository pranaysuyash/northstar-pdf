import Foundation

/// Merges annotations from multiple partner packages into a single unified set.
///
/// First principle: real reviews involve 3+ reviewers. The merge must handle
/// multiple packages sequentially, each producing a cumulative merge result.
///
/// Architecture:
/// - `MultiPackageMergeResult` — result of merging multiple packages
/// - `MultiPackageMerger` — orchestrates sequential merging
///
/// Doctrine alignment:
/// - §3: Do things smartly — sequential merge, each package is independent
/// - §5: Evidence-based — per-package merge results preserved
/// - §8: Capability activation — multi-package merge is opt-in

// MARK: - Multi-Package Merge Result

/// Result of merging multiple partner packages.
public struct MultiPackageMergeResult: Sendable {
    /// Per-package merge results (in order of merging).
    public let packageResults: [(packageID: UUID, packageName: String, result: AnnotationMergeResult)]
    /// The final merged mark set after all packages are merged.
    public let finalMarks: [AnnotationMark]
    /// Total unique conflicts across all packages.
    public let totalConflicts: [AnnotationConflict]
    /// Total marks added from all packages.
    public let totalAdded: Int
    /// Total duplicates removed.
    public let totalDuplicates: Int
    
    /// Summary description.
    public var description: String {
        "\(packageResults.count) packages merged: \(totalAdded) added, \(totalConflicts.count) conflicts, \(totalDuplicates) duplicates"
    }
}

// MARK: - Multi-Package Merger

/// Orchestrates sequential merging of multiple partner packages.
public struct MultiPackageMerger {
    
    /// Merge multiple packages against the local annotation set.
    ///
    /// - Parameters:
    ///   - localMarks: The local annotation marks.
    ///   - packages: Array of (packageID, partner marks) to merge sequentially.
    /// - Returns: A multi-package merge result.
    public static func merge(
        localMarks: [AnnotationMark],
        packages: [(packageID: UUID, partnerMarks: [AnnotationMark])]
    ) -> MultiPackageMergeResult {
        var currentMarks = localMarks
        var packageResults: [(packageID: UUID, packageName: String, result: AnnotationMergeResult)] = []
        var allConflicts: [AnnotationConflict] = []
        var totalAdded = 0
        var totalDuplicates = 0
        
        for (packageID, partnerMarks) in packages {
            let result = AnnotationMerger.merge(local: currentMarks, partner: partnerMarks)
            
            packageResults.append((
                packageID: packageID,
                packageName: "", // Filled by caller if needed
                result: result
            ))
            
            allConflicts.append(contentsOf: result.conflicts)
            totalAdded += result.partnerOnly.count
            totalDuplicates += result.duplicates.count
            
            // Accumulate marks for next package
            currentMarks = result.mergedMarks
        }
        
        return MultiPackageMergeResult(
            packageResults: packageResults,
            finalMarks: currentMarks,
            totalConflicts: allConflicts,
            totalAdded: totalAdded,
            totalDuplicates: totalDuplicates
        )
    }
    
    /// Merge multiple packages and resolve all conflicts with a default strategy.
    ///
    /// - Parameters:
    ///   - localMarks: The local annotation marks.
    ///   - packages: Array of (packageID, partner marks).
    ///   - defaultResolution: How to resolve conflicts automatically.
    /// - Returns: The final merged mark set.
    public static func mergeWithDefaults(
        localMarks: [AnnotationMark],
        packages: [(packageID: UUID, partnerMarks: [AnnotationMark])],
        defaultResolution: ConflictResolution = .keepBoth
    ) -> [AnnotationMark] {
        let result = merge(localMarks: localMarks, packages: packages)
        
        // Apply default resolution to all conflicts
        var finalMarks = result.finalMarks
        for conflict in result.totalConflicts {
            let resolvedMark: AnnotationMark
            switch defaultResolution {
            case .keepLocal:
                resolvedMark = conflict.localMark
            case .keepPartner:
                resolvedMark = conflict.partnerMark
            case .keepBoth:
                resolvedMark = conflict.localMark
                finalMarks.append(conflict.partnerMark)
            case .merge:
                resolvedMark = conflict.resolvedMark
            }
            // Replace the conflicted mark with the resolved one
            if let idx = finalMarks.firstIndex(where: { $0.id == conflict.localMark.id }) {
                finalMarks[idx] = resolvedMark
            }
        }
        
        return finalMarks
    }
    
    /// Analyze the complexity of a multi-package merge without performing it.
    ///
    /// Returns estimated conflict count and merge complexity.
    public static func analyzeComplexity(
        localMarks: [AnnotationMark],
        packages: [(packageID: UUID, partnerMarks: [AnnotationMark])]
    ) -> MergeComplexity {
        var currentMarks = localMarks
        var estimatedConflicts = 0
        var estimatedAdded = 0
        
        for (_, partnerMarks) in packages {
            let result = AnnotationMerger.merge(local: currentMarks, partner: partnerMarks)
            estimatedConflicts += result.conflicts.count
            estimatedAdded += result.partnerOnly.count
            currentMarks = result.mergedMarks
        }
        
        let complexity: ComplexityLevel
        if estimatedConflicts == 0 {
            complexity = .trivial
        } else if estimatedConflicts <= 3 {
            complexity = .simple
        } else if estimatedConflicts <= 10 {
            complexity = .moderate
        } else {
            complexity = .complex
        }
        
        return MergeComplexity(
            estimatedConflicts: estimatedConflicts,
            estimatedAddedMarks: estimatedAdded,
            packageCount: packages.count,
            level: complexity
        )
    }
}

// MARK: - Merge Complexity

/// Complexity analysis of a multi-package merge.
public struct MergeComplexity: Sendable {
    public let estimatedConflicts: Int
    public let estimatedAddedMarks: Int
    public let packageCount: Int
    public let level: ComplexityLevel
    
    public var description: String {
        "\(level.displayName): ~\(estimatedConflicts) conflicts, ~\(estimatedAddedMarks) new marks from \(packageCount) packages"
    }
}

/// Complexity levels for merge operations.
public enum ComplexityLevel: String, Codable, Sendable, CaseIterable {
    case trivial
    case simple
    case moderate
    case complex
    
    public var displayName: String {
        switch self {
        case .trivial: return "Trivial"
        case .simple: return "Simple"
        case .moderate: return "Moderate"
        case .complex: return "Complex"
        }
    }
    
    public var symbolName: String {
        switch self {
        case .trivial: return "checkmark.circle"
        case .simple: return "hand.thumbsup"
        case .moderate: return "exclamationmark.triangle"
        case .complex: return "exclamationmark.octagon"
        }
    }
}
