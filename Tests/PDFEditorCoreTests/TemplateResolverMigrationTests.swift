import Foundation
import Testing

@testable import PDFEditorCore

struct TemplateResolverMigrationTests {
    private let provider = PDFProviderDescriptor(id: "resolver-test", version: "1", platform: "test")
    private let templateID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    private let nameID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!

    private func mapping(
        id: UUID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
        key: String = "person.fullName",
        status: PDFTemplateMappingStatus = .confirmed
    ) -> PDFTemplateMapping {
        PDFTemplateMapping(
            id: id,
            semanticKey: key,
            target: PDFTemplateMappingTarget(
                kind: .nativeField,
                pageIndex: 0,
                region: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 10, y: 10, width: 100, height: 20))),
            suggestedFieldType: .text,
            status: status)
    }

    private func template(revisionID: UUID, mappings: [PDFTemplateMapping]) -> PDFTemplateContract {
        let fingerprint = PDFTemplateFingerprint(
            layoutFingerprint: "layout-resolver",
            exactSourceDigests: [String(repeating: "a", count: 64)],
            pageSignatures: [PDFTemplatePageSignature(pageIndex: 0, widthPoints: 612, heightPoints: 792, rotationDegrees: 0, nativeFieldKinds: [.text], nativeFieldNameTokens: [], anchorTokens: [], regionSignatures: [])])
        return PDFTemplateContract(
            header: PDFTemplateHeader(templateDigest: "template-resolver", provider: provider),
            payload: PDFTemplatePayload(
                templateID: templateID,
                revisionID: revisionID,
                displayName: "Resolver fixture",
                lifecycle: .active,
                fingerprint: fingerprint,
                mappings: mappings))
    }

    private func profile(id: UUID, name: String, value: PDFProfileValue) -> PDFProfileContract {
        let payload = PDFProfilePayload(
            profileID: id,
            revisionID: id,
            displayName: name,
            values: [PDFProfileValueRecord(semanticKey: "person.fullName", value: value)])
        return PDFProfileContract(
            header: PDFProfileHeader(profileID: id, revisionID: id, provider: provider),
            payload: payload)
    }

    @Test func resolverSelectsCompleteProfileWithoutReturningValues() {
        let selectedID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        let result = PDFTemplateProfileResolver.resolve(
            template: template(revisionID: templateID, mappings: [mapping()]),
            profiles: [profile(id: selectedID, name: "Primary", value: .text("private value"))])
        #expect(result.state == .selected)
        #expect(result.selectedProfileID == selectedID)
        #expect(result.abstained == false)
        #expect(result.candidates.first?.reasons.contains { $0.contains("1 of 1") } == true)
        let encoded = String(data: try! JSONEncoder().encode(result), encoding: .utf8)!
        #expect(!encoded.contains("private value"))
    }

    @Test func resolverAbstainsOnCompleteTieAndMissingValue() {
        let first = profile(id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!, name: "One", value: .text("one"))
        let second = profile(id: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!, name: "Two", value: .text("two"))
        let tie = PDFTemplateProfileResolver.resolve(
            template: template(revisionID: templateID, mappings: [mapping()]), profiles: [first, second])
        #expect(tie.state == .ambiguous)
        #expect(tie.abstained)
        let missing = PDFTemplateProfileResolver.resolve(
            template: template(revisionID: templateID, mappings: [mapping(), mapping(id: nameID, key: "person.email")]), profiles: [first])
        #expect(missing.state == .noMatch)
        #expect(missing.abstained)
    }

    @Test func migrationRequiresReviewAndApprovedRemovalActuallyRemovesMapping() throws {
        let from = template(revisionID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, mappings: [mapping(), mapping(id: nameID, key: "person.email")])
        let changed = template(revisionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, mappings: [mapping()])
        var proposal = try PDFTemplateMigrationPlanner.make(from: from, to: changed, sourceDigest: String(repeating: "b", count: 64))
        #expect(proposal.state == .reviewRequired)
        #expect(!proposal.canMaterialize)
        for decision in proposal.decisions {
            proposal = proposal.reviewing(mappingID: decision.id, approved: true)
        }
        #expect(proposal.canMaterialize)
        let migrated = try proposal.materialize()
        #expect(migrated.payload.parentRevisionID == from.payload.revisionID)
        #expect(migrated.payload.mappings.map(\.semanticKey) == ["person.fullName"])
        #expect(migrated.payload.fingerprint.exactSourceDigests.contains(String(repeating: "b", count: 64)))
    }
}

