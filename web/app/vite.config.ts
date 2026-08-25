import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const emptyShim = fileURLToPath(new URL("./src/shims/empty.js", import.meta.url));

// The React entry consumes the framework-neutral contract modules in web/
// directly (single source, never vendored copies) and the locally bundled
// provider runtimes in web/vendor/. No network fetches are introduced:
// everything resolves to same-origin static assets.
export default defineConfig({
  root: __dirname,
  plugins: [react()],
  resolve: {
    alias: [
      // Optional Node-only imports inside the vendored pdf.js runtime.
      { find: /^(canvas|fs|url|https?|path|zlib|path2d)$/, replacement: emptyShim }
    ]
  },
  server: {
    port: 5173,
    strictPort: true
  },
  build: {
    outDir: "dist",
    sourcemap: true,
    target: "es2022"
  }
});
