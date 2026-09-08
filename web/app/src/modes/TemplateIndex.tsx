/** Template Index Mode — indexes, matches, and benchmarks templates.
 * 
 * Bridges app.js template-index, template-match-benchmark, and
 * template-correction-benchmark workflows:
 * - Index template layouts from PDF documents
 * - Match new templates against existing index
 * - Run benchmark comparisons against corpus
 * - Display correction UI for mismatches
 */

import React, { useState, useEffect, useRef } from "react";
import { pdfPython } from "./pdf-python.mjs";
import { compareBrowserExportWithIndependentViewer } from "../benchmark/browser-export-independent-viewer-validator.mjs";
import { use } from "react";

export interface TemplateMatch {
  id: string;
  sourceDigest: string;
  matchScore: number;
  kind: "exact" | "partial" | "mismatch";
  details?: string;
}

export interface TemplateIndexProps {
  onSelect: (match: TemplateMatch) => void;
  onBenchmark: (fixturePath: string) => void;
  initialMatches?: TemplateMatch[];
}

export function TemplateIndex({
  onSelect,
  onBenchmark,
  initialMatches = [],
}: TemplateIndexProps) {
  const [matches, setMatches] = useState<TemplateMatch[]>(initialMatches);
  const [loading, setLoading] = useState<boolean>(false);
  const [selectedMatch, setSelectedMatch] = useState<TemplateMatch | null>(null);
  const [sourceDigest, setSourceDigest] = useState<string>("");
  const [fixturePath, setFixturePath] = useState<string>("/");

  // Load templates from a PDF document
  const loadTemplates = async (pdfPath: string) => {
    setLoading(true);
    try {
      // In a real implementation, this would use pdfPython/pikepdf to extract
      // template metadata from the PDF
      const templateMatches: TemplateMatch[] = [
        {
          id: "temp-1",
          sourceDigest: pdfPath,
          matchScore: 0.95,
          kind: "partial",
          details: "Template structure detected, partial field mapping",
        },
        {
          id: "temp-2",
          sourceDigest: pdfPath,
          matchScore: 0.78,
          kind: "mismatch",
          details: "Some fields could not be matched due to layout differences",
        },
      ];
      setMatches(templateMatches);
      setSourceDigest(pdfPath);
      setLoading(false);
    } catch (error) {
      console.error("Failed to load templates:", error);
      setLoading(false);
    }
  };

  // Run a benchmark comparison against a fixture
  const runBenchmark = (fixture: string) => {
    setFixturePath(fixture);
    onBenchmark(fixture);
  };

  // Select a match for further action
  const handleSelect = (match: TemplateMatch) => {
    setSelectedMatch(match);
    onSelect?.(match);
  };

  return (
    <div className="template-index-mode" style={{
      padding: "20px",
      border: "1px solid #ddd",
      borderRadius: "8px",
      maxWidth: "900px",
    }}>
      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "20px" }}>
        <h2>Template Index</h2>
        <button onClick={() => onBenchmark("/fixtures/template-benchmark.pdf")} style={{ padding: "8px 16px" }}>
          Run Benchmark
        </button>
      </header>

      <section style={{ marginBottom: "20px" }}>
        <h3>Template Matches ({matches.length})</h3>
        {matches.length === 0 ? (
          <p>No templates indexed. Use "Load Templates" to index a document.</p> : (
            <ul style={{ listStyle: "none", padding: 0, maxHeight: "300px", overflowY: "auto" }}>
              {matches.map((match) => (
                <li key={match.id} style={{ marginBottom: "12px", padding: "8px", border: "1px solid #ddd" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <span>
                      <strong>Score: {match.matchScore.toFixed(2)}</span>
                      <span style={{ color: "#666" }}>{match.kind}</span>
                    </span>
                    <span>{match.sourceDigest?.substring(0, 16) + "..."}</span>
                  </div>
                  <div style={{ flex: 1, marginLeft: "12px" }}>
                    <p style={{ margin: "4px 0" }}>{match.details || "No details"}</p>
                    <button
                      style={{
                        marginLeft: "8px",
                        cursor: "pointer",
                        fontSize: "12px",
                      }}
                      onClick={() => handleSelect(match)}
                    >
                      Select
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>

        {loading ? (
          <p>Indexing templates...</p> : (
            <section>
              <h3>Load Template Document</h3>
              <p>Index templates from a PDF document:</p>
              <div style={{ marginTop: "12px" }}>
                <button
                  style={{
                    padding: "8px 16px",
                    cursor: "pointer",
                    background: "#0066cc",
                    color: "white",
                  }}
                  onClick={() => loadTemplates("/fixtures/template-sample.pdf")}
                  >
                    Index Template Document
                  </button>
              </div>
            </section>
          )}
        </section>

        {selectedMatch && selectedMatch.kind !== "exact" ? (
          <section style={{ marginTop: "20px" }}>
            <h3>Mismatch Details</h3>
            <p><strong>Kind:</strong> {selectedMatch.kind}</p>
            <p><strong>Details:</strong> {selectedMatch.details || "No additional details"}</p>
            <button
              style={{
                padding: "8px 16px",
                marginTop: "8px",
                cursor: "pointer",
                background: "#e74c3c",
                color: "white",
              }}
              onClick={() => {
                setSelectedMatch(null);
              }}
            >
              Close
            </button>
          </section>
        ) : null}
      </section>

      <footer style={{ display: "flex", justifyContent: "flex-end", marginTop: "24px" }}>
        <button onClick={() => setSelectedMatch(null)} style={{ marginRight: "8px" }} padding="8px 16px">
          Deselect
        </button>
        <button style={{ padding: "8px 16px" }}>Close</button>
      </footer>
    </div>
  );
}