import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// Tests for rotated replay fixture with crop-box offsets.
@Suite("Rotated Replay Fixture")
struct RotatedReplayFixtureTests {
    
    @Test("Standard fixtures are well-formed")
    func standardFixturesWellFormed() {
        let fixtures = RotatedReplayVerifier.standardFixtures()
        #expect(fixtures.count == 3)
        
        for fixture in fixtures {
            #expect(fixture.rotation == 0 || fixture.rotation == 90 ||
                    fixture.rotation == 180 || fixture.rotation == 270)
            #expect(fixture.operations.count > 0)
            #expect(fixture.expected.outsideRegionPreserved)
        }
    }
    
    @Test("Fixture rotation values are valid")
    func rotationValues() {
        let fixtures = RotatedReplayVerifier.standardFixtures()
        let rotations = fixtures.map(\.rotation)
        #expect(rotations.contains(90))
        #expect(rotations.contains(180))
        #expect(rotations.contains(270))
    }
    
    @Test("Fixture crop-box offsets are non-zero for offset fixtures")
    func cropBoxOffsets() {
        let fixtures = RotatedReplayVerifier.standardFixtures()
        let offsetFixtures = fixtures.filter { $0.cropBoxOffset.x > 0 || $0.cropBoxOffset.y > 0 }
        #expect(offsetFixtures.count >= 2) // At least 2 fixtures have non-zero offsets
    }
    
    @Test("Verification result is Codable")
    func verificationCodable() {
        let result = ReplayVerificationResult(passed: true, issues: [])
        let encoder = JSONEncoder()
        let data = try! encoder.encode(result)
        let decoded = try! JSONDecoder().decode(ReplayVerificationResult.self, from: data)
        #expect(decoded.passed)
        #expect(decoded.issues.isEmpty)
    }
}
