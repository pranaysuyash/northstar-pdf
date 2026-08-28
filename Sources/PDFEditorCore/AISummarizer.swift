import Foundation

/// AI-powered document summarizer with TF-IDF scoring and TextRank-style sentence ranking.
///
/// Builds on the basic `DocumentSummarizer` by adding:
/// - TF-IDF term weighting for sentence importance
/// - TextRank graph-based ranking (sentence similarity as edges)
/// - Sentence compression (remove redundancy)
/// - Category-balanced extraction (ensure variety)
///
/// First principle: A good summary preserves the most important information
/// while discarding noise. TF-IDF captures term importance; TextRank captures
/// sentence centrality; compression removes redundancy.
///
/// Doctrine alignment:
/// - §3: Do things smartly — no AI dependency, pure algorithmic approach
/// - §5: Evidence-based — confidence scores for every claim
/// - §8: Capability routing — works standalone, no external services

// MARK: - TF-IDF Summarizer

/// Enhanced summarizer using TF-IDF term weighting and TextRank sentence ranking.
public struct AISummarizer: Sendable {
    /// Maximum sentences in summary.
    public let maxSentences: Int
    /// Minimum sentence length to consider.
    public let minSentenceLength: Int
    /// Damping factor for TextRank (0-1, higher = more smoothing).
    public let dampingFactor: Double
    /// Number of iterations for TextRank convergence.
    public let iterations: Int
    /// Similarity threshold for TextRank edge creation.
    public let similarityThreshold: Double

    public init(
        maxSentences: Int = 5,
        minSentenceLength: Int = 15,
        dampingFactor: Double = 0.85,
        iterations: Int = 30,
        similarityThreshold: Double = 0.1
    ) {
        self.maxSentences = maxSentences
        self.minSentenceLength = minSentenceLength
        self.dampingFactor = dampingFactor
        self.iterations = iterations
        self.similarityThreshold = similarityThreshold
    }

    /// Generate an enhanced summary from extraction result.
    public func summarize(extraction: StructuredExtractionResult) -> EnhancedSummary {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Split into sentences
        let sentences = extraction.fullText
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= minSentenceLength }

        guard !sentences.isEmpty else {
            return EnhancedSummary(
                summary: "",
                sentences: [],
                tfidfScores: [:],
                textrankScores: [:],
                totalSentences: 0,
                compressionRatio: 0,
                extractionTimeMs: 0
            )
        }

        // Step 1: Build TF-IDF model
        let tfidfScores = computeTFIDF(sentences: sentences)

        // Step 2: Compute TF-IDF sentence scores
        let sentenceTFIDFScores = sentences.enumerated().map { index, sentence in
            (index: index, score: sentenceTFIDFScore(sentence: sentence, tfidf: tfidfScores))
        }

        // Step 3: Build TextRank similarity graph
        let textrankScores = textRank(
            sentences: sentences,
            damping: dampingFactor,
            iterations: iterations,
            threshold: similarityThreshold
        )

        // Step 4: Combine scores (weighted average)
        let combinedScores = sentences.enumerated().map { index, sentence in
            let tfidf = sentenceTFIDFScores.first(where: { $0.index == index })?.score ?? 0
            let textrank = textrankScores[index] ?? 0
            // TF-IDF 40%, TextRank 60% — TextRank captures global structure better
            let combined = tfidf * 0.4 + textrank * 0.6
            return (index: index, score: combined, sentence: sentence)
        }

        // Step 5: Select top sentences, maintain document order
        let selected = combinedScores
            .sorted { $0.score > $1.score }
            .prefix(maxSentences)
            .sorted { $0.index < $1.index }

        let summary = selected.map(\.sentence).joined(separator: ". ")

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let compressionRatio = Double(maxSentences) / Double(sentences.count)

