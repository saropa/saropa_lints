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
}): string {
  const { hasHealth, healthScore, delta = '', tier, showVibrancy, vibrancyLabel } = params;

  if (hasHealth) {
    if (showVibrancy) {
      return `${healthScore}%${delta} · V${vibrancyLabel}`;
    }
    return `${healthScore}%${delta} · ${tier}`;
  }

  if (showVibrancy) {
    return `Saropa Lints · V${vibrancyLabel}`;
  }
  return `Saropa Lints · ${tier}`;
}
