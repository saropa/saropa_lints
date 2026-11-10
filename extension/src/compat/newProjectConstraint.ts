/**
 * The `saropa_lints` constraint written into a pubspec that does not declare it
 * yet. Uses the same `recommend()` as the compatibility card (Dart SDK filter,
 * newest stable first), so a new project gets the line its Dart can run instead
 * of a version frozen in the source.
 */
import { recommend } from './recommend';
import type { PubVersion } from './pubVersions';

/** Last 16.x release: resolves on every Dart the extension supports. */
export const FALLBACK_CONSTRAINT = '^16.7.0';

/**
 * Caret constraint for a new project. Falls back to [FALLBACK_CONSTRAINT] when
 * the Dart version or the pub.dev list is unavailable, or nothing fits the SDK.
 */
export async function chooseNewProjectConstraint(
  dartVersion: string | undefined,
  versions: PubVersion[],
): Promise<string> {
  if (!dartVersion || versions.length === 0) return FALLBACK_CONSTRAINT;
  const rec = await recommend(
    { dartVersion, locked: {}, inPubspec: false, pluginBlockDisabled: false },
    versions,
  );
  return rec.route === 'dependency' && rec.constraint ? rec.constraint : FALLBACK_CONSTRAINT;
}

/** Longest the pub.dev lookup may delay writing a new project's pubspec. */
export const VERSION_LOOKUP_TIMEOUT_MS = 8000;

/**
 * Runs [lookup], resolving to an empty list (which selects the fallback) if it
 * has not settled within [timeoutMs]. The timer is always cleared.
 */
export async function versionsWithin(
  lookup: () => Promise<{ versions: PubVersion[] }>,
  timeoutMs: number = VERSION_LOOKUP_TIMEOUT_MS,
): Promise<PubVersion[]> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<PubVersion[]>((resolve) => {
    timer = setTimeout(() => resolve([]), timeoutMs);
  });
  try {
    return await Promise.race([lookup().then((r) => r.versions), timeout]);
  } finally {
    clearTimeout(timer);
  }
}
