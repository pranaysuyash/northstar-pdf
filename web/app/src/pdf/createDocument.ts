/**
 * Client-side scratch document creation, backed by the vendored same-origin
 * pdf-lib bundle. Bytes produced here feed the standard PdfController.open
 * pipeline, so a created document behaves like an opened one: same viewer,
 * same export-copy contract, nothing leaves the device.
 */

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

function requirePdfLib(): PdfLibGlobal {
  if (!window.PDFLib) {
    throw new Error("pdf-lib is still loading. Try again in a moment.");
  }
  return window.PDFLib;
}

export function resolvePageSize(sizeID: string | undefined): ScratchPageSize {
  return (
    SCRATCH_PAGE_SIZES.find((size) => size.id === sizeID) ?? SCRATCH_PAGE_SIZES[0]
  );
}

export async function createBlankPdfBytes(
  pageSize: ScratchPageSize
): Promise<Uint8Array> {
  const pdfLib = requirePdfLib();
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
  const pdfLib = requirePdfLib();
  const doc = await pdfLib.PDFDocument.create();
  let embedded = 0;
  for (const file of files) {
    const bytes = new Uint8Array(await file.arrayBuffer());
    let image: PdfLibEmbeddedImage;
    if (file.type === "image/png") {
      image = await doc.embedPng(bytes);
    } else if (file.type === "image/jpeg") {
      image = await doc.embedJpg(bytes);
    } else {
      continue;
    }
    const page = doc.addPage([image.width, image.height]);
    page.drawImage(image, {
      x: 0,
      y: 0,
      width: image.width,
      height: image.height
    });
    embedded += 1;
  }
  if (embedded === 0) {
    throw new Error("No supported images (PNG or JPEG) were selected.");
  }
  return doc.save();
}
