#!/usr/bin/env node
// pdf-lib AcroForm lane — a genuinely independent provider for the
// cross-provider AcroForm parity experiment.
//
// pdf-lib is a pure-JS PDF implementation with its own AcroForm model. Using
// it (rather than relabeling PDFKit calls) makes the experiment's
// "PDF.js/qpdf" claims *measured* against an engine that shares no code with
// the native PDFKit path.
//
// Subcommands (JSON on stdout; exit 0 on success):
//   lane.mjs inspect <input.pdf>
//       -> { engine, pdfLibVersion, fields: [{ name, type, value, options }] }
//          type: radio | checkbox | choice | text
//   lane.mjs write <input.pdf> <output.pdf> <spec.json>
//       spec.json: [{ name, type, value }]  (value semantics per type)
//       -> { applied: [{ name, type, value, ok, error }] }
//   lane.mjs read <input.pdf>
//       same shape as inspect
//
// Value semantics (mirroring the PDFKit lane's conventions):
//   radio    value = export value to select ("0"/"1"/"Yes"/...). The sibling
//            kid instances are cleared first so a switch deselects the old
//            option.
//   checkbox value = "Yes" (check) or "Off" (uncheck)
//   choice   value = option string to select
//   choice_multi value = JSON array of option strings (multi-select /Ff 22)
//   text     value = string to write

import { PDFDocument } from "pdf-lib";
import fs from "fs";

function fail(message, extra = {}) {
  process.stdout.write(JSON.stringify({ ok: false, error: message, ...extra }));
  process.exit(1);
}

