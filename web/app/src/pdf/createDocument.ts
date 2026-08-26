/**
 * Client-side scratch document creation, backed by the vendored same-origin
 * pdf-lib bundle. Bytes produced here feed the standard PdfController.open
 * pipeline, so a created document behaves like an opened one: same viewer,
 * same export-copy contract, nothing leaves the device.
 */

import { ensurePdfLib } from "./ensurePdfLib";

export interface ScratchPageSize {
  readonly id: string;
  readonly width: number;
  readonly height: number;
}

/** Page sizes in PDF points, matching the native scratch-document sizes. */
export const SCRATCH_PAGE_SIZES: readonly ScratchPageSize[] = [
  { id: "Letter", width: 612, height: 792 },
  { id: "A4", width: 595, height: 842 },
  { id: "Legal", width: 612, height: 1008 }
];

export function resolvePageSize(sizeID: string | undefined): ScratchPageSize {
  return (
    SCRATCH_PAGE_SIZES.find((size) => size.id === sizeID) ?? SCRATCH_PAGE_SIZES[0]
  );
}

export async function createBlankPdfBytes(
  pageSize: ScratchPageSize
): Promise<Uint8Array> {
  const pdfLib = await ensurePdfLib();
  const doc = await pdfLib.PDFDocument.create();
  doc.addPage([pageSize.width, pageSize.height]);
  return doc.save();
}

/**
 * Builds one page per image at the image's native size. Only PNG and JPEG
 * are supported by the browser embedders; other types are skipped, and a
 * selection with none is rejected instead of producing an empty PDF.
 */
export async function createPdfFromImageFiles(
  files: File[]
): Promise<Uint8Array> {
  const supportedFiles = files.filter(
    (file) => file.type === "image/png" || file.type === "image/jpeg"
  );
  if (supportedFiles.length === 0) {
    throw new Error("No supported images (PNG or JPEG) were selected.");
  }

  // Parallelize reading array buffers across all files (async-parallel)
  const [pdfLib, imagePayloads] = await Promise.all([
    ensurePdfLib(),
    Promise.all(
      supportedFiles.map(async (file) => ({
        type: file.type as "image/png" | "image/jpeg",
        bytes: new Uint8Array(await file.arrayBuffer())
      }))
    )
  ]);

  const doc = await pdfLib.PDFDocument.create();
  // Embeds are independent parses — run them concurrently, then lay out pages.
  const images = await Promise.all(
    imagePayloads.map(({ type, bytes }) =>
      type === "image/png" ? doc.embedPng(bytes) : doc.embedJpg(bytes)
    )
  );
  for (const image of images) {
    const page = doc.addPage([image.width, image.height]);
    page.drawImage(image, {
      x: 0,
      y: 0,
      width: image.width,
      height: image.height
    });
  }

  return doc.save();
}

