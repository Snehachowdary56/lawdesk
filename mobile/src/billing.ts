// Law firms bill in tenths of an hour (6-minute units), always rounding up: 1-6 min = 0.1 h, 7-12 min = 0.2 h.
export const BILLING_UNIT_MINUTES = 6;

export function billableMinutes(elapsedMs: number): number {
  if (elapsedMs <= 0) return 0;
  const minutes = elapsedMs / 60000;
  return Math.ceil(minutes / BILLING_UNIT_MINUTES) * BILLING_UNIT_MINUTES;
}

export function formatClock(elapsedMs: number): string {
  const total = Math.max(0, Math.floor(elapsedMs / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return [h, m, s].map((n) => String(n).padStart(2, "0")).join(":");
}

export const hours = (minutes: number) => (minutes / 60).toFixed(1);
