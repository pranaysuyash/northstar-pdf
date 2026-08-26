/** Ambient window.PDFLib typing for the vendored UMD pdf-lib bundle. */
/** Minimal surface of the vendored UMD pdf-lib bundle (window.PDFLib). */
declare global {
  interface PdfLibFormField {
    setText?(value: string): void;
    check?(): void;
    uncheck?(): void;
    select?(value: string): void;
  }

  interface PdfLibEmbeddedImage {
    readonly width: number;
    readonly height: number;
  }

  interface PdfLibCreatedPage {
    drawImage(
      image: PdfLibEmbeddedImage,
      options: { x: number; y: number; width: number; height: number }
    ): void;
  }

  interface PdfLibCreatedDocument {
    addPage(size: [number, number]): PdfLibCreatedPage;
    embedPng(bytes: Uint8Array): Promise<PdfLibEmbeddedImage>;
    embedJpg(bytes: Uint8Array): Promise<PdfLibEmbeddedImage>;
    save(): Promise<Uint8Array>;
  }

  interface PdfLibBox {
    x: number;
    y: number;
    width: number;
    height: number;
  }

  interface PdfLibFont {
    widthOfTextAtSize(text: string, size: number): number;
    heightAtSize(size: number): number;
  }

  interface PdfLibPage {
    getMediaBox(): PdfLibBox;
    getCropBox(): PdfLibBox;
    getBleedBox(): PdfLibBox;
    getTrimBox(): PdfLibBox;
    getArtBox(): PdfLibBox;
    setMediaBox(x: number, y: number, width: number, height: number): void;
    setCropBox(x: number, y: number, width: number, height: number): void;
    setBleedBox(x: number, y: number, width: number, height: number): void;
    setTrimBox(x: number, y: number, width: number, height: number): void;
    setArtBox(x: number, y: number, width: number, height: number): void;
    setRotation(rotation: { angle: number }): void;
    drawText(
      text: string,
      options: { x: number; y: number; size: number; font: PdfLibFont }
    ): void;
  }

  interface PdfLibGlobal {
    PDFDocument: {
      load(source: Uint8Array): Promise<{
        save(options?: { useObjectStreams?: boolean }): Promise<Uint8Array>;
        getForm(): {
          getField(name: string): PdfLibFormField;
          updateFieldAppearances(font?: unknown): void;
        };
        embedFont(name: string): Promise<PdfLibFont>;
        getPages(): PdfLibPage[];
        getPage(index: number): PdfLibPage;
      }>;
      create(): Promise<PdfLibCreatedDocument>;
    };
    StandardFonts: { Helvetica: string };
    degrees(angle: number): { angle: number };
  }

  // eslint-disable-next-line no-var
  var PDFLib: PdfLibGlobal | undefined;
}

export {};
