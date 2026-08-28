import SwiftUI
import PDFEditorCore

/// SwiftUI view for the LEARN study loop.
///
/// Shows marks in review/recall/quiz mode with a progress bar,
/// mastery indicators, and recall interaction.
///
/// Doctrine alignment:
/// - §3: Do things smartly — reuses existing AnnotationMark data
/// - §5: Evidence-based — mastery levels displayed with data
/// - §8: Opt-in — only appears when user enters study mode
struct StudyLoopView: View {
  let documentID: String
  let marks: [AnnotationMark]
  @ObservedObject var annotationStore: AnnotationStore
  @StateObject private var manager = StudyLoopManager()
  @State private var session: StudySession?
  @State private var recallState: RecallState = .complete
  @State private var showingSummary = false
  @State private var selectedMode: StudyMode = .recall
  // Add mark state
  @State private var showingAddMark = false
  @State private var newMarkText = ""
  @State private var newMarkNote = ""
  @State private var newMarkType: AnnotationType = .highlight
  @State private var newMarkColor: AnnotationColor = .yellow
  @State private var newMarkPageIndex = 0

  var body: some View {
    VStack(spacing: 0) {
      if let session = session {
        if session.isComplete {
          completionView
        } else {
          sessionHeader(session)
          Divider()
          if selectedMode == .review {
            reviewCard(session)
          } else {
            recallCard(session)
          }
          Divider()
          sessionFooter(session)
        }
      } else {
        startView
      }
    }
    .navigationTitle("Study Loop")
    .sheet(isPresented: $showingSummary) {
      summarySheet
    }
    .sheet(isPresented: $showingAddMark) {
      addMarkSheet
    }
  }

  // MARK: - Start View

