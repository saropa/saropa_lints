/**
 * Centralized status bar label formatting for the unified Saropa item.
 *
 * Why this exists:
 * - The status bar has tight horizontal space, so labels must stay compact.
 * - We still need to disambiguate lint score (`%`) from vibrancy score (`/10`).
 * - A dedicated formatter keeps this logic testable and avoids drift across call sites.
 *
 * Formatting contract:
 * - With health + vibrancy: `90% ▲2 · V4/10`
 * - With health only: `90% ▲2 · recommended`
 * - Without health + vibrancy: `Saropa Lints · V4/10`
 * - Without health + vibrancy disabled: `Saropa Lints · recommended`
 */
export function buildStatusBarLabel(params: {
  hasHealth: boolean;
  healthScore?: number;
  delta?: string;
  tier: string;
  showVibrancy: boolean;
  vibrancyLabel: string | null;
  systemHealthSuffix?: string;
}): string {
  const { hasHealth, healthScore, delta = '', tier, showVibrancy, vibrancyLabel, systemHealthSuffix } = params;

  let base: string;
  if (hasHealth) {
    base = showVibrancy
      ? `${healthScore}%${delta} · V${vibrancyLabel}`
      : `${healthScore}%${delta} · ${tier}`;
  } else {
    base = showVibrancy
      ? `Saropa Lints · V${vibrancyLabel}`
      : `Saropa Lints · ${tier}`;
  }

  if (systemHealthSuffix) {
    return `${base} · ${systemHealthSuffix}`;
  }
  return base;
}