function fieldValueOf(ctor, instance) {
  try {
    if (ctor === "PDFTextField") return instance.getText() ?? null;
    if (ctor === "PDFCheckBox") {
      // Report the field's REAL on-token, not a hardcoded "Yes" — the
      // corpus carries On/Checked/1/Y vocabularies and callers compare
      // against structural /V values (Falsified 2026-09-06: the "Yes"/"Off"
      // projection mis-typed every non-Yes token as a read failure).
      return instance.isChecked()
        ? (instance.acroField.getOnValue()?.asString?.().replace(/^\//, "") ?? "Yes")
        : "Off";
    }
    if (ctor === "PDFDropdown" || ctor === "PDFOptionList") {
      const sel = instance.getSelected();
      return sel && sel.length ? sel[0] : null;
    }
    if (ctor === "PDFRadioGroup") return instance.getSelected() ?? null;
  } catch {
    return null;
  }
  return null;
}

function typeOf(ctor) {
  if (ctor === "PDFRadioGroup") return "radio";
  if (ctor === "PDFCheckBox") return "checkbox";
  // pdf-lib maps /FT /Ch to PDFDropdown when the /Ff combo bit (18) is set
  // and to PDFOptionList otherwise. Both are choice fields for parity
  // purposes — listboxes carry the same /Opt vocabulary.
  if (ctor === "PDFDropdown" || ctor === "PDFOptionList") return "choice";
  if (ctor === "PDFTextField") return "text";
  return null;
}

/** Aggregate fields: pdf-lib models flattened radio kids as separate group
 * instances sharing one name — merge them into a single radio group entry so
 * callers see the union of export options and any selection. */
function aggregate(raw) {
  const byKey = new Map();
  for (const f of raw) {
    const key = `${f.type}:${f.name}`;
    if (!byKey.has(key)) byKey.set(key, { ...f });
    const agg = byKey.get(key);
    if (f.type === "radio") {
      agg.options = [...new Set([...(agg.options ?? []), ...(f.options ?? [])])];
      if (f.value != null) agg.value = f.value;
    }
  }
  return [...byKey.values()].filter((f) => f.type != null);
}

function inspectFields(doc) {
  const form = doc.getForm();
  const raw = [];
  for (const f of form.getFields()) {
    const ctor = f.constructor.name;
    const type = typeOf(ctor);
    if (!type) continue;
    const entry = { name: f.getName(), type };
    if (type === "radio") {
      const opts = f.getOptions();
      entry.options = opts ?? [];
      entry.value = fieldValueOf(ctor, f);
    } else if (type === "checkbox") {
      entry.value = fieldValueOf(ctor, f);
    } else if (type === "choice") {
      try {
        const dd = f;
        entry.options = [...new Set((dd.getOptions() ?? []).map((o) =>
          typeof o === "string" ? o : o[0]))];
      } catch {
        entry.options = [];
      }
      entry.value = fieldValueOf(ctor, f);
      // Multi-select listboxes carry an ARRAY /V (§12.7.5.4 bit 22); expose
      // the full selection so callers can verify multi-selections. Single
      // selects report a 1-element array (shape still observable).
      if (ctor === "PDFOptionList" || ctor === "PDFDropdown") {
        try { entry.values = f.getSelected() ?? []; } catch { entry.values = []; }
      }
    } else {
      entry.value = fieldValueOf(ctor, f);
    }
    raw.push(entry);
  }
  return aggregate(raw);
}

async function load(inputPath) {
  const bytes = fs.readFileSync(inputPath);
  const doc = await PDFDocument.load(bytes, { updateMetadata: false });
  return { doc, bytes };
}

const [, , sub, inputPath, outputPath, specPath] = process.argv;

if (sub === "inspect" || sub === "read") {
  try {
    const { doc } = await load(inputPath);
    const fields = inspectFields(doc);
    const pdfLibVersion = doc.context ? "1.17.1" : "1.17.1";
    process.stdout.write(JSON.stringify({
      ok: true,
      engine: "pdf-lib",
      pdfLibVersion,
      fieldCount: fields.length,
      fields,
    }));
  } catch (e) {
    fail(e?.message ?? String(e));
  }
} else if (sub === "write") {
  let spec;
  try {
    spec = JSON.parse(fs.readFileSync(specPath, "utf8"));
  } catch (e) {
    fail(`cannot read spec: ${e.message}`);
  }
  if (!Array.isArray(spec)) fail("spec must be an array");
  try {
    const { doc } = await load(inputPath);
    const form = doc.getForm();
    const applied = [];
    // Snapshot of radio instances per name so a switch can clear siblings.
    const radioInstances = new Map();
    for (const f of form.getFields()) {
      if (f.constructor.name === "PDFRadioGroup") {
        const n = f.getName();
        if (!radioInstances.has(n)) radioInstances.set(n, []);
        radioInstances.get(n).push(f);
      }
    }
    for (const item of spec) {
      const { name, type, value } = item;
      try {
        if (type === "radio") {
          const instances = radioInstances.get(name) ?? [];
          if (!instances.length) {
            applied.push({ name, type, value, ok: false, error: "radio group not found" });
            continue;
          }
          const target = instances.find((i) =>
            (i.getOptions() ?? []).includes(value));
          if (!target) {
            applied.push({ name, type, value, ok: false, error: `no widget with export value '${value}'` });
            continue;
          }
          for (const inst of instances) {
            if (inst !== target) {
              try { inst.clear(); } catch { /* best effort */ }
            }
          }
          target.select(value);
          applied.push({ name, type, value, ok: true });
        } else if (type === "checkbox") {
          const cb = form.getCheckBox(name);
          if (value === "Off") {
            cb.uncheck();
          } else {
            // cb.check() applies the field's REAL on-token — pdf-lib's
            // PDFCheckBox.check() resolves acroField.getOnValue() (falling
            // back to /Yes only when absent). Falsified 2026-09-06: the old
            // `value === "Yes" ? cb.check() : cb.uncheck()` treated any
            // non-Yes target (On/Checked/1/Y) as an uncheck request, so the
            // lane silently deselected boxes and reported 6 phantom
            // checkbox failures on the pikepdf-generated corpus.
            cb.check();
          }
          applied.push({ name, type, value, ok: true });
        } else if (type === "choice") {
          // pdf-lib exposes /Ch fields as dropdowns (combo bit set) or
          // option lists (listbox) — try both before giving up.
          let dd = null;
          try { dd = form.getDropdown(name); } catch { /* not a combo */ }
          if (!dd) dd = form.getOptionList(name);
          dd.select(value);
          applied.push({ name, type, value, ok: true });
        } else if (type === "choice_multi") {
          // MULTI-SELECT listbox write. `value` is a JSON-encoded array of
          // option strings (JSON, not a separator, so options containing
          // commas stay representable). pdf-lib's PDFOptionList.select(
          // array) enables /Ff bit 22 automatically and setValues writes
          // array /V + sorted /I for >1 selections (measured on
          // PDFAcroChoice.setValues / updateSelectedIndices).
          let selections;
          try { selections = JSON.parse(value); } catch {
            applied.push({ name, type, value, ok: false, error: "choice_multi value must be a JSON array" });
            continue;
          }
          if (!Array.isArray(selections)) {
            applied.push({ name, type, value, ok: false, error: "choice_multi value must decode to an array" });
            continue;
          }
          let ol = null;
          try { ol = form.getOptionList(name); } catch { /* listbox */ }
          if (!ol) {
            try { ol = form.getDropdown(name); } catch { /* dropdown */ }
          }
          if (!ol) {
            applied.push({ name, type, value, ok: false, error: "no choice field found" });
            continue;
          }
          if (selections.length) {
            ol.select(selections, false);
          } else {
            // Empty selection deletes /V (measured: PDFAcroChoice.setValues
            // with 0 values deletes the key) — pdf-lib's clear() path.
            ol.clear();
          }
          applied.push({ name, type, value, ok: true });
        } else if (type === "text") {
          const tf = form.getTextField(name);
          tf.setText(value ?? "");
          applied.push({ name, type, value, ok: true });
        } else {
          applied.push({ name, type, value, ok: false, error: `unsupported type ${type}` });
        }
      } catch (e) {
        applied.push({ name, type, value, ok: false, error: e?.message ?? String(e) });
      }
    }
    const out = await doc.save({ useObjectStreams: false });
    fs.writeFileSync(outputPath, out);
    process.stdout.write(JSON.stringify({ ok: true, engine: "pdf-lib", applied }));
  } catch (e) {
    fail(e?.message ?? String(e));
  }
} else {
  fail(`unknown subcommand '${sub}' (expected inspect|write|read)`);
}
