import { fileURLToPath } from "node:url";
import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";

const emptyShim = fileURLToPath(new URL("./src/shims/empty.js", import.meta.url));

// Restores the air-gap CSP contract from the legacy web/index.html on
// production builds only. The built output contains no inline scripts, so
// script-src 'self' holds without a nonce. Dev keeps HMR by skipping this.
function productionCsp(): Plugin {
  const policy = [
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' blob: data:",
    "worker-src 'self' blob:",
    "connect-src 'none'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'none'"
  ].join("; ");
  return {
    name: "production-csp",
    apply: "build",
    transformIndexHtml: {
      order: "pre",
      handler() {
        return [
          {
            tag: "meta",
            attrs: { "http-equiv": "Content-Security-Policy", content: policy },
            injectTo: "head"
          }
        ];
      }
    }
  };
}

// The React entry consumes the framework-neutral contract modules in web/
// directly (single source, never vendored copies) and the locally bundled
// provider runtimes in web/vendor/. No network fetches are introduced:
// everything resolves to same-origin static assets.
export default defineConfig({
  root: __dirname,
  plugins: [react(), productionCsp()],
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
    target: "es2022",
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes("vendor/pdfjs")) {
            return "pdfjs";
          }
          if (id.includes("node_modules/react") || id.includes("node_modules/react-dom")) {
            return "react-vendor";
          }
        }
      }
    }
  }
});
