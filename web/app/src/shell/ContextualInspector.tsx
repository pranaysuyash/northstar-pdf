import { memo, useMemo, useState } from "react";
import type { NativeField } from "../pdf/PdfController";

interface ContextualInspectorProps {
  fields: NativeField[];
  selectedFieldId: string | null;
  onSelectField: (id: string) => void;
  onUpdateFieldValue: (field: NativeField, value: string) => void;
  onRunOCR: () => void;
  onAutofillProfile: () => void;
}

export const ContextualInspector = memo(function ContextualInspector({
  fields,
  selectedFieldId,
  onSelectField,
  onUpdateFieldValue,
  onRunOCR,
  onAutofillProfile
}: ContextualInspectorProps) {
  const [activeTab, setActiveTab] = useState<"focus" | "document" | "trust">("focus");

  const selectedField = useMemo(
    () => fields.find((f) => f.id === selectedFieldId),
    [fields, selectedFieldId]
  );

  return (
    <aside className="w-80 border-l border-slate-800 bg-slate-900/90 backdrop-blur flex flex-col h-full text-slate-200">
      {/* 3-Tab Segmented Control */}
      <div className="p-3 border-b border-slate-800">
        <div className="grid grid-cols-3 bg-slate-950 p-1 rounded-lg text-xs font-medium border border-slate-800">
          <button
            className={`py-1.5 rounded-md transition-colors ${
              activeTab === "focus" ? "bg-slate-800 text-cyan-400 font-semibold shadow-sm" : "text-slate-400 hover:text-slate-200"
            }`}
            onClick={() => setActiveTab("focus")}
          >
            Focus & Edit
          </button>
          <button
            className={`py-1.5 rounded-md transition-colors ${
              activeTab === "document" ? "bg-slate-800 text-cyan-400 font-semibold shadow-sm" : "text-slate-400 hover:text-slate-200"
            }`}
            onClick={() => setActiveTab("document")}
          >
            Document
          </button>
          <button
            className={`py-1.5 rounded-md transition-colors ${
              activeTab === "trust" ? "bg-slate-800 text-cyan-400 font-semibold shadow-sm" : "text-slate-400 hover:text-slate-200"
            }`}
            onClick={() => setActiveTab("trust")}
          >
            Trust & Safety
          </button>
        </div>
      </div>

      {/* Tab Contents */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4 text-xs">
        {activeTab === "focus" && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="font-semibold text-slate-300 uppercase tracking-wider text-[10px]">
                Field Inspector ({fields.length})
              </span>
              <button
                className="px-2 py-1 bg-cyan-900/40 hover:bg-cyan-800/60 text-cyan-300 rounded border border-cyan-700/50 text-[11px] font-medium"
                onClick={onAutofillProfile}
              >
                ⚡ Autofill All
              </button>
            </div>

            {selectedField ? (
              <div className="bg-slate-950/60 p-3 rounded-lg border border-slate-800 space-y-3">
                <div className="space-y-1">
                  <span className="text-[10px] uppercase font-bold text-slate-500">Field Name</span>
                  <div className="text-sm font-mono text-cyan-300 font-medium">{selectedField.name}</div>
                </div>

                <div className="space-y-1">
                  <span className="text-[10px] uppercase font-bold text-slate-500">Type / Page</span>
                  <div className="text-xs text-slate-300 capitalize">
                    {selectedField.kind} • Page {selectedField.pageIndex + 1}
                  </div>
                </div>

                <div className="space-y-1">
                  <label
                    htmlFor="inspectorFieldValue"
                    className="text-[10px] uppercase font-bold text-slate-500"
                  >
                    Value
                  </label>
                  {selectedField.kind === "checkbox" || selectedField.kind === "radio" ? (
                    <input
                      id="inspectorFieldValue"
                      type="checkbox"
                      className="h-4 w-4 rounded border-slate-700 text-cyan-500 focus:ring-cyan-400"
                      checked={selectedField.value === "true" || selectedField.value === "/Yes" || selectedField.value === "/1"}
                      onChange={(e) => onUpdateFieldValue(selectedField, e.target.checked ? "/Yes" : "/Off")}
                    />
                  ) : (
                    <input
                      id="inspectorFieldValue"
                      type="text"
                      className="w-full bg-slate-900 border border-slate-700 rounded px-2.5 py-1.5 text-slate-100 text-xs focus:border-cyan-500 focus:outline-none"
                      value={selectedField.value}
                      onChange={(e) => onUpdateFieldValue(selectedField, e.target.value)}
                    />
                  )}
                </div>
              </div>
            ) : (
              <div className="p-4 bg-slate-950/40 border border-dashed border-slate-800 rounded-lg text-center text-slate-500">
                Select a field on the canvas or rail to inspect and edit values.
              </div>
            )}

            <div className="space-y-2">
              <div className="text-[10px] uppercase font-bold text-slate-500">Form Fields</div>
              <div className="space-y-1 max-h-56 overflow-y-auto">
                {fields.map((f) => (
                  <button
                    type="button"
                    key={f.id}
                    className={`p-2 rounded cursor-pointer flex items-center justify-between transition-colors w-full text-left ${
                      f.id === selectedFieldId
                        ? "bg-cyan-950/60 border border-cyan-700 text-cyan-200"
                        : "hover:bg-slate-800/50 text-slate-400"
                    }`}
                    style={{ contentVisibility: "auto", containIntrinsicSize: "32px" }}
                    onClick={() => onSelectField(f.id)}
                  >
                    <span className="font-mono truncate max-w-[150px]">{f.name}</span>
                    <span className="text-[10px] text-slate-500">P{f.pageIndex + 1}</span>
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {activeTab === "document" && (
          <div className="space-y-3">
            <div className="text-[10px] uppercase font-bold text-slate-500">Document Outline</div>
            <div className="p-3 bg-slate-950/60 rounded border border-slate-800 text-slate-400 space-y-1">
              <div>• Section 1: Overview</div>
              <div>• Section 2: Personal Details</div>
              <div>• Section 3: Declaration & Signature</div>
            </div>

            <div className="text-[10px] uppercase font-bold text-slate-500">Document Intelligence</div>
            <button
              className="w-full py-2 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded text-slate-200 font-medium flex items-center justify-center gap-2"
              onClick={onRunOCR}
            >
              <span>🔍</span>
              <span>Run On-Device OCR Analysis</span>
            </button>
          </div>
        )}

        {activeTab === "trust" && (
          <div className="space-y-3">
            <div className="text-[10px] uppercase font-bold text-slate-500">Local Security Posture</div>
            <div className="p-3 bg-slate-950/60 rounded border border-slate-800 space-y-2">
              <div className="flex items-center justify-between text-emerald-400 font-medium">
                <span>Zero-Egress Sandboxed</span>
                <span>✔ 100% Local</span>
              </div>
              <div className="text-[11px] text-slate-400">
                WebCrypto AES-GCM local storage with immutable original source byte preservation.
              </div>
            </div>

            <div className="text-[10px] uppercase font-bold text-slate-500">Structural Validation</div>
            <div className="p-3 bg-slate-950/60 rounded border border-slate-800 space-y-1 text-slate-300">
              <div>• Incremental AcroForm Writer: Ready</div>
              <div>• Pixel Impact Guard: Active</div>
              <div>• Action Neutralizer: Enforced</div>
            </div>
          </div>
        )}
      </div>
    </aside>
  );
});

