/**
 * Type declarations for the framework-neutral product-mode contract
 * (product-modes.mjs). The runtime module stays plain ESM so Node-based
 * tests keep running without a build step; these types are additive.
 */
export interface ProductMode {
  readonly id: ProductModeID;
  readonly label: string;
  readonly shortLabel: string;
  readonly description: string;
  readonly defaultCapability: CapabilityState;
}

export type CapabilityState =
  | "available"
  | "loading"
  | "partial"
  | "reader_only"
  | "blocked"
  | "failed"
  | "validated";

export type ProductModeID = "reader" | "understand" | "complete" | "organize" | "review";

export declare const PRODUCT_MODES: readonly ProductMode[];
export declare const CAPABILITY_STATES: readonly CapabilityState[];

export function getProductMode(modeID: ProductModeID): ProductMode;

export interface ProductSurfaceState {
  activeMode: ProductModeID;
  capabilities: Record<ProductModeID, CapabilityState>;
  modeHistory: ProductModeID[];
}

export function createProductSurfaceState(): ProductSurfaceState;

export function selectProductMode(
  state: ProductSurfaceState,
  modeID: ProductModeID
): ProductSurfaceState;

export function setModeCapability(
  state: ProductSurfaceState,
  modeID: ProductModeID,
  capabilityState: CapabilityState
): ProductSurfaceState;

export function getModeCapability(
  state: ProductSurfaceState,
  modeID: ProductModeID
): CapabilityState;
