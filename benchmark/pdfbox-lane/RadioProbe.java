import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.TreeSet;

import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.interactive.form.PDAcroForm;
import org.apache.pdfbox.pdmodel.interactive.form.PDCheckBox;
import org.apache.pdfbox.pdmodel.interactive.form.PDChoice;
import org.apache.pdfbox.pdmodel.interactive.form.PDField;
import org.apache.pdfbox.pdmodel.interactive.form.PDRadioButton;
import org.apache.pdfbox.pdmodel.interactive.form.PDTextField;

/**
 * PDFBox control lane for the external-AcroForm preservation contract.
 * Args: <input.pdf> <output-dir>. Emits a JSON report on stdout.
 */
public final class RadioProbe {

    private static final String MUTATED_TEXT = "PDFBox lane";

    private RadioProbe() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("usage: RadioProbe <input.pdf> <output-dir>");
            System.exit(2);
        }
        File input = new File(args[0]);
        File outDir = new File(args[1]);
        if (!outDir.exists() && !outDir.mkdirs()) {
            System.err.println("cannot create output dir: " + outDir);
            System.exit(2);
        }

        String inputSha256 = sha256(input);

        int pagesInitial;
        LinkedHashMap<String, Map<String, String>> snapshotInitial;
        try (PDDocument doc = Loader.loadPDF(input)) {
            pagesInitial = doc.getNumberOfPages();
            snapshotInitial = inspect(doc);
        }

        List<String> fieldTypes = new ArrayList<>();
        Map<String, String> radioExportValues = new TreeMap<>();
        List<Map<String, Object>> fieldInventory = new ArrayList<>();
        for (Map.Entry<String, Map<String, String>> e : snapshotInitial.entrySet()) {
            String type = e.getValue().getOrDefault("type", "?");
            if (!fieldTypes.contains(type)) {
                fieldTypes.add(type);
            }
            if ("PDRadioButton".equals(type)) {
                radioExportValues.put(e.getKey(),
                        e.getValue().getOrDefault("exportValues", ""));
            }
            fieldInventory.add(inventoryEntry(e.getKey(), e.getValue()));
        }

        // No-op save: zero mutations between load and save.
        boolean noOpReopen = false;
        int pagesNoop = -1;
        LinkedHashMap<String, Map<String, String>> snapshotNoop =
                new LinkedHashMap<>();
        File noopPdf = new File(outDir, "noop.pdf");
        try (PDDocument doc = Loader.loadPDF(input)) {
            doc.save(noopPdf);
        }
        try (PDDocument doc = Loader.loadPDF(noopPdf)) {
            PDAcroForm acroForm = doc.getDocumentCatalog().getAcroForm();
            noOpReopen = acroForm != null;
            pagesNoop = doc.getNumberOfPages();
            snapshotNoop = inspect(doc);
        }
        boolean widgetStateEquivalent = noOpReopen
                && pagesNoop == pagesInitial
                && snapshotNoop.equals(snapshotInitial);
        List<Map<String, Object>> perFieldDiffs =
                diffSnapshots(snapshotInitial, snapshotNoop);

        // Mutated save: first text field gets a known value.
        boolean mutatedReopen = false;
        String mutatedFieldName = null;
        File mutatedPdf = new File(outDir, "mutated.pdf");
        try (PDDocument doc = Loader.loadPDF(input)) {
            PDAcroForm acroForm = doc.getDocumentCatalog().getAcroForm();
            if (acroForm != null) {
                for (PDField field : acroForm.getFieldTree()) {
                    if (field instanceof PDTextField) {
                        mutatedFieldName = field.getFullyQualifiedName();
                        ((PDTextField) field).setValue(MUTATED_TEXT);
                        break;
                    }
                }
            }
            if (mutatedFieldName != null) {
                doc.save(mutatedPdf);
            }
        }
        if (mutatedFieldName != null) {
            try (PDDocument doc = Loader.loadPDF(mutatedPdf)) {
                PDAcroForm acroForm = doc.getDocumentCatalog().getAcroForm();
                if (acroForm != null) {
                    PDField field = acroForm.getField(mutatedFieldName);
                    mutatedReopen = field instanceof PDTextField
                            && MUTATED_TEXT.equals(safeValueAsString(field));
                }
            }
        }

        String finalInputSha256 = sha256(input);
        boolean originalUnchanged = inputSha256.equals(finalInputSha256);
        String jarSha512 = System.getProperty("pdfbox.jar.sha512", "");

        StringBuilder json = new StringBuilder();
        json.append("{\n");
        json.append("  \"provider\" : \"PDFBox\",\n");
        json.append("  \"pdfboxVersion\" : ")
            .append(q(org.apache.pdfbox.util.Version.getVersion())).append(",\n");
        json.append("  \"inputSHA256\" : ").append(q(inputSha256)).append(",\n");
        json.append("  \"pages\" : ").append(pagesInitial).append(",\n");
        json.append("  \"fieldCount\" : ").append(snapshotInitial.size()).append(",\n");
        json.append("  \"fieldTypes\" : ").append(stringArray(fieldTypes)).append(",\n");
        json.append("  \"radioExportValues\" : ").append(objectOfStrings(radioExportValues))
            .append(",\n");
        json.append("  \"fieldInventory\" : ").append(listOfObjects(fieldInventory))
            .append(",\n");
        json.append("  \"noOpReopen\" : ").append(noOpReopen).append(",\n");
        json.append("  \"widgetStateEquivalent\" : ").append(widgetStateEquivalent)
            .append(",\n");
        json.append("  \"mutatedReopen\" : ").append(mutatedReopen).append(",\n");
        json.append("  \"originalUnchanged\" : ").append(originalUnchanged).append(",\n");
        json.append("  \"finalInputSHA256\" : ").append(q(finalInputSha256)).append(",\n");
        json.append("  \"jarSHA512\" : ").append(q(jarSha512)).append(",\n");
        json.append("  \"mutatedFieldName\" : ").append(q(mutatedFieldName == null ? ""
                : mutatedFieldName)).append(",\n");
        json.append("  \"perFieldDiffs\" : ").append(listOfObjects(perFieldDiffs))
            .append("\n");
        json.append("}\n");
        System.out.print(json);
    }

    private static LinkedHashMap<String, Map<String, String>> inspect(
            PDDocument doc) {
        LinkedHashMap<String, Map<String, String>> snapshot = new LinkedHashMap<>();
        PDAcroForm acroForm = doc.getDocumentCatalog().getAcroForm();
        if (acroForm == null) {
            return snapshot;
        }
        for (PDField field : acroForm.getFieldTree()) {
            Map<String, String> props = new TreeMap<>();
            String fqName = safe(() -> field.getFullyQualifiedName());
            props.put("type", typeName(field));
            props.put("valueAsString", safeValueAsString(field));
            if (field instanceof PDRadioButton) {
                PDRadioButton radio = (PDRadioButton) field;
                props.put("value", safe(radio::getValue));
                props.put("exportValues",
                        safeListJoin(radio.getExportValues()));
                props.put("onValues",
                        safeSetJoin(radio.getOnValues()));
                props.put("selectedExportValues",
                        safeListJoin(radio.getSelectedExportValues()));
            } else if (field instanceof PDCheckBox) {
                PDCheckBox box = (PDCheckBox) field;
                props.put("value", Boolean.toString(box.isChecked()));
                props.put("onValue", safe(box::getOnValue));
                props.put("exportValues",
                        safeListJoin(box.getExportValues()));
                props.put("onValues",
                        safeSetJoin(box.getOnValues()));
            } else if (field instanceof PDChoice) {
                PDChoice choice = (PDChoice) field;
                props.put("value",
                        safeListJoin(choice.getValue()));
                props.put("options",
                        safeListJoin(choice.getOptions()));
                props.put("optionsExportValues",
                        safeListJoin(choice.getOptionsExportValues()));
            } else if (field instanceof PDTextField) {
                PDTextField text = (PDTextField) field;
                props.put("value", safe(text::getValue));
            }
            snapshot.put(fqName, props);
        }
        return snapshot;
    }

    private static String typeName(PDField field) {
        if (field instanceof PDRadioButton) {
            return "PDRadioButton";
        }
        if (field instanceof PDCheckBox) {
            return "PDCheckBox";
        }
        if (field instanceof PDChoice) {
            return "PDChoice";
        }
        if (field instanceof PDTextField) {
            return "PDTextField";
        }
        return field.getClass().getSimpleName();
    }

    private static List<Map<String, Object>> diffSnapshots(
            Map<String, Map<String, String>> before,
            Map<String, Map<String, String>> after) {
        TreeSet<String> names = new TreeSet<>();
        names.addAll(before.keySet());
        names.addAll(after.keySet());
        List<Map<String, Object>> diffs = new ArrayList<>();
        for (String name : names) {
            Map<String, String> b =
                    before.getOrDefault(name, Collections.emptyMap());
            Map<String, String> a =
                    after.getOrDefault(name, Collections.emptyMap());
            TreeSet<String> props = new TreeSet<>();
            props.addAll(b.keySet());
            props.addAll(a.keySet());
            for (String prop : props) {
                String bv = b.get(prop);
                String av = a.get(prop);
                if (bv == null) {
                    bv = "<absent>";
                }
                if (av == null) {
                    av = "<absent>";
                }
                if (!bv.equals(av)) {
                    Map<String, Object> d = new LinkedHashMap<>();
                    d.put("field", name);
                    d.put("property", prop);
                    d.put("before", bv);
                    d.put("after", av);
                    diffs.add(d);
                }
            }
        }
        return diffs;
    }

    private static Map<String, Object> inventoryEntry(
            String fqName, Map<String, String> props) {
        Map<String, Object> entry = new LinkedHashMap<>();
        entry.put("fqName", fqName);
        entry.put("type", props.get("type"));
        for (String key : new String[] {
                "value", "valueAsString", "exportValues", "onValues",
                "selectedExportValues", "onValue", "options",
                "optionsExportValues"}) {
            if (props.containsKey(key)) {
                entry.put(key, props.get(key));
            }
        }
        return entry;
    }

    private interface SafeCall {
        String run() throws Exception;
    }

    private static String safe(SafeCall call) {
        try {
            String v = call.run();
            return v == null ? "<null>" : v;
        } catch (Exception e) {
            return "<error:" + e.getClass().getSimpleName() + ">";
        }
    }

    private static String safeValueAsString(PDField field) {
        try {
            String v = field.getValueAsString();
            return v == null ? "<null>" : v;
        } catch (Exception e) {
            return "<error:" + e.getClass().getSimpleName() + ">";
        }
    }

    private static String safeListJoin(List<String> values) {
        if (values == null) {
            return "<null>";
        }
        return String.join("|", values);
    }

    private static String safeSetJoin(java.util.Set<String> values) {
        if (values == null) {
            return "<null>";
        }
        TreeSet<String> sorted = new TreeSet<>(values);
        return String.join("|", sorted);
    }

    private static String sha256(File file) throws IOException {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = Files.readAllBytes(file.toPath());
            byte[] hash = digest.digest(bytes);
            StringBuilder hex = new StringBuilder();
            for (byte b : hash) {
                hex.append(String.format("%02x", b));
            }
            return hex.toString();
        } catch (IOException | RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private static String q(String s) {
        StringBuilder out = new StringBuilder("\"");
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"':
                    out.append("\\\"");
                    break;
                case '\\':
                    out.append("\\\\");
                    break;
                case '\b':
                    out.append("\\b");
                    break;
                case '\f':
                    out.append("\\f");
                    break;
                case '\n':
                    out.append("\\n");
                    break;
                case '\r':
                    out.append("\\r");
                    break;
                case '\t':
                    out.append("\\t");
                    break;
                default:
                    if (c < 0x20) {
                        out.append(String.format("\\u%04x", (int) c));
                    } else {
                        out.append(c);
                    }
            }
        }
        return out.append('"').toString();
    }

    private static String stringArray(List<String> items) {
        StringBuilder out = new StringBuilder("[");
        for (int i = 0; i < items.size(); i++) {
            if (i > 0) {
                out.append(", ");
            }
            out.append(q(items.get(i)));
        }
        return out.append(']').toString();
    }

    private static String objectOfStrings(Map<String, String> map) {
        StringBuilder out = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, String> e : map.entrySet()) {
            if (!first) {
                out.append(", ");
            }
            first = false;
            out.append(q(e.getKey())).append(" : ").append(q(e.getValue()));
        }
        return out.append('}').toString();
    }

    private static String listOfObjects(List<Map<String, Object>> entries) {
        StringBuilder out = new StringBuilder("[");
        for (int i = 0; i < entries.size(); i++) {
            if (i > 0) {
                out.append(", ");
            }
            out.append('{');
            boolean first = true;
            for (Map.Entry<String, Object> e : entries.get(i).entrySet()) {
                if (!first) {
                    out.append(", ");
                }
                first = false;
                out.append(q(e.getKey())).append(" : ");
                Object v = e.getValue();
                out.append(v instanceof Number ? v.toString() : q(String.valueOf(v)));
            }
            out.append('}');
        }
        return out.append(']').toString();
    }
}
