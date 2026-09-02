import SwiftUI
import PDFKit
import PDFEditorCore

/// Human visual confirmation panel (RG-135).
///
/// A reviewer walks the governed manifest fixture-by-fixture, inspects the
/// rendered document in an embedded PDFKit view, records per-dimension
/// verdicts, and persists confirmations to the shared ledger artifact
/// (`benchmark/results/human-visual-confirmation/human-review-ledger.json`).
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — confirmations bind to the fixture's current SHA-256;
///   a changed file invalidates prior confirmations (stale).
/// - §0 Fail-closed — the gate reports `pending` while coverage is incomplete.
/// - §13 Claim reality — the panel always shows gate truth (pass / pending /
///   fail); there is no way to bypass an incomplete review from the UI.
@MainActor
struct HumanReviewPanelView: View {
    @State private var store: HumanVisualConfirmationStore
    @State private var selectedFixtureId: String?
    @State private var reviewerName: String = ""
    @State private var notes: String = ""
    @State private var draftVerdicts: [HumanReviewDimension: HumanReviewVerdict] = [:]
    @State private var document: PDFDocument?
    @State private var saveError: String?
    @State private var showSavedConfirmation = false

    private let projectRoot: String

    init(projectRoot: String? = nil) {
        // Tests pass a temp root; the app resolves the checkout root at runtime.
        let root = projectRoot ?? Self.detectProjectRoot()
        self.projectRoot = root
        _store = State(initialValue: HumanVisualConfirmationStore(projectRoot: root))
    }

    /// Walk up from the working directory to find the checkout root
    /// (the directory containing benchmark/results/governed-corpus-manifest.json).
    static func detectProjectRoot() -> String {
        var dir = FileManager.default.currentDirectoryPath
        for _ in 0..<6 {
            let marker = (dir as NSString).appendingPathComponent("benchmark/results/governed-corpus-manifest.json")
            if FileManager.default.fileExists(atPath: marker) { return dir }
            let parent = (dir as NSString).deletingLastPathComponent
            if parent == dir { break }
            dir = parent
        }
        return FileManager.default.currentDirectoryPath
    }

    private var selectedFixture: HumanVisualConfirmationStore.HumanReviewFixtureInfo? {
        guard let id = selectedFixtureId else { return nil }
        return store.manifestFixtures.first { $0.id == id }
    }

    private var fixturesNeedingReview: [HumanVisualConfirmationStore.HumanReviewFixtureInfo] {
        store.manifestFixtures.filter { fixture in
            guard fixture.exists else { return false }
            return store.reviewState(for: fixture) != .confirmed
        }
    }

    var body: some View {
        HSplitView {
            fixtureList
                .frame(minWidth: 280, maxWidth: 380)
            reviewPane
                .frame(minWidth: 560, maxWidth: .infinity, minHeight: 480)
        }
        .frame(minWidth: 920, minHeight: 560)
        .onAppear(perform: selectDefaultFixture)
        .onChange(of: selectedFixtureId) { _, _ in loadSelectionState() }
    }

    // MARK: - Fixture list

