import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import java.util.TreeSet;

import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.encryption.InvalidPasswordException;
import org.apache.pdfbox.pdmodel.interactive.form.PDAcroForm;
import org.apache.pdfbox.pdmodel.interactive.form.PDCheckBox;
import org.apache.pdfbox.pdmodel.interactive.form.PDChoice;
import org.apache.pdfbox.pdmodel.interactive.form.PDField;
import org.apache.pdfbox.pdmodel.interactive.form.PDRadioButton;
import org.apache.pdfbox.pdmodel.interactive.form.PDTextField;
import org.apache.pdfbox.rendering.ImageType;
import org.apache.pdfbox.rendering.PDFRenderer;

/**
 * PDFBox control lane for the external-AcroForm preservation contract.
 *
 * Usage: RadioProbe [--no-mutate] [--raster] <input.pdf> <output-dir>
 *
 * Bare <input.pdf> <output-dir> keeps the historical behavior: full oracle
 * incl. a mutated-save round trip. Optional flags:
 *   --no-mutate  skip the mutated-save phase (fixtures where mutation is
 *                not applicable, e.g. encrypted or field-less documents)
 *   --raster     render page 1 of input and of the no-op output at scale
 *                1.0 and report rasterAE (absolute differing-pixel count)
 *                and rasterMeanDelta (mean absolute per-channel delta)
 *
 * Emits a JSON report on stdout. Encrypted inputs that cannot be opened
 * without a password produce an explicit encryptedUnsupported report
 * instead of crashing.
 */
public final class RadioProbe {

    private static final String MUTATED_TEXT = "PDFBox lane";

    private RadioProbe() {
    }

