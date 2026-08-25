import type { CapabilityState } from "../state/productSurface";

const LABELS: Record<CapabilityState, string> = {
  available: "Ready",
  loading: "Working",
  partial: "Partial",
  reader_only: "Reader only",
  blocked: "Blocked",
  failed: "Failed",
  validated: "Validated"
};

export function CapabilityBadge({ state }: { state: CapabilityState }) {
  return (
    <span className={`capability-badge capability-${state}`} data-capability={state}>
      {LABELS[state]}
    </span>
  );
}
