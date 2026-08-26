import { useEffect, useRef, useState } from "react";
import type { NativeField } from "../pdf/PdfController";

interface CompleteWorkbenchProps {
  fields: NativeField[];
  onConfirmEdit(field: NativeField, value: string): void;
  canUndo: boolean;
  onUndo(): void;
}

const KIND_LABELS: Record<NativeField["kind"], string> = {
  text: "Text",
  checkbox: "Checkbox",
  radio: "Radio",
  choice: "Choice",
  other: "Other"
};

export function CompleteWorkbench({
  fields,
  onConfirmEdit,
  canUndo,
  onUndo
}: CompleteWorkbenchProps) {
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const syncedValues = useRef<Record<string, string>>({});

  useEffect(() => {
    setDrafts((current) => {
      const next = { ...current };
      for (const field of fields) {
        // A value change that did not originate from this editor (undo,
        // reload) must replace any stale local draft.
        if (next[field.id] === undefined || syncedValues.current[field.id] !== field.value) {
          next[field.id] = field.value;
        }
        syncedValues.current[field.id] = field.value;
      }
      return next;
    });
  }, [fields]);

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
                value={drafts[field.id] ?? field.value}
                onChange={(event) =>
                  setDrafts((d) => ({ ...d, [field.id]: event.target.value }))
                }
              >
                <option value="">Unchecked</option>
                <option value={field.value || "Yes"}>Checked</option>
              </select>
            ) : (
              <input
                className="field-input"
                type="text"
                value={drafts[field.id] ?? field.value}
                onChange={(event) =>
                  setDrafts((d) => ({ ...d, [field.id]: event.target.value }))
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
              const draft = drafts[field.id] ?? "";
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
        onto a new copy — this source stays read-only.
      </p>
    </>
  );
}
