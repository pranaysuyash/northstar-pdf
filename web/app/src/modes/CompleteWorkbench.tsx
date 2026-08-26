import { useState } from "react";
import type { GeometryCandidate, NativeField, Rect } from "../pdf/PdfController";

interface CompleteWorkbenchProps {
  fields: NativeField[];
  onConfirmEdit(field: NativeField, value: string): void;
  canUndo: boolean;
  onUndo(): void;
  candidates: GeometryCandidate[];
  candidatesLoading: boolean;
  dismissedIDs: ReadonlySet<string>;
  onDismissCandidate(id: string): void;
  pendingPlacement: { pageIndex: number; rect: Rect } | null;
  onConfirmPlacement(value: string): void;
  onCancelPlacement(): void;
  onProposePlacement(placement: { pageIndex: number; rect: Rect }): void;
}

const KIND_LABELS: Record<NativeField["kind"], string> = {
  text: "Text",
  checkbox: "Checkbox",
  radio: "Radio",
  choice: "Choice",
  other: "Other"
};

/**
 * A draft is valid only against the authoritative value it was typed on.
 * When the field's confirmed value moves (undo, reload), the base no longer
 * matches and the stale draft is discarded by derivation — no effects needed.
 */
interface FieldDraft {
  readonly baseValue: string;
  readonly value: string;
}

export function CompleteWorkbench({
  fields,
  onConfirmEdit,
  canUndo,
  onUndo,
  candidates,
  candidatesLoading,
  dismissedIDs,
  onDismissCandidate,
  pendingPlacement,
  onConfirmPlacement,
  onCancelPlacement,
  onProposePlacement
}: CompleteWorkbenchProps) {
  const [drafts, setDrafts] = useState<Record<string, FieldDraft>>({});
  const [placementValue, setPlacementValue] = useState("");

  const shownValue = (field: NativeField): string => {
    const draft = drafts[field.id];
    return draft && draft.baseValue === field.value ? draft.value : field.value;
  };

  if (!fields.length) {
    return (
      <>
        <div className="list-title">Native fields</div>
        <div className="small muted">
          No AcroForm widgets found. Geometry-detected candidate regions connect through a later
          adapter slice; nothing is inferred silently.
        </div>
      </>
    );
  }

  return (
    <>
      {pendingPlacement && (
        <div className="review-card" data-testid="placement-card">
          <h3>Manual text placement</h3>
          <p className="small muted">
            Authorized region on page {pendingPlacement.pageIndex + 1} —{" "}
            {pendingPlacement.rect.width.toFixed(0)}×{pendingPlacement.rect.height.toFixed(0)}pt.
            The text must fit inside it at export time.
          </p>
          <input
            className="field-input"
            type="text"
            value={placementValue}
            placeholder="Text to place in this region"
            aria-label="Overlay text value"
            onChange={(event) => setPlacementValue(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter" && placementValue.trim()) {
                onConfirmPlacement(placementValue.trim());
                setPlacementValue("");
              }
            }}
          />
          <div className="review-actions" style={{ marginTop: 8 }}>
            <button
              type="button"
              className="primary"
              disabled={!placementValue.trim()}
              onClick={() => {
                onConfirmPlacement(placementValue.trim());
                setPlacementValue("");
              }}
            >
              Confirm placement
            </button>
            <button
              type="button"
              onClick={() => {
                onCancelPlacement();
                setPlacementValue("");
              }}
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      <div className="list-title">Native fields ({fields.length})</div>
      <div className="small completion-list">
        {fields.map((field) => (
          <label key={field.id} className="field-row" style={{ display: "block", marginBlock: 8 }}>
            <span className="small">
              <strong>{field.name}</strong>{" "}
              <span className="muted">· p{field.pageIndex + 1} · {KIND_LABELS[field.kind]}</span>
            </span>
            {field.kind === "checkbox" || field.kind === "radio" ? (
              <select
                className="field-input"
                value={shownValue(field)}
                onChange={(event) =>
                  setDrafts((d) => ({
                    ...d,
                    [field.id]: { baseValue: field.value, value: event.target.value }
                  }))
                }
              >
                <option value="">Unchecked</option>
                <option value={field.value || "Yes"}>Checked</option>
              </select>
            ) : (
              <input
                className="field-input"
                type="text"
                value={shownValue(field)}
                onChange={(event) =>
                  setDrafts((d) => ({
                    ...d,
                    [field.id]: { baseValue: field.value, value: event.target.value }
                  }))
                }
                aria-label={`Value for ${field.name}`}
              />
            )}
          </label>
        ))}
      </div>
      <div className="inline" style={{ marginTop: 10 }}>
        <button
          type="button"
          className="primary"
          onClick={() => {
            for (const field of fields) {
              const draft = shownValue(field);
              if (draft !== field.value) onConfirmEdit(field, draft);
            }
          }}
        >
          Confirm changes
        </button>
        <button type="button" disabled={!canUndo} onClick={onUndo}>
          Undo last
        </button>
      </div>
      <p className="small muted" style={{ marginTop: 8 }}>
        Confirmed changes enter the reversible operation log. Bytes are written only at export,
        onto a new copy; this source stays read-only.
      </p>

      <div className="list-title" style={{ marginTop: 14 }}>
        Detected entry regions{candidates.length ? ` (page ${(candidates[0].pageIndex ?? 0) + 1})` : ""}
      </div>
      {candidatesLoading && <div className="small muted">Reading page geometry…</div>}
      {!candidatesLoading && candidates.length === 0 && (
        <div className="small muted">
          No geometry candidates on this page. Findings stay review-only; nothing is applied
          without explicit confirmation.
        </div>
      )}
      <div className="completion-list small">
        {candidates.map((candidate) => (
          <div key={candidate.id} className="review-card candidate-card" style={{ marginTop: 8 }}>
            <strong>{candidate.displayName || candidate.labelText || "Unlabeled region"}</strong>{" "}
            <span className="muted">
              · {candidate.suggestedFieldType ?? "region"} · score {candidate.score.toFixed(2)}
            </span>
            {candidate.evidence.slice(0, 3).map((line, i) => (
              <p key={i} className="small muted" style={{ margin: "4px 0 0" }}>
                {line}
              </p>
            ))}
            <div className="review-actions" style={{ marginTop: 6 }}>
              <button
                type="button"
                onClick={() =>
                  onProposePlacement({
                    pageIndex: candidate.pageIndex,
                    rect: candidate.bounds
                  })
                }
              >
                Place text here
              </button>
              <button type="button" onClick={() => onDismissCandidate(candidate.id)}>
                Dismiss
              </button>
            </div>
          </div>
        ))}
        {!candidatesLoading && dismissedIDs.size > 0 && (
          <p className="small muted">{dismissedIDs.size} dismissed finding(s) hidden this session.</p>
        )}
      </div>
    </>
  );
}
