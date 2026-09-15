export const PLAY_STEPS = [
  { id: "welcome", label: "Start" },
  { id: "setup", label: "Set up" },
  { id: "think", label: "Key points" },
  { id: "email", label: "Email" },
  { id: "record", label: "Record" },
  { id: "yours", label: "Look" },
  { id: "submit", label: "Submit" },
  { id: "why", label: "Done" },
];

const known = new Set([...PLAY_STEPS.map((s) => s.id), "stuck", "facilitator"]);

export function isKnownStep(id) {
  return known.has(id);
}

export function stepLabel(id) {
  return PLAY_STEPS.find((s) => s.id === id)?.label || id || "—";
}

export function stepIndex(id) {
  const i = PLAY_STEPS.findIndex((s) => s.id === id);
  return i < 0 ? -1 : i;
}

export function tickCount(ticks) {
  if (!ticks || typeof ticks !== "object") return 0;
  return Object.keys(ticks).filter((k) => ticks[k]).length;
}
