/**
 * Pure upgrade-detection helpers for the What's New panel (no `vscode` import so
 * they can be unit-tested headlessly).
 */

/** Major version in which the default diagnostic engine changed to the LSP server. */
export const ENGINE_CHANGE_MAJOR = 16;

/** Extracts the major version from a semver-ish string, or null when unparseable. */
function parseMajor(version: string | undefined): number | null {
  if (!version) return null;
  const match = /^(\d+)\./.exec(version.trim());
  return match ? Number(match[1]) : null;
}

/**
 * Human-readable reason for the engine-card decision, for the debug log. Mirrors
 * isUpgradingAcrossEngineChange's branches so the log never disagrees with behavior.
 */
export function describeEngineCardReason(previousVersion: string | undefined, shown: boolean): string {
  if (shown) return 'confirmed upgrade from before v' + ENGINE_CHANGE_MAJOR;
  if (parseMajor(previousVersion) === null) {
    return previousVersion ? 'previous version unparseable' : 'no previous version recorded (fresh install or unknown history)';
  }
  return 'previous version already v' + ENGINE_CHANGE_MAJOR + ' or later';
}

/**
 * True only when the user is KNOWN to be upgrading across the engine change: a
 * recorded previous version below ENGINE_CHANGE_MAJOR and a current version at or
 * above it. A missing or unparseable previous version (fresh install, or an upgrade
 * from a build that never recorded its version) returns false — the red engine card
 * is an upgrade warning, and showing it when the upgrade cannot be confirmed would
 * alarm users it does not apply to.
 */
export function isUpgradingAcrossEngineChange(
  previousVersion: string | undefined,
  currentVersion: string,
): boolean {
  const previous = parseMajor(previousVersion);
  const current = parseMajor(currentVersion);
  if (previous === null || current === null) return false;
  return previous < ENGINE_CHANGE_MAJOR && current >= ENGINE_CHANGE_MAJOR;
}
