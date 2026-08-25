import { useRef } from "react";
import { PRODUCT_MODES, type CapabilityState, type ProductModeID } from "../state/productSurface";
import { CapabilityBadge } from "../ui/CapabilityBadge";

interface ModeRailProps {
  activeMode: ProductModeID;
  capabilities: Record<ProductModeID, CapabilityState>;
  onSelect(mode: ProductModeID): void;
}

const INDEX = new Map(PRODUCT_MODES.map((mode, i) => [mode.id, String(i + 1).padStart(2, "0")]));

export function ModeRail({ activeMode, capabilities, onSelect }: ModeRailProps) {
  const navRef = useRef<HTMLDivElement>(null);

  const moveFocus = (from: number, delta: 1 | -1) => {
    const buttons = navRef.current?.querySelectorAll<HTMLButtonElement>("[role=tab]");
    if (!buttons?.length) return;
    const next = (from + delta + buttons.length) % buttons.length;
    buttons[from].tabIndex = -1;
    buttons[next].tabIndex = 0;
    buttons[next].focus();
    buttons[next].click();
  };

  return (
    <nav className="product-mode-rail" aria-label="PDF Editor modes">
      <div className="product-mode-kicker">Document workbench</div>
      <div ref={navRef} className="product-mode-nav" role="tablist" aria-orientation="vertical">
        {PRODUCT_MODES.map((mode, i) => (
          <button
            key={mode.id}
            type="button"
            role="tab"
            id={`mode-tab-${mode.id}`}
            aria-selected={activeMode === mode.id}
            aria-controls={`mode-panel-${mode.id}`}
            data-product-mode={mode.id}
            tabIndex={activeMode === mode.id ? 0 : -1}
            className={`product-mode-button${activeMode === mode.id ? " is-active" : ""}`}
            onClick={() => onSelect(mode.id)}
            onKeyDown={(event) => {
              if (event.key === "ArrowDown") moveFocus(i, 1);
              if (event.key === "ArrowUp") moveFocus(i, -1);
            }}
          >
            <span className="product-mode-index">{INDEX.get(mode.id)}</span>
            <span className="product-mode-copy">
              <strong>{mode.label}</strong>
              <small>{mode.description}</small>
            </span>
            <span className="product-mode-state" data-mode-state={mode.id}>
              <CapabilityBadge state={capabilities[mode.id] as CapabilityState} />
            </span>
          </button>
        ))}
      </div>
      <div id="productModeStatus" className="product-mode-status" role="status" aria-live="polite">
        {PRODUCT_MODES.find((m) => m.id === activeMode)?.label} is the active document surface.
      </div>
    </nav>
  );
}
