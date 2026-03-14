/**
 * Path helpers shared by Code Lens, Issues tree, and commands.
 * Ensures consistent normalization for comparison with violations.json paths (forward slashes).
 */

/** Normalize path to forward slashes for consistent match with violations.json file paths. */
export function normalizePath(p: string): string {
  return p.replace(/\\/g, '/');
}
