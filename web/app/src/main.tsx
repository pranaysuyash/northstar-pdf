import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "../../design-system.css";
import "./app.css";
import { App } from "./App";

const container = document.getElementById("app");
if (!container) throw new Error("Missing #app mount point");

createRoot(container).render(
  <StrictMode>
    <App />
  </StrictMode>
);