    private var fixtureList: some View {
        VStack(spacing: 0) {
            gateSummaryHeader
            List(selection: $selectedFixtureId) {
                ForEach(groupedByClass.keys.sorted(), id: \.self) { documentClass in
                    Section(documentClass) {
                        ForEach(groupedByClass[documentClass] ?? []) { fixture in
                            fixtureRow(fixture)
                                .tag(fixture.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var groupedByClass: [String: [HumanVisualConfirmationStore.HumanReviewFixtureInfo]] {
        Dictionary(grouping: store.manifestFixtures, by: \.documentClass)
    }

    private var gateSummaryHeader: some View {
        let report = store.evaluateGate()
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: gateSymbol(report.status))
                    .foregroundStyle(gateColor(report.status))
                Text("RG-135: \(report.status.uppercased())")
                    .font(.headline)
                Spacer()
                Text("\(report.confirmedCount)/\(report.totalFixtures)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(report.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(10)
    }

    private func gateSymbol(_ status: String) -> String {
        switch status {
        case "pass": return "checkmark.seal.fill"
        case "fail": return "xmark.seal.fill"
        default: return "hourglass"
        }
    }

    private func gateColor(_ status: String) -> Color {
        switch status {
        case "pass": return .green
        case "fail": return .red
        default: return .orange
        }
    }

    private func fixtureRow(_ fixture: HumanVisualConfirmationStore.HumanReviewFixtureInfo) -> some View {
        HStack(spacing: 8) {
            stateSymbol(store.reviewState(for: fixture))
            VStack(alignment: .leading, spacing: 2) {
                Text(fixture.id)
                    .font(.callout)
                    .lineLimit(1)
                Text(fixture.relativePath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func stateSymbol(_ state: HumanVisualConfirmationStore.FixtureReviewState) -> some View {
        switch state {
        case .confirmed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .stale:
            Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
        case .pending:
            Image(systemName: "circle.dashed").foregroundStyle(.secondary)
        }
    }

    // MARK: - Review pane

    @ViewBuilder
    private var reviewPane: some View {
        if let fixture = selectedFixture {
            VStack(alignment: .leading, spacing: 10) {
                header(fixture)
                if fixture.exists {
                    pdfPreview(fixture)
                    verdictGrid
                    reviewerFields
                    recordBar(fixture)
                } else {
                    missingFixtureNotice(fixture)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        } else {
            emptyState
        }
    }

    private func header(_ fixture: HumanVisualConfirmationStore.HumanReviewFixtureInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fixture.id).font(.title3.weight(.semibold))
                Spacer()
                Label(fixture.documentClass, systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(fixture.description)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func pdfPreview(_ fixture: HumanVisualConfirmationStore.HumanReviewFixtureInfo) -> some View {
        Group {
            if let document {
                PDFKitRepresentedView(document: document)
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.4))
                    .frame(height: 120)
                    .overlay(Text("Preview unavailable").foregroundStyle(.secondary))
            }
        }
    }

    private func missingFixtureNotice(_ fixture: HumanVisualConfirmationStore.HumanReviewFixtureInfo) -> some View {
        Label("Fixture file missing on disk: \(fixture.relativePath)", systemImage: "exclamationmark.triangle")
            .foregroundStyle(.orange)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var verdictGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dimension verdicts").font(.headline)
            ForEach(HumanReviewDimension.allCases, id: \.self) { dimension in
                HStack {
                    Text(dimension.displayName)
                        .frame(width: 140, alignment: .leading)
                    Spacer()
                    Picker(dimension.displayName, selection: binding(for: dimension)) {
                        Text("—").tag(HumanReviewVerdict?.none)
                        Text("Confirmed").tag(HumanReviewVerdict?.some(.confirmed))
                        Text("Failed").tag(HumanReviewVerdict?.some(.failed))
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                    .accessibilityLabel("Verdict for \(dimension.displayName)")
                }
            }
        }
    }

    private func binding(for dimension: HumanReviewDimension) -> Binding<HumanReviewVerdict?> {
        Binding(
            get: { draftVerdicts[dimension] },
            set: { draftVerdicts[dimension] = $0 }
        )
    }

    private var reviewerFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Reviewer").frame(width: 140, alignment: .leading)
                TextField("Name or id (recorded in artifact)", text: $reviewerName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Reviewer identity")
            }
            HStack(alignment: .top, spacing: 8) {
                Text("Notes").frame(width: 140, alignment: .leading)
                TextEditor(text: $notes)
                    .frame(minHeight: 48, maxHeight: 90)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Review notes")
            }
        }
    }

    @ViewBuilder
    private func recordBar(_ fixture: HumanVisualConfirmationStore.HumanReviewFixtureInfo) -> some View {
        HStack {
            if let saveError {
                Label(saveError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            if showSavedConfirmation {
                Label("Recorded", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }
            Spacer()
            Button("Record Confirmation") {
                Task { recordFixture(fixture) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(reviewerName.trimmingCharacters(in: .whitespaces).isEmpty || draftVerdicts.count < HumanReviewDimension.allCases.count)
            .accessibilityLabel("Record confirmation for \(fixture.id)")
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Select a fixture",
            systemImage: "eye",
            description: Text("Choose a governed fixture to review and record human visual confirmations.")
        )
    }

    // MARK: - Actions

    private func selectDefaultFixture() {
        if selectedFixtureId == nil {
            selectedFixtureId = fixturesNeedingReview.first?.id ?? store.manifestFixtures.first?.id
        }
        loadSelectionState()
    }

    private func loadSelectionState() {
        guard let fixture = selectedFixture else { return }
        document = PDFDocument(url: URL(fileURLWithPath: fixture.absolutePath))
        notes = ""
        draftVerdicts = [:]
        showSavedConfirmation = false
        saveError = nil
        // Pre-fill reviewer with the last recorded reviewer name for convenience.
        if reviewerName.isEmpty, let last = store.ledger.entries.last {
            reviewerName = last.reviewer
        }
    }

    private func recordFixture(_ fixture: HumanVisualConfirmationStore.HumanReviewFixtureInfo) {
        do {
            try store.record(
                fixture: fixture,
                reviewer: reviewerName,
                verdicts: draftVerdicts,
                notes: notes
            )
            saveError = nil
            showSavedConfirmation = true
            // Refresh fixture digests (guard against edits during review).
            store.reloadFixtures()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSavedConfirmation = false
            }
        } catch {
            saveError = "Could not record: \(error)"
        }
    }
}

// MARK: - PDFKit representable

private struct PDFKitRepresentedView: NSViewRepresentable {
    let document: PDFDocument?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayBox = .cropBox
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.dataRepresentation() != document?.dataRepresentation() {
            view.document = document
        }
    }
}
