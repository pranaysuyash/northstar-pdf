import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectDirectory = path.join(testDirectory, "..");

const assets = [
  ["web/vendor/pdfjs/pdf.min.mjs", "c3caae2cf1fe9d6e25588d0d239d02454422778ed5897314981496a4656eab82"],
  ["web/vendor/pdfjs/pdf.worker.min.mjs", "ee61de6dd3effd826b7083739409e50bae43c2e41a896f27ea8dd2d77e2f349b"],
  ["web/vendor/pdf-lib/pdf-lib.min.js", "0f9a5cad07941f0826586c94e089d89b918c46e5c17cf2d5a3c6f666e3bc694f"],
  ["web/vendor/pdfjs/LICENSE", "0d542e0c8804e39aa7f37eb00da5a762149dc682d7829451287e11b938e94594"],
  ["web/vendor/pdf-lib/LICENSE.md", "f2c9fc00fdb66eb99ac156ba52d734af66d8d309f65753ae809ad34ee2883bcb"],
  ["benchmark/results/public-sample-form.pdf", "5a681d44622f2ee577808e77f034525314d48a628b9cad26f7788564c9e922e8"],
  ["benchmark/results/2026-08-23-pdfkit-widgets/fixture.pdf", "b80bca995c4381f6570eda6c6a186e45f86dc0f78fa24cf6ff551150c31ddc74"],
  ["benchmark/results/security-corpus/encrypted-reader.pdf", "b1a6177b0736ebb8c8bff00df19137cc1d4887eb32fac836f90a02e36c3eacbf"],
  ["benchmark/results/security-corpus/truncated-128-bytes.pdf", "3b70218c05a4f4bbb38248af32153802e8b99e955d2161f856dc8cb29d624ea1"],
  ["benchmark/results/security-corpus/repeated-20-pages.pdf", "64f06a8d57e0807864c021b83e975981500c6099b748a134cbb442a8caaa1f71"]
  , ["benchmark/results/ocr-corpus/printed-scan.pdf", "9ce5e5c2d9a58e43fa61c1a612512a5dba31f11900aad625304d83681be14364"]
  , ["benchmark/results/rotation-corpus/rotated-widget-90.pdf", "bc7c40a80dc662258b99680c3d73dea05a1b9f297576410e21a0690b2e2711b2"]
  , ["benchmark/results/rotation-corpus/rotated-form6-mixed.pdf", "3e01dac92555798ca8d4369ed0ea4021c35a264e0969b5d08cd026e30364b177"]
];

for (const [relativePath, expectedDigest] of assets) {
  const absolutePath = path.join(projectDirectory, relativePath);
  assert.equal(fs.existsSync(absolutePath), true, `Missing provenance asset: ${relativePath}`);
  const digest = crypto.createHash("sha256").update(fs.readFileSync(absolutePath)).digest("hex");
  assert.equal(digest, expectedDigest, `Digest drift: ${relativePath}`);
}

console.log(`provenance contract: ${assets.length} assets verified`);
