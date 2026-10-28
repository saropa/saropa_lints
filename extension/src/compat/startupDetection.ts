/**
 * Pure start-up detection: which route a project uses (pubspec, plugin, both,
 * neither), whether a newer applicable saropa_lints exists for it, and the
 * single prompt that offers the migration. Decision 20 of
 * plans/PLAN_analyzer_12_to_13_14_upgrade.md.
 *
 * No vscode, fs or network here: facts and the version list are injected. The
 * pub solver is never run (cheap filters only, via `recommend` without a prober).
 */
import * as semver from 'semver';
import type { ProjectFacts } from './projectFacts';
import type { PubVersion } from './pubVersions';
import { recommend } from './recommend';

export type RouteState =
  | 'pubspecOnly'
  | 'pluginOnly'
  | 'bothAgree'
  | 'bothDisagree'
  | 'neither'
  | 'localSource'
  | 'dartTooOld';

/** Plugin route needs this Dart (analyzer 13 needs _fe_analyzer_shared 100). */
const PLUGIN_MIN_DART = '3.11.0';

export interface Installed {
  pubspec?: string;
  plugin?: string;
}

export interface StartupOffer {
  state: RouteState;
  /** Which prompt wording and dismissal bucket applies. */
  route: 'dependency' | 'plugin' | 'both';
  installed: Installed;
  offered: string;
  dart?: string;
  /** Renamed rules between the lowest installed version and `offered`. */
  renamedCount: number;
}

export interface StartupResult {
  state: RouteState;
  installed: Installed;
  offer?: StartupOffer;
}

/** Exact version from a locked or configured value (`^1.2.3`, `>=1.2.3 <2.0.0` -> 1.2.3). */
function coerce(v: string | undefined): string | undefined {
  return v ? (semver.coerce(v)?.version ?? undefined) : undefined;
}

export function installedVersions(facts: ProjectFacts): Installed {
  const plugin = facts.pluginBlockDisabled ? undefined : coerce(facts.pluginVersion);
  return { pubspec: coerce(facts.locked.saropaLints?.version), plugin };
}

export function detectState(facts: ProjectFacts): RouteState {
  const locked = facts.locked.saropaLints;
  if (locked && locked.source !== 'hosted') return 'localSource';
  const { pubspec, plugin } = installedVersions(facts);
  // Declared in pubspec but not yet locked still counts as the pubspec route.
  const hasPub = pubspec !== undefined || facts.inPubspec;
  const hasPlugin = facts.pluginVersion !== undefined && !facts.pluginBlockDisabled;
  const dart = semver.coerce(facts.dartVersion ?? '')?.version;
  if (hasPlugin && dart && semver.lt(dart, PLUGIN_MIN_DART)) return 'dartTooOld';
  if (hasPub && hasPlugin) return pubspec !== undefined && plugin !== undefined && pubspec !== plugin ? 'bothDisagree' : 'bothAgree';
  if (hasPub) return 'pubspecOnly';
  if (hasPlugin) return 'pluginOnly';
  return 'neither';
}

function routeOf(state: RouteState, facts: ProjectFacts): StartupOffer['route'] {
  if (state === 'bothAgree' || state === 'bothDisagree') return 'both';
  if (state === 'pluginOnly') return 'plugin';
  if (state === 'dartTooOld') return facts.inPubspec ? 'both' : 'plugin';
  return 'dependency';
}

/**
 * Detect the route and compute the offer. Offered only when a recommended
 * version (Dart SDK and meta filtered, no solver) is newer than at least one
 * installed version. `renamedBetween` counts renamed rules in a version range.
 */
export async function computeStartup(
  facts: ProjectFacts,
  versions: PubVersion[],
  renamedBetween: (from: string, to: string) => number = () => 0,
): Promise<StartupResult> {
  const state = detectState(facts);
  const installed = installedVersions(facts);
  const result: StartupResult = { state, installed };
  if (state === 'neither' || state === 'localSource' || state === 'dartTooOld') return result;

  const rec = await recommend(facts, versions);
  if (rec.route === 'none' || !rec.pluginVersion) return result;
  const offered = rec.pluginVersion;
  const lows = [installed.pubspec, installed.plugin].filter((v): v is string => v !== undefined);
  // Declared but unresolved (no lock, no plugin): nothing to compare against.
  if (lows.length === 0) return result;
  const behind = lows.filter((v) => semver.gt(offered, v));
  if (behind.length === 0) return result;
  const lowest = behind.sort(semver.compare)[0];
  result.offer = {
    state,
    route: routeOf(state, facts),
    installed,
    offered,
    dart: facts.dartVersion,
    renamedCount: renamedBetween(lowest, offered),
  };
  return result;
}

/** Key for "Don't ask for this version": per folder, route and offered version. */
export function dontAskKey(root: string, route: StartupOffer['route'], version: string): string {
  return `${root}::${route}@${version}`;
}

export function isSuppressed(dismissed: readonly string[] | undefined, offer: StartupOffer, root: string): boolean {
  return (dismissed ?? []).includes(dontAskKey(root, offer.route, offer.offered));
}

export type Translate = (key: string, params?: Record<string, string>) => string;

/** The single start-up prompt text; `t` resolves en.json keys (l10n in the host). */
export function offerMessage(offer: StartupOffer, t: Translate): string {
  const K = 'compat.startup.';
  const { pubspec, plugin } = offer.installed;
  const differ = offer.route === 'both' && pubspec !== undefined && plugin !== undefined && pubspec !== plugin;
  const installed = differ
    ? t(K + 'installedDisagree', { pubspec: pubspec!, plugin: plugin! })
    : (pubspec ?? plugin ?? '');
  const routeKey = { dependency: 'routeDependency', plugin: 'routePlugin', both: 'routeBoth' }[offer.route];
  const suffix = (offer.dart ? '' : 'NoDart') + (offer.renamedCount > 0 ? 'Renames' : '');
  return t(K + 'offer' + suffix, {
    route: t(K + routeKey),
    installed,
    offered: offer.offered,
    dart: offer.dart ?? '',
    count: String(offer.renamedCount),
  });
}
