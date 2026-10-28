/**
 * Pure gating for the upgrade prompt: only versions that `recommend()` accepts
 * are offered, and a failed solver probe sends the user to the compatibility
 * card instead of letting `pub get` fail after the pubspec was edited.
 */
import type { Recommendation } from './recommend';

/** globalState key for the cached pub.dev version list. */
export const VERSIONS_CACHE_KEY = 'saropaLints.pubVersionsCache';

/**
 * The version to offer, or undefined when nothing should be offered
 * (no acceptable version, or it equals what is installed).
 */
export function offerableVersion(rec: Recommendation, installed: string): string | undefined {
  if (rec.route === 'none' || !rec.pluginVersion) return undefined;
  return rec.pluginVersion === installed ? undefined : rec.pluginVersion;
}

/**
 * After the user clicks Upgrade on `offered`, with the solver-backed
 * recommendation in hand: apply it, or open the card to explain.
 */
export function decideOnUpgrade(rec: Recommendation, offered: string): 'apply' | 'openCard' {
  if (rec.route === 'none' || !rec.pluginVersion) return 'openCard';
  if (rec.messageKey === 'compat.recommend.noVersionResolves') return 'openCard';
  if (rec.messageKey === 'compat.recommend.blockedUsePlugin') return 'openCard';
  // The solver chose something other than what the toast promised: explain.
  if (rec.pluginVersion !== offered) return 'openCard';
  return 'apply';
}