  private var startView: some View {
    VStack(spacing: 20) {
      Image(systemName: "brain.head.profile")
        .font(.system(size: 48))
        .foregroundColor(.purple)

      Text("Study Your Marks")
        .font(.title2.bold())

      Text("\(marks.count) annotation\(marks.count == 1 ? "" : "s") available for review")
        .foregroundColor(.secondary)

      // Mode picker
      Picker("Mode", selection: $selectedMode) {
        ForEach(StudyMode.allCases) { mode in
          Text(mode.displayName).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal, 40)

      // Mastery preview
      let summary = manager.summary(for: documentID, marks: marks)
      if summary.total > 0 {
        masteryBar(summary)
          .padding(.horizontal, 40)
      }

      Button("Start Session") {
        session = manager.startSession(marks: marks, mode: selectedMode, documentID: documentID)
        if selectedMode != .review {
          recallState = .hidden(question: RecallQuestion(mark: marks[0]))
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(marks.isEmpty)
    }
    .padding(40)
  }

  // MARK: - Session Header

  private func sessionHeader(_ session: StudySession) -> some View {
    HStack {
      // Progress
      ProgressView(value: session.progress)
        .frame(maxWidth: 200)

      Text("\(session.reviewedCount)/\(session.marks.count)")
        .font(.caption.monospacedDigit())
        .foregroundColor(.secondary)

      Spacer()

      // Current mode badge
      Label(session.mode.displayName, systemImage: session.mode.symbolName)
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(6)

      Spacer()

      // Mastery
      let summary = session.masterySummary
      Text(summary.description)
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  // MARK: - Review Card (passive reading)

  private func reviewCard(_ session: StudySession) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      if let question = session.currentQuestion {
        // Page indicator
        HStack {
          Circle()
            .fill(question.mark.color.swiftUIColor)
            .frame(width: 12, height: 12)
          Text("Page \(question.pageNumber)")
            .font(.caption)
            .foregroundColor(.secondary)
          Spacer()
          Text(question.category)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(4)
        }

        // Selected text
        if !question.mark.selectedText.isEmpty {
          Text(question.mark.selectedText)
            .font(.body)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(question.mark.color.swiftUIColor.opacity(0.15))
            .cornerRadius(8)
        }

        // Note
        if !question.mark.note.isEmpty {
          HStack(alignment: .top, spacing: 6) {
            Image(systemName: "note.text")
              .foregroundColor(.secondary)
            Text(question.mark.note)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.gray.opacity(0.08))
          .cornerRadius(8)
        }

        // Tags
        if !question.mark.tags.isEmpty {
          HStack {
            ForEach(question.mark.tags, id: \.self) { tag in
              Text("#\(tag)")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
            }
          }
        }
      }
    }
    .padding()
  }

  // MARK: - Recall Card (active testing)

  private func recallCard(_ session: StudySession) -> some View {
    VStack(spacing: 16) {
      if let question = session.currentQuestion {
        switch recallState {
        case .hidden(let q):
          // Question mode — answer is hidden
          VStack(spacing: 12) {
            // Category badge
            HStack {
              Circle()
                .fill(question.mark.color.swiftUIColor)
                .frame(width: 12, height: 12)
              Text("Page \(question.pageNumber) · \(question.category)")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
            }

            // Hint
            if !q.hint.isEmpty {
              Text("Hint: \"\(q.hint)\"")
                .font(.subheadline.italic())
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }

            // Prompt
            Text("What was marked here?")
              .font(.headline)
              .frame(maxWidth: .infinity, alignment: .leading)

            // Note prompt (if mark has a note)
            if !question.mark.note.isEmpty {
              Text("Note: \(question.mark.note.prefix(30))...")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .padding()

          // Reveal button
          Button(action: {
            let answer = RecallAnswer(question: question)
            recallState = .revealed(answer: answer)
            manager.recordCorrect(documentID: documentID, markID: question.mark.id)
          }) {
            Label("I Knew It", systemImage: "checkmark")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(.green)

          Button(action: {
            let answer = RecallAnswer(question: question)
            recallState = .revealed(answer: answer)
            manager.recordIncorrect(documentID: documentID, markID: question.mark.id)
          }) {
            Label("Didn't Know", systemImage: "xmark")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .tint(.red)

        case .revealed(let answer):
          // Answer revealed
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Circle()
                .fill(answer.color.swiftUIColor)
                .frame(width: 12, height: 12)
              Text("Page \(answer.pageNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
            }

            if !answer.selectedText.isEmpty {
              Text(answer.selectedText)
                .font(.body)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(answer.color.swiftUIColor.opacity(0.15))
                .cornerRadius(8)
            }

            if !answer.note.isEmpty {
              HStack(alignment: .top, spacing: 6) {
                Image(systemName: "note.text")
                  .foregroundColor(.secondary)
                Text(answer.note)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.gray.opacity(0.08))
              .cornerRadius(8)
            }
          }
          .padding()

        case .complete:
          EmptyView()
        }
      }
    }
  }

  // MARK: - Session Footer

  private func sessionFooter(_ currentSession: StudySession) -> some View {
    HStack {
      if currentSession.currentIndex > 0 {
        Button("Previous") {
          let prev = StudySession(
            marks: currentSession.marks,
            mode: currentSession.mode,
            currentIndex: currentSession.currentIndex - 1,
            mastery: currentSession.mastery,
            startedAt: currentSession.startedAt
          )
          self.session = prev
          if selectedMode != .review {
            recallState = .hidden(question: RecallQuestion(mark: currentSession.marks[currentSession.currentIndex - 1]))
          }
        }
        .buttonStyle(.bordered)
      }

      // Add new mark button
      Button {
        // Pre-fill with current mark's page if available
        if let question = currentSession.currentQuestion {
          newMarkPageIndex = question.mark.pageIndex
        }
        showingAddMark = true
      } label: {
        Label("Add Mark", systemImage: "plus.circle")
      }
      .buttonStyle(.bordered)
      .tint(.purple)

      Spacer()

      Button("End Session") {
        showingSummary = true
        session = nil
        recallState = .complete
      }
      .buttonStyle(.bordered)
      .tint(.red)

      Spacer()

      if !currentSession.isComplete {
        Button("Next") {
          let next = manager.nextSessionState(from: currentSession)
          self.session = next
          if selectedMode != .review, let q = next.currentQuestion {
            recallState = .hidden(question: q)
          }
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding()
  }

  // MARK: - Completion View

  private var completionView: some View {
    VStack(spacing: 20) {
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 48))
        .foregroundColor(.green)

      Text("Session Complete!")
        .font(.title2.bold())

      Text("You reviewed \(marks.count) mark\(marks.count == 1 ? "" : "s")")
        .foregroundColor(.secondary)

      let summary = manager.summary(for: documentID, marks: marks)
      masteryBar(summary)
        .padding(.horizontal, 40)

      Button("Start New Session") {
        session = nil
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(40)
  }

  // MARK: - Summary Sheet

  private var summarySheet: some View {
    VStack(spacing: 16) {
      Text("Session Summary")
        .font(.title3.bold())

      let summary = manager.summary(for: documentID, marks: marks)
      masteryBar(summary)
        .padding(.horizontal)

      Divider()

      // Per-level breakdown
      VStack(alignment: .leading, spacing: 8) {
        masteryRow(level: .mastered, count: summary.mastered, color: .green)
        masteryRow(level: .review, count: summary.review, color: .blue)
        masteryRow(level: .learning, count: summary.learning, color: .orange)
        masteryRow(level: .seen, count: summary.seen, color: .gray)
        masteryRow(level: .new, count: summary.new, color: .purple)
      }
      .padding()

      Spacer()
    }
    .padding(20)
    .frame(width: 300, height: 350)
  }

  // MARK: - Add Mark Sheet

  private var addMarkSheet: some View {
    NavigationStack {
      Form {
        Section("Mark Details") {
          TextField("Selected text", text: $newMarkText)
            .font(.body)

          TextField("Note (optional)", text: $newMarkNote)
            .font(.subheadline)

          Stepper("Page: \(newMarkPageIndex + 1)", value: $newMarkPageIndex, in: 0...max(0, marks.first?.pageIndex ?? 0 + 10))
        }

        Section("Type") {
          Picker("Mark Type", selection: $newMarkType) {
            Text("Highlight").tag(AnnotationType.highlight)
            Text("Underline").tag(AnnotationType.underline)
            Text("Note").tag(AnnotationType.note)
          }
          .pickerStyle(.segmented)
        }

        Section("Color") {
          HStack(spacing: 12) {
            ForEach([AnnotationColor.yellow, .green, .blue, .pink, .orange, .purple, .red, .gray], id: \.self) { color in
              Circle()
                .fill(color.swiftUIColor)
                .frame(width: 30, height: 30)
                .overlay(
                  Circle().strokeBorder(Color.white, lineWidth: 2)
                )
                .shadow(radius: newMarkColor == color ? 3 : 0)
                .overlay(
                  Circle().strokeBorder(Color.primary, lineWidth: newMarkColor == color ? 2 : 0)
                )
                .onTapGesture {
                  newMarkColor = color
                }
            }
          }
          .padding(.vertical, 8)
        }
      }
      .navigationTitle("New Mark")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            showingAddMark = false
            resetAddMarkFields()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            addMark()
            showingAddMark = false
            resetAddMarkFields()
          }
          .disabled(newMarkText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
    .frame(width: 400, height: 350)
  }

  private func addMark() {
    // Default bounds — user can adjust position after adding
    let defaultBounds = PDFRect(x: 0, y: 0, width: 200, height: 30)
    let mark = AnnotationMark(
      type: newMarkType,
      pageIndex: newMarkPageIndex,
      bounds: defaultBounds,
      selectedText: newMarkText,
      note: newMarkNote,
      color: newMarkColor
    )
    annotationStore.addMark(mark)
  }

  private func resetAddMarkFields() {
    newMarkText = ""
    newMarkNote = ""
    newMarkType = .highlight
    newMarkColor = .yellow
  }

  // MARK: - Helpers

  private func masteryBar(_ summary: MasterySummary) -> some View {
    GeometryReader { geo in
      HStack(spacing: 0) {
        if summary.mastered > 0 {
          Rectangle()
            .fill(Color.green)
            .frame(width: geo.size.width * CGFloat(summary.mastered) / CGFloat(max(summary.total, 1)))
        }
        if summary.review > 0 {
          Rectangle()
            .fill(Color.blue)
            .frame(width: geo.size.width * CGFloat(summary.review) / CGFloat(max(summary.total, 1)))
        }
        if summary.learning > 0 {
          Rectangle()
            .fill(Color.orange)
            .frame(width: geo.size.width * CGFloat(summary.learning) / CGFloat(max(summary.total, 1)))
        }
        if summary.seen > 0 {
          Rectangle()
            .fill(Color.gray)
            .frame(width: geo.size.width * CGFloat(summary.seen) / CGFloat(max(summary.total, 1)))
        }
        if summary.new > 0 {
          Rectangle()
            .fill(Color.purple.opacity(0.4))
            .frame(width: geo.size.width * CGFloat(summary.new) / CGFloat(max(summary.total, 1)))
        }
      }
    }
    .frame(height: 8)
    .clipShape(Capsule())
  }

  private func masteryRow(level: MasteryLevel, count: Int, color: Color) -> some View {
    HStack {
      Image(systemName: level.symbolName)
        .foregroundColor(color)
        .frame(width: 20)
      Text(level.displayName)
        .font(.subheadline)
      Spacer()
      Text("\(count)")
        .font(.subheadline.monospacedDigit())
        .foregroundColor(.secondary)
    }
  }
}

// MARK: - Color Extension

extension AnnotationColor {
  var swiftUIColor: Color {
    switch self {
    case .yellow: return .yellow
    case .green: return .green
    case .blue: return .blue
    case .pink: return .pink
    case .orange: return .orange
    case .purple: return .purple
    case .red: return .red
    case .gray: return .gray
    }
  }
}