    public static void main(String[] args) throws Exception {
        File input = null;
        File outDir = null;
        boolean noMutate = false;
        boolean rasterWanted = false;
        for (String arg : args) {
            if ("--no-mutate".equals(arg)) {
                noMutate = true;
            } else if ("--raster".equals(arg)) {
                rasterWanted = true;
            } else if (!arg.startsWith("--") && input == null) {
                input = new File(arg);
            } else if (!arg.startsWith("--") && outDir == null) {
                outDir = new File(arg);
            } else {
                System.err.println("usage: RadioProbe [--no-mutate] [--raster]"
                        + " <input.pdf> <output-dir>");
                System.exit(2);
            }
        }
        if (input == null || outDir == null) {
            System.err.println("usage: RadioProbe [--no-mutate] [--raster]"
                    + " <input.pdf> <output-dir>");
            System.exit(2);
        }
        if (!outDir.exists() && !outDir.mkdirs()) {
            System.err.println("cannot create output dir: " + outDir);
            System.exit(2);
        }

        String inputSha256 = sha256(input);

        int pagesInitial;
        LinkedHashMap<String, Map<String, String>> snapshotInitial;
        try {
            try (PDDocument doc = Loader.loadPDF(input)) {
                pagesInitial = doc.getNumberOfPages();
                snapshotInitial = inspect(doc);
            }
        } catch (InvalidPasswordException e) {
            emitEncryptedReport(input, inputSha256,
                    "encrypted-no-password", describe(e));
            return;
        } catch (IOException e) {
            String detail = describe(e).toLowerCase(Locale.ROOT);
            if (detail.contains("password") || detail.contains("decrypt")) {
                emitEncryptedReport(input, inputSha256,
                        "encrypted-no-password", describe(e));
                return;
            }
            throw e;
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

        Long rasterAE = null;
        String rasterMeanDelta = null;
        String rasterPage1 = null;
        if (rasterWanted) {
            LinkedHashMap<String, Object> raster =
                    rasterParity(input, noopPdf);
            rasterAE = (Long) raster.remove("ae");
            rasterMeanDelta = (String) raster.remove("mean");
            StringBuilder meta = new StringBuilder("{");
            boolean firstMeta = true;
            for (Map.Entry<String, Object> m : raster.entrySet()) {
                if (!firstMeta) {
                    meta.append(", ");
                }
                firstMeta = false;
                meta.append(q(m.getKey())).append(" : ").append(m.getValue());
            }
            meta.append('}');
            rasterPage1 = meta.toString();
        }

        // Mutated save: first text field gets a known value.
        boolean mutatedReopen = false;
        String mutatedFieldName = null;
        File mutatedPdf = new File(outDir, "mutated.pdf");
        if (!noMutate) {
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
                    PDAcroForm acroForm =
                            doc.getDocumentCatalog().getAcroForm();
                    if (acroForm != null) {
                        PDField field = acroForm.getField(mutatedFieldName);
                        mutatedReopen = field instanceof PDTextField
                                && MUTATED_TEXT.equals(safeValueAsString(field));
                    }
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
        json.append("  \"mutateSkipped\" : ").append(noMutate).append(",\n");
        json.append("  \"encryptedUnsupported\" : false,\n");
        json.append("  \"rasterAE\" : ")
            .append(rasterAE == null ? "null" : rasterAE.toString()).append(",\n");
        json.append("  \"rasterMeanDelta\" : ")
            .append(rasterMeanDelta == null ? "null" : rasterMeanDelta)
            .append(",\n");
        json.append("  \"rasterPage1\" : ")
            .append(rasterPage1 == null ? "null" : rasterPage1).append(",\n");
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

    private static void emitEncryptedReport(
            File input, String inputSha256,
            String failureMode, String failureDetail) throws IOException {
        String finalInputSha256 = sha256(input);
        boolean originalUnchanged = inputSha256.equals(finalInputSha256);
        String jarSha512 = System.getProperty("pdfbox.jar.sha512", "");
        StringBuilder json = new StringBuilder();
        json.append("{\n");
        json.append("  \"provider\" : \"PDFBox\",\n");
        json.append("  \"pdfboxVersion\" : ")
            .append(q(org.apache.pdfbox.util.Version.getVersion())).append(",\n");
        json.append("  \"inputSHA256\" : ").append(q(inputSha256)).append(",\n");
        json.append("  \"pages\" : null,\n");
        json.append("  \"fieldCount\" : null,\n");
        json.append("  \"fieldTypes\" : [],\n");
        json.append("  \"radioExportValues\" : {},\n");
        json.append("  \"fieldInventory\" : [],\n");
        json.append("  \"noOpReopen\" : false,\n");
        json.append("  \"widgetStateEquivalent\" : false,\n");
        json.append("  \"mutatedReopen\" : false,\n");
        json.append("  \"mutateSkipped\" : true,\n");
        json.append("  \"encryptedUnsupported\" : true,\n");
        json.append("  \"rasterAE\" : null,\n");
        json.append("  \"rasterMeanDelta\" : null,\n");
        json.append("  \"rasterPage1\" : null,\n");
        json.append("  \"originalUnchanged\" : ").append(originalUnchanged).append(",\n");
        json.append("  \"finalInputSHA256\" : ")
            .append(q(finalInputSha256)).append(",\n");
        json.append("  \"jarSHA512\" : ").append(q(jarSha512)).append(",\n");
        json.append("  \"failureMode\" : ").append(q(failureMode)).append(",\n");
        json.append("  \"failureDetail\" : ").append(q(failureDetail)).append(",\n");
        json.append("  \"mutatedFieldName\" : \"\",\n");
        json.append("  \"perFieldDiffs\" : []\n");
        json.append("}\n");
        System.out.print(json);
    }

    /**
     * Renders page 1 of both documents at scale 1.0 (72 dpi, RGB, headless
     * Java2D) and compares them pixel-wise. Returns ae = absolute count of
     * differing pixels, mean = mean absolute per-channel delta formatted as
     * a decimal string (-1 when page dimensions differ and the mean is not
     * comparable), plus both page sizes.
     */
    private static LinkedHashMap<String, Object> rasterParity(
            File a, File b) throws IOException {
        BufferedImage imgA;
        BufferedImage imgB;
        try (PDDocument docA = Loader.loadPDF(a);
             PDDocument docB = Loader.loadPDF(b)) {
            if (docA.getNumberOfPages() < 1 || docB.getNumberOfPages() < 1) {
                throw new IOException("cannot rasterize: document has no page 1");
            }
            imgA = new PDFRenderer(docA).renderImage(
                    0, 1.0f, ImageType.RGB);
            imgB = new PDFRenderer(docB).renderImage(
                    0, 1.0f, ImageType.RGB);
        }
        int widthA = imgA.getWidth();
        int heightA = imgA.getHeight();
        int widthB = imgB.getWidth();
        int heightB = imgB.getHeight();
        long differingPixels;
        String meanDelta;
        if (widthA == widthB && heightA == heightB) {
            differingPixels = 0L;
            long channelSum = 0L;
            long channels = (long) widthA * heightA * 3L;
            for (int y = 0; y < heightA; y++) {
                for (int x = 0; x < widthA; x++) {
                    int pa = imgA.getRGB(x, y);
                    int pb = imgB.getRGB(x, y);
                    int dRed = Math.abs(((pa >> 16) & 0xFF)
                            - ((pb >> 16) & 0xFF));
                    int dGreen = Math.abs(((pa >> 8) & 0xFF)
                            - ((pb >> 8) & 0xFF));
                    int dBlue = Math.abs((pa & 0xFF) - (pb & 0xFF));
                    if ((dRed | dGreen | dBlue) != 0) {
                        differingPixels++;
                    }
                    channelSum += dRed + dGreen + dBlue;
                }
            }
            meanDelta = String.format(Locale.ROOT, "%.6f",
                    channelSum / (double) channels);
        } else {
            differingPixels = Math.max((long) widthA * heightA,
                    (long) widthB * heightB);
            meanDelta = "-1.000000";
        }
        LinkedHashMap<String, Object> out = new LinkedHashMap<>();
        out.put("ae", Long.valueOf(differingPixels));
        out.put("mean", meanDelta);
        out.put("widthA", Integer.valueOf(widthA));
        out.put("heightA", Integer.valueOf(heightA));
        out.put("widthB", Integer.valueOf(widthB));
        out.put("heightB", Integer.valueOf(heightB));
        return out;
    }

    private static String describe(Exception e) {
        String msg = e.getMessage();
        if (msg == null || msg.isEmpty()) {
            return e.getClass().getName();
        }
        return e.getClass().getSimpleName() + ": " + msg;
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
                        safe(() -> safeListJoin(choice.getValue())));
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
