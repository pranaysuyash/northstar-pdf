/** Template Review Mode — captures, reviews, and revises template mappings.
 *
 * Bridges the app.js `renderTemplateReview` workflow (2307-2512):
 * - Layout capture via pointer events
 * - Mapping edits with per-member validation
 * - Review UI with confirm/dismiss actions
 * - Validated template revision generation
 *
 * NOTE: unwired scaffold. No mode currently mounts this component, signature
 * and calibration imports target modules outside the React tree, and the
 * validation action is a placeholder. Implement or retire by owner decision —
 * see the ready-game decision pack before building on this.
 */

import { useState } from "react";

export interface TemplateMapping {
  id: string;
  type: "text" | "checkbox" | "radio" | "signature";
  bounds: { x: number; y: number; width: number; height: number };
  value?: string;
  evidence?: {
    confidence: number;
    label?: string;
  };
}

export interface TemplateReviewProps {
  onSave: (mappings: TemplateMapping[]) => void;
  onCancel: () => void;
  initialMappings?: TemplateMapping[];
  documentDigest?: string;
}

export function TemplateReview({
  onSave,
  onCancel,
  initialMappings = [],
}: TemplateReviewProps) {
  const [mappings, setMappings] = useState<TemplateMapping[]>(initialMappings);
  const [currentEdit, setCurrentEdit] = useState<TemplateMapping | null>(null);
  const [mode, setMode] = useState<"capture" | "review">("capture");

  // Save changes to a mapping
  const saveEdit = () => {
    if (!currentEdit) return;
    setMappings(
      mappings.map((m) => (m.id === currentEdit.id ? currentEdit : m))
    );
    setCurrentEdit(null);
    setMode("capture");
    onSave?.(mappings);
  };

  // Cancel editing
  const cancelEdit = () => {
    setCurrentEdit(null);
    setMode("capture");
  };

  // Add a new mapping
  const addMapping = (mapping: Omit<TemplateMapping, "id">) => {
    const newMapping: TemplateMapping = {
      ...mapping,
      id: `temp-${Date.now()}-${Math.random().toString(36).slice(2)}`,
    };
    setMappings([...mappings, newMapping]);
  };

  // Remove a mapping
  const removeMapping = (id: string) => {
    setMappings(mappings.filter((m) => m.id !== id));
  };

  // Save the template review state
  const handleSave = () => {
    onSave?.(mappings);
    onCancel();
  };

  return (
    <div className="template-review-mode" style={{
      padding: "20px",
      border: "1px solid #ddd",
      borderRadius: "8px",
      maxWidth: "800px",
    }}>
      <header style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "20px" }}>
        <h2>Template Review</h2>
        <button onClick={onCancel} style={{ padding: "8px 16px" }}>Cancel</button>
      </header>

      <section style={{ marginBottom: "20px" }}>
        <h3>Current Mappings ({mappings.length})</h3>
        {mappings.length === 0 ? (
          <p>No mappings defined. Use capture mode to add.</p>
        ) : (
          <ul style={{ listStyle: "none", padding: 0 }}>
            {mappings.map((m) => (
              <li key={m.id} style={{ marginBottom: "8px", paddingBottom: "4px", borderBottom: "1px solid #eee" }}>
                <strong>{m.type}</strong> at ({m.bounds.x}, {m.bounds.y}) - {m.bounds.width}x{m.bounds.height}
                {m.evidence ? ` • Confidence: ${m.evidence.confidence}` : ""}
                {m.value ? ` • Value: ${m.value}` : ""}
                <button
                  style={{ marginLeft: "12px", cursor: "pointer" }}
                  onClick={() => removeMapping(m.id)}
                >
                  Remove
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      {mode === "capture" ? (
        <section>
          <h3>Capture New Mapping</h3>
          <p>Draw a region or select a template element:</p>
          <div>
            <button
              style={{
                padding: "8px 16px",
                marginBottom: "8px",
                cursor: "pointer",
              }}
              onClick={() => setMode("review")}
            >
              Switch to Review Mode
            </button>
            <button
              style={{
                padding: "8px 16px",
                cursor: "pointer",
                background: "#0066cc",
                color: "white",
              }}
              onClick={() =>
                addMapping({
                  type: "text",
                  bounds: { x: 100, y: 100, width: 200, height: 32 },
                })
              }
            >
              Add Text Field
            </button>
          </div>
        </section>
      ) : (
        <section>
          <h3>Review Mapping</h3>
          <p>Edit the selected mapping:</p>
          {currentEdit ? (
            <div>
              <label>
                Type:
                <select
                  value={currentEdit.type}
                  onChange={(e) => {
                    setCurrentEdit({ ...currentEdit, type: e.target.value as TemplateMapping["type"] });
                  }}
                >
                  <option value="text">Text</option>
                  <option value="checkbox">Checkbox</option>
                  <option value="radio">Radio</option>
                  <option value="signature">Signature</option>
                </select>
              </label>
              <label>
                Bounds X:
                <input
                  value={currentEdit.bounds.x}
                  onChange={(e) => {
                    setCurrentEdit({
                      ...currentEdit,
                      bounds: { x: Number(e.target.value), y: currentEdit.bounds.y, width: currentEdit.bounds.width, height: currentEdit.bounds.height },
                    });
                  }}
                />
              </label>
              <label>
                Bounds Y:
                <input
                  value={currentEdit.bounds.y}
                  onChange={(e) => {
                    setCurrentEdit({
                      ...currentEdit,
                      bounds: { x: currentEdit.bounds.x, y: Number(e.target.value), width: currentEdit.bounds.width, height: currentEdit.bounds.height },
                    });
                  }}
                />
              </label>
              <label>
                Value:
                <input
                  value={currentEdit.value || ""}
                  onChange={(e) => {
                    setCurrentEdit({ ...currentEdit, value: e.target.value });
                  }}
                />
              </label>
              <div style={{ marginTop: "12px" }}>
                <button onClick={saveEdit} style={{ marginRight: "8px", padding: "4px 8px" }}>
                  Save
                </button>
                <button onClick={cancelEdit} style={{ padding: "4px 8px" }}>Cancel</button>
              </div>
            </div>
          ) : (
            <p>Select a mapping from the list above to edit.</p>
          )}
        </section>
      )}

      <section>
        <h3>Evidence &amp; Validation</h3>
        <p>Template mappings should be validated against the document source.</p>
        <button
          style={{
            padding: "8px 16px",
            marginTop: "12px",
            cursor: "pointer",
          }}
          onClick={() => {
            // Placeholder for validation logic
            alert("Validation would run here against pdfPython/pikepdf");
          }}
        >
          Validate Mappings
        </button>
      </section>

      <footer style={{ display: "flex", justifyContent: "flex-end", marginTop: "24px" }}>
        <button onClick={handleSave} style={{ marginRight: "8px", padding: "8px 16px" }}>
          Save Template
        </button>
        <button onClick={onCancel} style={{ padding: "8px 16px" }}>Cancel</button>
      </footer>
    </div>
  );
}
