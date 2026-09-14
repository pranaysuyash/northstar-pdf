import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

/// Tests for the cross-provider AcroForm parity experiment.
@Suite("AcroForm Parity Experiment")
struct AcroFormParityExperimentTests {

    /// Discover form-bearing PDFs from the governed corpus.
    ///
    /// Includes PDFs from multiple producers to stress-test the round-trip:
    /// - public-sample-form (baseline)
    /// - pdfkit-widgets (PDFKit native widgets)
    /// - public-acroform (PDFKit AcroForm)
    /// - native-incremental (6 producer re-encodes: synthetic, tagged, compressed)
    /// - browser-corpus hybrid (text + raster form)
    /// - rotation-corpus (rotated widgets)
    /// qpdf is a local brew dependency on the PATH; the experiment's
    /// independent-verifier channel requires it (read-only structural reads).
    private static func qpdfAvailable() -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["qpdf"]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        do { try proc.run(); proc.waitUntilExit() } catch { return false }
        return proc.terminationStatus == 0
    }

    private static func corpusFixtures() -> [String] {
        let fm = FileManager.default
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        
        // Known form-bearing PDFs (verified via PDFKit inspection)
        // Corpus targets 15+ fixtures across producers, field types, and vocabularies.
        let knownForms = [
            // Baseline forms
            "benchmark/results/public-sample-form.pdf",
            "benchmark/results/2026-08-23-pdfkit-widgets/noop.pdf",
            "benchmark/results/2026-08-23-public-acroform/noop.pdf",
            // Producer re-encodes of the same base form
            "benchmark/results/2026-08-25-native-incremental/corpus/compressed-acroform.pdf",
            "benchmark/results/2026-08-25-native-incremental/corpus/tagged-acroform.pdf",
            "benchmark/results/2026-08-25-native-incremental/corpus/tagged-no-acroform.pdf",
            "benchmark/results/2026-08-25-native-incremental/corpus/synthetic-producer-0.pdf",
            // Browser corpus: hybrid text+raster form
            "benchmark/results/browser-corpus/hybrid-text-raster-form.pdf",
            // Rotation corpus: rotated widgets
            "benchmark/results/rotation-corpus/rotated-widget-90.pdf",
            // Additional producers: PDFKit mutated widgets, PDFBox re-encodes
            "benchmark/results/2026-08-23-pdfkit-widgets/mutated.pdf",
            "benchmark/results/2026-08-23-public-acroform/mutated.pdf",
            "benchmark/results/2026-08-25-pdfbox-public-acroform/noop.pdf",
            // Generated radio fixtures: diverse vocabularies and tree structures
            // (exercise radio round-trip beyond the base applicant.contact group)
            "benchmark/datasets/radio-fixtures/yes_no.pdf",
            "benchmark/datasets/radio-fixtures/on_off.pdf",
            "benchmark/datasets/radio-fixtures/email_phone.pdf",
            "benchmark/datasets/radio-fixtures/hierarchical.pdf",
            "benchmark/datasets/radio-fixtures/multi_group.pdf",
            "benchmark/datasets/radio-fixtures/single_option.pdf",
            "benchmark/datasets/radio-fixtures/numeric_vocabulary.pdf",
            "benchmark/datasets/radio-fixtures/off_adjacent.pdf",
            // Generated checkbox fixtures (pikepdf producer): diverse boolean
            // export vocabularies, checked/unchecked states, hierarchical and
            // multi-box layouts. RG-134 corpus expansion (2026-09-05).
            "benchmark/datasets/checkbox-fixtures/yes_off_unchecked_basic.pdf",
            "benchmark/datasets/checkbox-fixtures/yes_off_checked_basic.pdf",
            "benchmark/datasets/checkbox-fixtures/on_off_unchecked.pdf",
            "benchmark/datasets/checkbox-fixtures/on_off_checked.pdf",
            "benchmark/datasets/checkbox-fixtures/true_false_unchecked.pdf",
            "benchmark/datasets/checkbox-fixtures/one_off_unchecked.pdf",
            "benchmark/datasets/checkbox-fixtures/y_n_unchecked.pdf",
            "benchmark/datasets/checkbox-fixtures/checked_off_unchecked.pdf",
            "benchmark/datasets/checkbox-fixtures/checked_off_checked.pdf",
            "benchmark/datasets/checkbox-fixtures/hierarchical_names.pdf",
            "benchmark/datasets/checkbox-fixtures/multibox_same_page.pdf",
            "benchmark/datasets/checkbox-fixtures/prechecked_hierarchical.pdf",
            "benchmark/datasets/checkbox-fixtures/mixed_export_same_page.pdf",
            // Generated choice fixtures (pikepdf producer): real /Opt arrays
            // per PDF 32000-1 §12.7.5.4 — string, [export, display] pair,
            // numeric, hierarchical, multi-field+combo, empty-selection, and
            // editable-combo vocabularies. Fixes the phantom "PDFKit choice
            // unsupported" row (2026-09-06: buttonWidgetState no-ops on /Ch).
            "benchmark/datasets/choice-fixtures/dropdown_strings.pdf",
            "benchmark/datasets/choice-fixtures/dropdown_pairs.pdf",
            "benchmark/datasets/choice-fixtures/dropdown_numeric.pdf",
            "benchmark/datasets/choice-fixtures/choice_hierarchical.pdf",
            "benchmark/datasets/choice-fixtures/choice_multi_field.pdf",
            "benchmark/datasets/choice-fixtures/dropdown_empty_selection.pdf",
            "benchmark/datasets/choice-fixtures/combo_editable.pdf",
        ]
        
        var fixtures: [String] = []
        for rel in knownForms {
            let path = projectRoot.appendingPathComponent(rel).path
            if fm.fileExists(atPath: path) && !fixtures.contains(path) {
                fixtures.append(path)
            }
        }
        return fixtures
    }

    @Test("AcroFormFieldType classification")
    func fieldTypeClassification() {
        #expect(AcroFormFieldType.radio.supportsRoundTrip == true)
        #expect(AcroFormFieldType.checkbox.supportsRoundTrip == true)
        #expect(AcroFormFieldType.choice.supportsRoundTrip == true)
        #expect(AcroFormFieldType.text.supportsRoundTrip == true)
        #expect(AcroFormFieldType.signature.supportsRoundTrip == false)
        #expect(AcroFormFieldType.button.supportsRoundTrip == false)
    }

    @Test("ProviderCapability decision logic")
    func capabilityDecision() {
        let highConfidence = AcroFormCapability(
            provider: "PDFKit", fieldType: .text,
            canDetect: true, canRead: true, canWrite: true, canRoundTrip: true,
            verifiedFixtures: 10, failedFixtures: 0
        )
        #expect(highConfidence.decision == .productionReady)
        #expect(highConfidence.confidence == 1.0)

        let mediumConfidence = AcroFormCapability(
            provider: "PDF.js", fieldType: .choice,
            canDetect: true, canRead: true, canWrite: false, canRoundTrip: false,
            verifiedFixtures: 8, failedFixtures: 2
        )
        #expect(mediumConfidence.decision == .experimental)
        #expect(mediumConfidence.confidence == 0.8)

        let lowConfidence = AcroFormCapability(
            provider: "qpdf", fieldType: .radio,
            canDetect: true, canRead: false, canWrite: false, canRoundTrip: false,
            verifiedFixtures: 2, failedFixtures: 8
        )
        #expect(lowConfidence.decision == .unsupported)
        #expect(lowConfidence.confidence == 0.2)
    }

    @Test("Generated checkbox fixtures are present in the corpus (composition guard)")
    func generatedCheckboxFixturesInCorpus() {
        // Fail-closed on corpus composition: the 13 pikepdf-generated checkbox
        // fixtures are the corpus's boolean-vocabulary coverage (Yes/On/
        // Checked/1/Y/True export tokens × checked/unchecked states,
        // hierarchical names, multi-box, pre-checked, mixed-vocabulary pages).
        // RG-134's closure rests on them — a missing fixture would silently
        // narrow the confidence claim to the base forms.
        let fm = FileManager.default
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let generated = [
            "benchmark/datasets/checkbox-fixtures/yes_off_unchecked_basic.pdf",
            "benchmark/datasets/checkbox-fixtures/yes_off_checked_basic.pdf",
            "benchmark/datasets/checkbox-fixtures/on_off_unchecked.pdf",
            "benchmark/datasets/checkbox-fixtures/on_off_checked.pdf",
            "benchmark/datasets/checkbox-fixtures/true_false_unchecked.pdf",
            "benchmark/datasets/checkbox-fixtures/one_off_unchecked.pdf",
            "benchmark/datasets/checkbox-fixtures/y_n_unchecked.pdf",
            "benchmark/datasets/checkbox-fixtures/checked_off_unchecked.pdf",
            "benchmark/datasets/checkbox-fixtures/checked_off_checked.pdf",
            "benchmark/datasets/checkbox-fixtures/hierarchical_names.pdf",
            "benchmark/datasets/checkbox-fixtures/multibox_same_page.pdf",
            "benchmark/datasets/checkbox-fixtures/prechecked_hierarchical.pdf",
            "benchmark/datasets/checkbox-fixtures/mixed_export_same_page.pdf",
        ]
        let corpus = Set(Self.corpusFixtures())
        var present = 0
        for rel in generated {
            let path = projectRoot.appendingPathComponent(rel).path
            #expect(fm.fileExists(atPath: path), "generated checkbox fixture missing on disk: \(rel) — rerun the checkbox fixture generator")
            #expect(corpus.contains(path), "generated checkbox fixture missing from experiment corpus: \(rel)")
            if fm.fileExists(atPath: path), corpus.contains(path) { present += 1 }
        }
        #expect(present == 13, "all 13 generated checkbox fixtures must be corpus members, saw \(present)")
    }

    @Test("Generated choice fixtures are present in the corpus (composition guard)")
    func generatedChoiceFixturesInCorpus() {
        // Fail-closed on corpus composition: the 7 pikepdf-generated choice
        // fixtures are the experiment's real /Opt coverage (string, pair-form,
        // numeric, hierarchical, multi-field+combo, empty-selection,
        // editable-combo vocabularies). If any goes missing from disk or is
        // dropped from the corpus list, the choice confidence would silently
        // rest on the 9 base fixtures alone — this guard makes that a visible
        // failure instead of a drift.
        let fm = FileManager.default
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let generated = [
            "benchmark/datasets/choice-fixtures/dropdown_strings.pdf",
            "benchmark/datasets/choice-fixtures/dropdown_pairs.pdf",
            "benchmark/datasets/choice-fixtures/dropdown_numeric.pdf",
            "benchmark/datasets/choice-fixtures/choice_hierarchical.pdf",
            "benchmark/datasets/choice-fixtures/choice_multi_field.pdf",
            "benchmark/datasets/choice-fixtures/dropdown_empty_selection.pdf",
            "benchmark/datasets/choice-fixtures/combo_editable.pdf",
        ]
        let corpus = Set(Self.corpusFixtures())
        var present = 0
        for rel in generated {
            let path = projectRoot.appendingPathComponent(rel).path
            #expect(fm.fileExists(atPath: path), "generated choice fixture missing on disk: \(rel) — rerun benchmark/datasets/generate_choice_fixtures.py")
            #expect(corpus.contains(path), "generated choice fixture missing from experiment corpus: \(rel)")
            if fm.fileExists(atPath: path), corpus.contains(path) { present += 1 }
        }
        #expect(present == 7, "all 7 generated choice fixtures must be corpus members, saw \(present)")
    }

    @Test("Experiment runs against real PDF corpus and persists gate report")
    func experimentRuns() {
        // qpdf is the independent structural verifier this experiment exists
        // to measure; without it the run would be exactly the relabeled-engine
        // lie the regression guards below forbid. Absence = not_ran provenance.
        if !Self.qpdfAvailable() {
            print("not_ran: qpdf not installed; the independent-verifier experiment requires it (brew install qpdf)")
            return
        }

        let fixtures = Self.corpusFixtures()
        #expect(fixtures.count >= 1, "Need at least 1 corpus fixture")

        let results = AcroFormParityExperiment.runExperiment(fixturePaths: fixtures)
        #expect(results.count == 4) // radio, checkbox, choice, text

        for result in results {
            print("[parity] \(result.fieldType.rawValue): \(result.decision)")
            print("  agreement=\(String(format: "%.2f", result.crossProviderAgreement)) roundTrip=\(String(format: "%.2f", result.roundTripSuccessRate)) ghost=\(result.ghostFields)")
        }

        // Regression guards for the cross-provider claim.
        //
        // Falsified 2026-09-03: the old experiment ran the *same* PDFKit code
        // path under three labels ("PDFKit", "PDF.js", "qpdf") so the
        // cross-provider rows were byte-identical and the agreement was
        // inferred. The rows are now genuinely independent engines:
        //   PDFKit (native API), pdf-lib (pure-JS lane), IncrementalWriter
        //   (native production lane), qpdf (independent structural verifier,
        //   role=verifier, read-only by design).
        let radio = results.first { $0.fieldType == .radio }
        #expect(radio != nil)
        let radioProviders = radio!.capabilities.filter { $0.role == "provider" }
        let radioVerifiers = radio!.capabilities.filter { $0.role == "verifier" }
        #expect(radioProviders.contains { $0.provider == "PDFKit" })
        #expect(radioProviders.contains { $0.provider == "pdf-lib" },
                "pdf-lib lane must be present (independent engine measured, not PDFKit relabeled)")
        #expect(radioProviders.contains { $0.provider == "IncrementalWriter" })
        #expect(!radio!.capabilities.contains { $0.provider == "PDF.js" },
                "The simulated PDF.js row must be gone")
        #expect(radioVerifiers.contains { $0.provider == "qpdf" },
                "qpdf must be present as a verifier (read-only, genuinely executed)")
        #expect(radioVerifiers.allSatisfy { $0.canWrite == false && $0.canRoundTrip == false },
                "qpdf cannot fill forms; a write claim would be a relabeled PDFKit lie")
        for capability in radioProviders {
            #expect(capability.canDetect,
                    "Radio must be detected by \(capability.provider)")
        }
        // Radio gate semantics mirror docs/release-gates.md RG-133 and the CI
        // check: radio is REPORTED but NOT gated. pdf-lib is the measured
        // production-ready radio provider and must round-trip; PDFKit and
        // IncrementalWriter are documented experimental (PDFKit's annotation
        // API omits group /V on save; IncrementalWriter refuses
        // compressed/no-AcroForm sources fail-closed), so they must carry
        // measured evidence but their experimental tier is not a failure.
        let pdfLibRadio = radioProviders.first { $0.provider == "pdf-lib" }
        #expect(pdfLibRadio?.canRoundTrip == true,
                "pdf-lib (production-ready radio provider) must round-trip radio")
        #expect((pdfLibRadio?.verifiedFixtures ?? 0) > 0,
                "pdf-lib radio must carry measured fixture evidence")
        let incrementalWriterRadio = radioProviders.first { $0.provider == "IncrementalWriter" }
        let incrementalWriterRoundTrips = (incrementalWriterRadio?.canRoundTrip ?? false)
            && (incrementalWriterRadio?.verifiedFixtures ?? 0) > 0
        let incrementalWriterDocumentedTier = incrementalWriterRadio?.decision == .experimental
            || incrementalWriterRadio?.decision == .unsupported
        #expect(incrementalWriterRoundTrips || incrementalWriterDocumentedTier,
                "IncrementalWriter radio must round-trip or be an explicitly documented experimental/unsupported tier (never a silent gap)")
        #expect(radio!.verifiedFixturesCount > 0,
                "Radio must have real fixture evidence, not N/A")

        // The independent pdf-lib engine must have produced its own measured
        // evidence (text round-trips on the corpus), not inherited numbers.
        let text = results.first { $0.fieldType == .text }
        let pdfLibText = text?.capabilities.first { $0.provider == "pdf-lib" }
        #expect((pdfLibText?.verifiedFixtures ?? 0) > 0,
                "pdf-lib text lane must carry measured fixture evidence")

        // Choice regression guard (2026-09-06): production-ready on every
        // provider, with verified counts that PROVE the 7 generated /Opt
        // fixtures contributed. 9 base fixtures carry choice fields; the
        // generated fixtures bring the round-tripping total to 16 on the
        // write lanes (8 verified through qpdf's independent structural
        // channel). A drop below these floors means the real /Opt coverage
        // silently stopped measuring.
        let choice = results.first { $0.fieldType == .choice }
        #expect(choice != nil, "choice must be measured")
        if let choice {
            #expect(choice.decision == "All providers production-ready for choice",
                    "choice must stay production-ready on every provider (RG-133 falsifier), got \(choice.decision)")
            for providerName in ["PDFKit", "pdf-lib"] {
                let cap = choice.capabilities.first { $0.provider == providerName && $0.role == "provider" }
                #expect((cap?.verifiedFixtures ?? 0) >= 16,
                        "\(providerName) choice must verify ≥16 fixtures (9 base + 7 generated /Opt corpus), got \(cap?.verifiedFixtures ?? 0)")
            }
            let qpdfCap = choice.capabilities.first { $0.provider == "qpdf" }
            #expect((qpdfCap?.verifiedFixtures ?? 0) >= 8,
                    "qpdf choice verifier must confirm ≥8 fixtures, got \(qpdfCap?.verifiedFixtures ?? 0)")
        }

        // Checkbox regression guard (RG-134, 2026-09-06): production-ready on
        // every provider with verified counts proving the 13 generated
        // vocabulary fixtures contribute. 9 base fixtures carry checkboxes;
        // the generated corpus brings write-lane verification to ≥22 (PDFKit
        // 23) and qpdf's structural channel to ≥8. RG-134's version-bump bar
        // (production_ready, confidence ≥ 0.9) is asserted here so it is
        // enforced on every suite run, not only by the release runbook.
        let checkbox = results.first { $0.fieldType == .checkbox }
        #expect(checkbox != nil, "checkbox must be measured")
        if let checkbox {
            #expect(checkbox.decision == "All providers production-ready for checkbox",
                    "checkbox must stay production-ready on every provider (RG-134 falsifier), got \(checkbox.decision)")
            for providerName in ["PDFKit", "pdf-lib"] {
                let cap = checkbox.capabilities.first { $0.provider == providerName && $0.role == "provider" }
                #expect((cap?.verifiedFixtures ?? 0) >= 22,
                        "\(providerName) checkbox must verify ≥22 fixtures (9 base + 13 generated corpus), got \(cap?.verifiedFixtures ?? 0)")
                #expect((cap?.confidence ?? 0) >= 0.9,
                        "\(providerName) checkbox confidence must hold the RG-134 ≥0.9 bar, got \(cap?.confidence ?? 0)")
            }
            let qpdfCap = checkbox.capabilities.first { $0.provider == "qpdf" }
            #expect((qpdfCap?.verifiedFixtures ?? 0) >= 8,
                    "qpdf checkbox verifier must confirm ≥8 fixtures, got \(qpdfCap?.verifiedFixtures ?? 0)")
        }

        // Persist the gate report.
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let outputDir = projectRoot.appendingPathComponent("benchmark/results/acroform-parity").path
        let url = AcroFormParityExperiment.persistReport(
            results: results,
            corpusSize: fixtures.count,
            outputDir: outputDir
        )
        #expect(url != nil, "Gate report must be persisted")
        #expect(FileManager.default.fileExists(atPath: outputDir + "/acroform-parity-gate-report.json"))
    }

    @Test("Radio group selection round-trips with the specific option preserved")
    func radioSelectionRoundTrip() throws {
        // public-acroform carries a real radio group: applicant.contact with
        // two kids whose export values are "0" and "1" (Verified via PDFKit
        // probe: buttonWidgetStateString reports the export value on each kid
        // regardless of selection state).
        let fm = FileManager.default
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = projectRoot
            .appendingPathComponent("benchmark/results/2026-08-23-public-acroform/noop.pdf").path
        #expect(fm.fileExists(atPath: path), "public-acroform fixture must be committed")
        guard fm.fileExists(atPath: path) else { return }

        guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
            Issue.record("Failed to open public-acroform fixture")
            return
        }

        // Find the radio group: /Btn annotations sharing the name
        // applicant.contact.
        var group: [PDFAnnotation] = []
        for p in 0..<doc.pageCount {
            guard let page = doc.page(at: p) else { continue }
            for a in page.annotations where a.widgetFieldType.rawValue == "/Btn" {
                if a.fieldName == "applicant.contact" {
                    group.append(a)
                }
            }
        }
        #expect(group.count == 2, "applicant.contact must be a 2-kid radio group")
        let exportValues = Set(group.map { $0.buttonWidgetStateString })
        #expect(exportValues == ["0", "1"], "Radio kids expose their export values")

        // Select the currently-off kid: off-then-on order (Verified: PDFKit's
        // .off setter clears the group, so .on must be written last).
        guard let target = group.first(where: { $0.buttonWidgetState.rawValue != 1 }) else {
            Issue.record("Expected at least one off kid")
            return
        }
        let expected = target.buttonWidgetStateString
        for f in group where f !== target {
            f.buttonWidgetState = PDFWidgetCellState(rawValue: 0)!
        }
        target.buttonWidgetState = PDFWidgetCellState(rawValue: 1)!

        let tmp = NSTemporaryDirectory() + "radio-rt-\(UUID().uuidString).pdf"
        let tmpURL = URL(fileURLWithPath: tmp)
        guard doc.write(to: tmpURL) else {
            Issue.record("Save failed")
            return
        }
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let reopened = PDFDocument(url: tmpURL) else {
            Issue.record("Reopen failed")
            return
        }
        var reopenedKids: [PDFAnnotation] = []
        for p in 0..<reopened.pageCount {
            guard let page = reopened.page(at: p) else { continue }
            for a in page.annotations where a.widgetFieldType.rawValue == "/Btn" {
                if a.fieldName == "applicant.contact" {
                    reopenedKids.append(a)
                }
            }
        }
        let selected = reopenedKids.filter { $0.buttonWidgetState.rawValue == 1 }
        #expect(selected.count == 1, "Exactly one radio kid must be selected")
        #expect(selected.first?.buttonWidgetStateString == expected,
                "The specific written selection must survive reopen")
    }
}

extension AcroFormParityResult {
    /// Total fixtures with verified round-trip evidence across providers.
    var verifiedFixturesCount: Int {
        capabilities.reduce(0) { $0 + $1.verifiedFixtures }
    }
}
