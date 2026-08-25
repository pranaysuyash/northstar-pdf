import {
  createProductSurfaceState,
  selectProductMode,
  setModeCapability,
  type ProductModeID
} from "../../../product-modes.mjs";

export type { ProductModeID } from "../../../product-modes.mjs";
export {
  CAPABILITY_STATES,
  PRODUCT_MODES,
  createProductSurfaceState,
  getModeCapability,
  selectProductMode,
  setModeCapability
} from "../../../product-modes.mjs";

export type CapabilityState =
  | "available"
  | "loading"
  | "partial"
  | "reader_only"
  | "blocked"
  | "failed"
  | "validated";

/**
 * The React layer owns no domain logic of its own: mode selection and
 * capability transitions delegate to the framework-neutral contract module so
 * the browser entry, this UI, and headless tooling all share one state model.
 */
export type ProductSurfaceAction =
  | { type: "select-mode"; modeID: ProductModeID }
  | { type: "set-capability"; modeID: ProductModeID; capability: CapabilityState };

export type ProductSurfaceState = ReturnType<typeof createProductSurfaceState>;

export function productSurfaceReducer(
  state: ProductSurfaceState = createProductSurfaceState(),
  action: ProductSurfaceAction
): ProductSurfaceState {
  switch (action.type) {
    case "select-mode":
      return selectProductMode(state, action.modeID);
    case "set-capability":
      return setModeCapability(state, action.modeID, action.capability);
    default:
      return state;
  }
}
