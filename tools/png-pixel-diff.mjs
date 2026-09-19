/**
 * png-pixel-diff.mjs — dependency-free PNG decoding and perceptual pixel
 * comparison for node-side visual regression tests.
 *
 * Why this exists: byte-level PNG comparison (Buffer.equals) is engine- and
 * render-sensitive — a Chrome minor update re-encodes identical pixels into
 * different bytes and flips every visual test to a false 100% diff
 * (flaky-register 2026-08-26, toolbar_visual_regression_test). Real pixel
 * comparison needs a decoder; pixelmatch/pngjs are not vendored and the repo
 * is air-gapped, so this module implements the small subset needed:
 * 8-bit, non-interlaced PNG, color types 2 (RGB) and 6 (RGBA).
 *
 * Usage:
 *   import { decodePNG, pixelDiff } from "../tools/png-pixel-diff.mjs";
 *   const result = pixelDiff(baselineBytes, currentBytes, { channelTolerance: 8 });
 *   // result: { status: "identical" | "within-tolerance" | "changed"
 *   //                | "dimension-mismatch" | "undecodable",
 *   //           diffPercent: 0..1, detail?: string }
 *
 * diffPercent is the fraction of pixels where any channel delta exceeds
 * channelTolerance (0-255). Antialiasing and PNG encoder noise stay far
 * below the default tolerance; real layout/repaint changes do not.
 */

import zlib from "node:zlib";

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function chunkType(buffer, offset) {
  return buffer.toString("ascii", offset + 4, offset + 8);
}

/**
 * Decode an 8-bit non-interlaced PNG (color type 2 RGB or 6 RGBA) into a
 * flat RGBA Uint8Array. Throws on unsupported formats rather than guessing.
 */
export function decodePNG(buffer) {
  if (!buffer || buffer.length < 8 || !buffer.subarray(0, 8).equals(PNG_SIGNATURE)) {
    throw new Error("Not a PNG file (bad signature).");
  }
  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  let interlace = 0;
  const idat = [];

  while (offset + 8 <= buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = chunkType(buffer, offset);
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    if (type === "IHDR") {
      width = buffer.readUInt32BE(dataStart);
      height = buffer.readUInt32BE(dataStart + 4);
      bitDepth = buffer[dataStart + 8];
      colorType = buffer[dataStart + 9];
      interlace = buffer[dataStart + 12];
    } else if (type === "IDAT") {
      idat.push(buffer.subarray(dataStart, dataEnd));
    } else if (type === "IEND") {
      break;
    }
    offset = dataEnd + 4; // skip CRC
  }

  if (bitDepth !== 8) {
    throw new Error(`Unsupported PNG bit depth ${bitDepth} (only 8 supported).`);
  }
  if (interlace !== 0) {
    throw new Error("Unsupported PNG interlacing (only non-interlaced supported).");
  }
  if (colorType !== 6 && colorType !== 2) {
    throw new Error(`Unsupported PNG color type ${colorType} (only RGBA 6 and RGB 2 supported).`);
  }

  const channels = colorType === 6 ? 4 : 3;
  const stride = width * channels;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  if (raw.length < (stride + 1) * height) {
    throw new Error(`PNG pixel stream truncated (${raw.length} bytes for ${width}x${height}).`);
  }

  // Unfilter scanlines (filters: 0 None, 1 Sub, 2 Up, 3 Average, 4 Paeth).
  const pixels = new Uint8Array(width * height * 4);
  const previous = new Uint8Array(stride);
  const current = new Uint8Array(stride);
  const paeth = (a, b, c) => {
    const p = a + b - c;
    const pa = Math.abs(p - a);
    const pb = Math.abs(p - b);
    const pc = Math.abs(p - c);
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  };

  for (let y = 0; y < height; y++) {
    const rowStart = y * (stride + 1);
    const filter = raw[rowStart];
    for (let i = 0; i < stride; i++) {
      const filtered = raw[rowStart + 1 + i];
      const left = i >= channels ? current[i - channels] : 0;
      const up = previous[i];
      const upLeft = i >= channels ? previous[i - channels] : 0;
      let predictor;
      switch (filter) {
        case 0: predictor = 0; break;
        case 1: predictor = left; break;
        case 2: predictor = up; break;
        case 3: predictor = Math.floor((left + up) / 2); break;
        case 4: predictor = paeth(left, up, upLeft); break;
        default: throw new Error(`Unsupported PNG scanline filter ${filter}.`);
      }
      current[i] = (filtered + predictor) & 0xff;
    }
    for (let x = 0; x < width; x++) {
      const src = x * channels;
      const dst = (y * width + x) * 4;
      pixels[dst] = current[src];
      pixels[dst + 1] = current[src + 1];
      pixels[dst + 2] = current[src + 2];
      pixels[dst + 3] = channels === 4 ? current[src + 3] : 255;
    }
    previous.set(current);
  }

  return { width, height, pixels };
}

/**
 * Perceptual pixel comparison of two PNG buffers.
 * Returns a status + diffPercent suitable for visual-regression assertions.
 */
export function pixelDiff(bufferA, bufferB, { channelTolerance = 8 } = {}) {
  let a;
  let b;
  try {
    a = decodePNG(bufferA);
    b = decodePNG(bufferB);
  } catch (error) {
    return { status: "undecodable", diffPercent: 1, detail: error.message };
  }
  if (a.width !== b.width || a.height !== b.height) {
    return {
      status: "dimension-mismatch",
      diffPercent: 1,
      detail: `baseline ${a.width}x${a.height} vs current ${b.width}x${b.height}`
    };
  }
  const total = a.width * a.height;
  let differing = 0;
  for (let i = 0; i < total * 4; i += 4) {
    if (Math.abs(a.pixels[i] - b.pixels[i]) > channelTolerance
        || Math.abs(a.pixels[i + 1] - b.pixels[i + 1]) > channelTolerance
        || Math.abs(a.pixels[i + 2] - b.pixels[i + 2]) > channelTolerance
        || Math.abs(a.pixels[i + 3] - b.pixels[i + 3]) > channelTolerance) {
      differing += 1;
    }
  }
  const diffPercent = differing / total;
  const status = diffPercent === 0
    ? "identical"
    : diffPercent < 1
      ? "within-tolerance-or-changed"
      : "changed";
  return { status, diffPercent };
}