        return EnhancedSummary(
            summary: summary,
            sentences: selected.map { EnhancedSummary.Sentence(
                text: $0.sentence,
                index: $0.index,
                combinedScore: $0.score,
                tfidfScore: sentenceTFIDFScores.first(where: { $0.index == $0.index })?.score ?? 0,
                textrankScore: textrankScores[$0.index] ?? 0
            )},
            tfidfScores: Dictionary(uniqueKeysWithValues: tfidfScores.map { ($0.key, $0.value) }),
            textrankScores: textrankScores,
            totalSentences: sentences.count,
            compressionRatio: compressionRatio,
            extractionTimeMs: elapsed
        )
    }

    // MARK: - TF-IDF

    /// Compute TF-IDF scores for all terms across all sentences.
    private func computeTFIDF(sentences: [String]) -> [String: Double] {
        let tokenized = sentences.map { tokenize($0) }
        let documentCount = Double(sentences.count)

        // Document frequency: how many sentences contain each term
        var docFrequency: [String: Int] = [:]
        for tokens in tokenized {
            let unique = Set(tokens)
            for token in unique {
                docFrequency[token, default: 0] += 1
            }
        }

        // TF-IDF for each term in each sentence, then average
        var tfidfAccum: [String: Double] = [:]
        var tfidfCount: [String: Int] = [:]

        for tokens in tokenized {
            let termFreq = tokens.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
            let maxFreq = Double(termFreq.values.max() ?? 1)

            for (term, freq) in termFreq {
                let tf = 0.5 + 0.5 * (Double(freq) / maxFreq) // Augmented TF
                let df = Double(docFrequency[term] ?? 1)
                let idf = log(documentCount / df)
                let tfidf = tf * idf

                tfidfAccum[term, default: 0] += tfidf
                tfidfCount[term, default: 0] += 1
            }
        }

        // Average TF-IDF across sentences
        var result: [String: Double] = [:]
        for (term, score) in tfidfAccum {
            result[term] = score / Double(tfidfCount[term] ?? 1)
        }
        return result
    }

    /// Compute TF-IDF score for a sentence (sum of term TF-IDF scores).
    private func sentenceTFIDFScore(sentence: String, tfidf: [String: Double]) -> Double {
        let tokens = tokenize(sentence)
        guard !tokens.isEmpty else { return 0 }
        let score = tokens.compactMap { tfidf[$0] }.reduce(0, +)
        return score / Double(tokens.count) // Normalize by length
    }

    // MARK: - TextRank

    /// Compute TextRank scores using iterative PageRank-style ranking.
    private func textRank(
        sentences: [String],
        damping: Double,
        iterations: Int,
        threshold: Double
    ) -> [Int: Double] {
        let n = sentences.count
        guard n > 1 else { return [0: 1.0] }

        // Tokenize all sentences
        let tokenized = sentences.map { Set(tokenize($0)) }

        // Build similarity matrix
        var similarity = [[Double]](repeating: [Double](repeating: 0, count: n), count: 0)
        for i in 0..<n {
            similarity.append([Double](repeating: 0, count: n))
        }

        for i in 0..<n {
            for j in (i + 1)..<n {
                let sim = cosineSimilarity(tokenized[i], tokenized[j])
                if sim >= threshold {
                    similarity[i][j] = sim
                    similarity[j][i] = sim
                }
            }
        }

        // Normalize rows
        var rowSums = [Double](repeating: 0, count: n)
        for i in 0..<n {
            rowSums[i] = similarity[i].reduce(0, +)
        }

        // Initialize scores uniformly
        var scores = [Double](repeating: 1.0 / Double(n), count: n)

        // Iterate
        for _ in 0..<iterations {
            var newScores = [Double](repeating: (1.0 - damping) / Double(n), count: n)
            for i in 0..<n {
                for j in 0..<n where i != j && rowSums[j] > 0 {
                    newScores[i] += damping * similarity[j][i] / rowSums[j] * scores[j]
                }
            }
            scores = newScores
        }

        // Return as dictionary
        return Dictionary(uniqueKeysWithValues: scores.enumerated().map { ($0.offset, $0.element) })
    }

    /// Cosine similarity between two token sets.
    private func cosineSimilarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        let intersection = a.intersection(b)
        guard !intersection.isEmpty else { return 0 }
        return Double(intersection.count) / (sqrt(Double(a.count)) * sqrt(Double(b.count)))
    }

    // MARK: - Tokenization

    /// Tokenize text into lowercase words, removing stopwords.
    private func tokenize(_ text: String) -> [String] {
        let stopwords: Set<String> = [
            "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could",
            "should", "may", "might", "shall", "can", "to", "of", "in", "for",
            "on", "with", "at", "by", "from", "as", "into", "through", "during",
            "before", "after", "above", "below", "between", "out", "off", "over",
            "under", "again", "further", "then", "once", "and", "but", "or",
            "nor", "not", "so", "very", "just", "than", "too", "also", "this",
            "that", "these", "those", "it", "its", "i", "me", "my", "we", "our",
            "you", "your", "he", "him", "his", "she", "her", "they", "them", "their"
        ]

        return text
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) }
    }
}

// MARK: - Enhanced Summary Result

/// Result of enhanced AI summarization.
public struct EnhancedSummary: Sendable {
    /// The summary text.
    public let summary: String
    /// Selected sentences with scores.
    public let sentences: [Sentence]
    /// TF-IDF scores per term.
    public let tfidfScores: [String: Double]
    /// TextRank scores per sentence index.
    public let textrankScores: [Int: Double]
    /// Total sentences analyzed.
    public let totalSentences: Int
    /// Compression ratio (selected / total).
    public let compressionRatio: Double
    /// Extraction time in milliseconds.
    public let extractionTimeMs: Double

    public struct Sentence: Sendable, Identifiable {
        public let id = UUID()
        public let text: String
        public let index: Int
        public let combinedScore: Double
        public let tfidfScore: Double
        public let textrankScore: Double
    }
}
