import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "../../design-system.css";
import "./app.css";
import { App } from "./App";

if (import.meta.env.DEV) {
  // React Scan (dev-only): highlights unnecessary re-renders in the toolbar.
  void import("react-scan").then(({ scan }) =>
    scan({ enabled: true, log: false, showToolbar: true })
  );
}

const container = document.getElementById("app");
if (!container) throw new Error("Missing #app mount point");

createRoot(container).render(
  <StrictMode>
    <App />
  </StrictMode>
);
