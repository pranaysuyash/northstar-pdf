# PDFBox Companion Lane: Packaging and License Review

**Reviewed:** 2026-08-25
**Status:** Evidence-based review for the D-007 provider decision; not legal advice.
**Artifact inspected:** `benchmark/pdfbox-lane/pdfbox-app-3.0.8.jar`
(SHA-512 verified against the published Apache digest).

## License Facts (verified from the artifact)

- PDFBox 3.0.8 ships under the Apache License 2.0 (`META-INF/LICENSE`).
- `META-INF/NOTICE` requires preserving attribution for: The Apache Software
  Foundation (PDFBox/FontBox, with 2002–2007 pdfbox.org heritage), the Adobe
  Glyph List, the Zapf Dingbats Glyph List, Unicode, Inc. Bidi Mirroring data,
  and parts of TwelveMonkeys ImageIO.
- The fat jar bundles Bouncy Castle classes (`org/bouncycastle/*`) used for
  encryption support. Bouncy Castle distribution obligations must be reviewed
  from its own license files before shipping; the Apache NOTICE alone does not
  discharge them.
- Consequence: redistribution of the jar (or a jlink-trimmed subset) requires
  bundling the full LICENSE + NOTICE text and completing the Bouncy Castle
  notice review. All inspected licenses are permissive; no copyleft surface
  was found in the inspected artifact.

## Runtime Facts (verified on this machine)

- PDFBox 3.0.8 runs on the installed Homebrew OpenJDK 17.0.15 (arm64), fully
  headless with `-Djava.awt.headless=true`. No native libraries are required.
- The fat jar is approximately 13 MB; a jlink-trimmed runtime would add
  roughly 40–80 MB depending on modules retained.
- Rendering uses Java2D (`PDFRenderer`); measured raster parity on this
  machine is AE 0 versus source for the public AcroForm sample and both
  rotation fixtures at 72 dpi.

## Packaging Options for the macOS Product

| Option | Shape | Assessment |
|---|---|---|
| A. Require system JDK | User installs Java | Rejected for v1: unacceptable setup friction for the target SMB/individual users. |
| B. Bundle JVM in the app | jlink runtime inside the .app | Adds 40–80 MB to every download and a JVM upgrade surface for all users, including the majority whose PDFs have no AcroForm. |
| C. Separate opt-in companion process | PDFKit stays in-process; PDFBox runs as a helper invoked only for AcroForm documents, installed on first need with explicit consent | Selected direction (D-007). Keeps the base app small and fully native; the form-aware lane ships its own license notices and update cadence. |
| D. Server-side PDFBox | Remote processing | Rejected: violates the local-first privacy boundary without an explicit, separately reviewed consent model. |

## Security Notes

- The helper-process boundary (Option C) must treat the JVM lane as a sandbox
  boundary: no shared file handles beyond the staged copy, explicit timeout and
  memory limits, and JSON-only IPC. The existing lane already runs headless
  with digest verification on both sides.
- The structural AcroForm guard remains the routing point: PDFKit handles
  AcroForm-free documents in-process; documents with a catalog AcroForm are
  eligible for the companion lane instead of being silently degraded.

## Open Items Before Shipping the Lane

1. Bouncy Castle license file review and notice bundling.
2. jlink module list minimization and size measurement.
3. IPC contract hardening (timeouts, max payload, version handshake).
4. Notarization implications of shipping a signed JVM helper.
