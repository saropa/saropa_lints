/**
 * Pure recommendation: which saropa_lints constraint and plugin version suit
 * a project, from its facts, the published versions and (optionally) the pub
 * solver. Slice E of plans/history/2026.10/2026.10.28/PLAN_analyzer_12_to_13_14_upgrade.md (decision 12).
 *
 * Never hard-codes a version. Cheap filters (Dart SDK, `meta` pin) run first;
 * the solver then probes the newest survivor, falling back one major at a
 * time, at most MAX_PROBES probes. Messages are en.json keys under
 * `compat.recommend` plus params; the UI formats them.
 */
import * as semver from 'semver';
import type { ProjectFacts } from './projectFacts';
import type { PubVersion } from './pubVersions';
import type { ProbeResult } from './solverProbe';

export type Route = 'dependency' | 'plugin' | 'both' | 'none';

export interface Msg {
  key: string;
  params: Record<string, string>;
}

export interface Recommendation {
  route: Route;
  /** `^x.y.z` for pubspec.yaml; empty when no pubspec edit applies. */
  constraint: string;
  /** Exact version for the analysis_options.yaml plugin entry; empty if none. */
  pluginVersion: string;
  /** The headline explanation. */
  messageKey: string;
  messageParams: Record<string, string>;
  blockers: Msg[];
  fixes: Msg[];
  /** Extra remarks (for example: versions list is stale). */
  notes: Msg[];
}

export type Prober = (constraint: string) => Promise<ProbeResult>;

export interface RecommendOptions {
  /** True when `versions` came from the offline cache. */
  stale?: boolean;
}

const MAX_PROBES = 3;
/** The plugin route resolves in the analyzer server's private package; it needs this Dart. */
const PLUGIN_MIN_DART = '3.11.0';
const K = 'compat.recommend.';

const msg = (key: string, params: Record<string, string> = {}): Msg => ({ key: K + key, params });

function excludes(range: string | undefined, version: string | undefined): boolean {
  if (!range || !version) return false;
  const v = semver.coerce(version, { includePrerelease: true })?.version;
  if (!v || semver.validRange(range) === null) return false;
  return !semver.satisfies(v, range, { includePrerelease: true });
}

function newestFirst(list: PubVersion[]): PubVersion[] {
  return list
    .filter((v) => semver.valid(v.version) && !semver.prerelease(v.version))
    .sort((a, b) => semver.rcompare(a.version, b.version));
}

function installedRoute(facts: ProjectFacts): Route {
  const plugin = facts.pluginVersion !== undefined && !facts.pluginBlockDisabled;
  if (facts.inPubspec && plugin) return 'both';
  if (facts.inPubspec) return 'dependency';
  if (plugin) return 'plugin';
  return 'dependency';
}

function result(
  r: Partial<Recommendation> & Pick<Recommendation, 'route' | 'messageKey'>,
  stale: boolean,
): Recommendation {
  const notes = stale ? [msg('staleVersions')] : [];
  return {
    constraint: '',
    pluginVersion: '',
    messageParams: {},
    blockers: [],
    fixes: [],
    ...r,
    notes,
    messageKey: K + r.messageKey,
  };
}

/** True when two recommendations would make the same edits. */
export function sameRecommendation(a: Recommendation, b: Recommendation): boolean {
  return a.route === b.route && a.constraint === b.constraint && a.pluginVersion === b.pluginVersion;
}

export async function recommend(
  facts: ProjectFacts,
  versions: PubVersion[],
  probe?: Prober,
  options: RecommendOptions = {},
): Promise<Recommendation> {
  const stale = options.stale === true;
  const locked = facts.locked.saropaLints;

  // Local path/git source: the user chose it; report facts only.
  if (locked && locked.source !== 'hosted') {
    return result({ route: 'none', messageKey: 'localSource', messageParams: { source: locked.source } }, stale);
  }

  const all = newestFirst(versions);
  if (all.length === 0) return result({ route: 'none', messageKey: 'noVersions' }, stale);
  const newest = all[0];
  const route = installedRoute(facts);
  const dart = facts.dartVersion ?? '';
  const sdkOk = all.filter((v) => !excludes(v.sdk, facts.dartVersion));
  const upgradeDart = msg('fixFlutterUpgrade');

  // Plugin-only: no pubspec edit, no meta pin, no solver.
  if (route === 'plugin') {
    const pick = sdkOk[0];
    if (!pick) {
      return result({ route: 'none', messageKey: 'noCompatible', blockers: [msg('blockerSdk', { version: newest.version, dart })], fixes: [upgradeDart] }, stale);
    }
    const base = { route: 'plugin' as Route, pluginVersion: pick.version, messageParams: { version: pick.version } };
    if (pick.version !== newest.version) {
      return result({ ...base, messageKey: 'needsNewerDart', messageParams: { newest: newest.version, chosen: pick.version, dart }, blockers: [msg('blockerSdk', { version: newest.version, dart })], fixes: [upgradeDart, msg('fixKeepVersion', { version: pick.version })] }, stale);
    }
    if (facts.pluginVersion === pick.version) {
      return result({ ...base, messageKey: 'alreadyCorrect' }, stale);
    }
    return result({ ...base, messageKey: 'pluginOnly' }, stale);
  }

  // Dependency route (alone or with the plugin).
  const survivors = sdkOk.filter((v) => !excludes(v.meta, facts.flutterMetaPin));
  const lastProbe: { holder?: string } = {};
  const failedProbes = new Set<string>();
  let chosen: PubVersion | undefined;
  let probes = 0;
  let ceilingMajor = Infinity;
  for (;;) {
    const cand = survivors.find((v) => semver.major(v.version) < ceilingMajor);
    if (!cand) break;
    if (!probe) {
      chosen = cand;
      break;
    }
    if (probes >= MAX_PROBES) break;
    probes++;
    const res = await probe('^' + cand.version);
    if (res.ok) {
      chosen = cand;
      break;
    }
    if (res.toolError) {
      // The tool failed, so nothing is known about this constraint: do not lower the ceiling.
      return result({ route: 'none', messageKey: 'probeFailed', messageParams: { detail: res.reason } }, stale);
    }
    lastProbe.holder ??= res.blockingPackage;
    failedProbes.add(cand.version);
    ceilingMajor = semver.major(cand.version);
  }

  // Decision 19: a newest version blocked on the pubspec route still works as a
  // plugin (private package, own analyzer) on Dart >= 3.11. Filter on sdk only: no probe.
  const newestOk = sdkOk[0];
  const dartCoerced = semver.coerce(facts.dartVersion ?? '')?.version;
  const pluginEligible = !!newestOk && !!dartCoerced && semver.gte(dartCoerced, PLUGIN_MIN_DART);
  if (pluginEligible && (!chosen || failedProbes.has(newestOk.version))) {
    const holder = lastProbe.holder ?? 'unknown';
    const blockers = [msg('blockerPackage', { package: holder })];
    if (!chosen && survivors.length === 0) blockers.push(msg('blockerMeta', { version: newest.version, pin: facts.flutterMetaPin ?? '' }));
    const fixes = [msg('fixUsePluginRoute', { version: newestOk.version })];
    if (chosen) fixes.push(msg('fixPubspecFallback', { version: chosen.version, package: holder }));
    const out = result({
      route: 'plugin',
      pluginVersion: newestOk.version,
      messageKey: facts.pluginVersion === newestOk.version && !facts.pluginBlockDisabled ? 'alreadyCorrect' : 'blockedUsePlugin',
      messageParams: { version: newestOk.version, package: holder },
      blockers,
      fixes,
    }, stale);
    const pubspecVersion = locked?.version;
    if (pubspecVersion) out.notes.push(msg('editorVsCli', { plugin: newestOk.version, pubspec: pubspecVersion }));
    out.notes.push(msg('cliNeedsPubspec'));
    return out;
  }

  if (!chosen) {
    // Nothing resolves as a dependency. The plugin route is offered only when
    // its candidate passed the solver; with no solver it is offered unchecked and says so.
    const pick = sdkOk[0];
    const holder = lastProbe.holder ?? 'unknown';
    const blockers = [msg('blockerPackage', { package: holder })];
    if (!pick) {
      blockers.push(msg('blockerSdk', { version: newest.version, dart }));
      return result({ route: 'none', messageKey: 'noVersionResolves', messageParams: { package: holder }, blockers, fixes: [upgradeDart] }, stale);
    }
    if (survivors.length === 0) blockers.push(msg('blockerMeta', { version: newest.version, pin: facts.flutterMetaPin ?? '' }));
    if (probe && !failedProbes.has(pick.version)) {
      const res = await probe('^' + pick.version);
      if (!res.ok) {
        if (res.toolError) {
          return result({ route: 'none', messageKey: 'probeFailed', messageParams: { detail: res.reason } }, stale);
        }
        failedProbes.add(pick.version);
      }
    }
    if (failedProbes.has(pick.version)) {
      return result({ route: 'none', messageKey: 'noPluginResolves', messageParams: { package: holder, version: pick.version }, blockers, fixes: [upgradeDart] }, stale);
    }
    const out = result({
      route: 'plugin',
      pluginVersion: pick.version,
      messageKey: 'noVersionResolves',
      messageParams: { package: holder },
      blockers,
      fixes: [msg('fixUsePluginRoute', { version: pick.version })],
    }, stale);
    if (!probe) out.notes.push(msg('pluginUnverified', { version: pick.version }));
    return out;
  }

  const constraint = '^' + chosen.version;
  const base = { route, constraint, pluginVersion: chosen.version, messageParams: { version: chosen.version } };
  const lockedV = locked?.version;
  const plugin = facts.pluginVersion;

  if (chosen.version === newest.version) {
    if (lockedV === chosen.version) {
      if (route === 'both' && plugin !== lockedV) {
        return result({ ...base, messageKey: 'alignPlugin', messageParams: { plugin: plugin ?? '', locked: lockedV }, fixes: [msg('fixAlignPlugin', { version: lockedV })] }, stale);
      }
      return result({ ...base, messageKey: 'alreadyCorrect' }, stale);
    }
    return result({ ...base, messageKey: 'latestOk' }, stale);
  }

  // The newest published version was not chosen: say why.
  const params = { newest: newest.version, chosen: chosen.version, dart, pin: facts.flutterMetaPin ?? '', package: lastProbe.holder ?? '' };
  const keep = msg('fixKeepVersion', { version: chosen.version });
  let out: Pick<Recommendation, 'messageKey' | 'blockers' | 'fixes'>;
  if (excludes(newest.sdk, facts.dartVersion)) {
    out = { messageKey: 'needsNewerDart', blockers: [msg('blockerSdk', { version: newest.version, dart })], fixes: [upgradeDart, keep] };
  } else if (excludes(newest.meta, facts.flutterMetaPin)) {
    out = { messageKey: 'metaExcludesPin', blockers: [msg('blockerMeta', { version: newest.version, pin: params.pin })], fixes: [msg('fixUpgradeFlutterMeta'), keep] };
  } else {
    out = { messageKey: 'packageHoldsAnalyzer', blockers: [msg('blockerPackage', { package: params.package })], fixes: [msg('fixUpdateHolder', { package: params.package }), keep] };
  }
  if (lockedV === chosen.version && (route !== 'both' || plugin === lockedV)) {
    return result({ ...base, messageKey: 'alreadyCorrect', messageParams: params }, stale);
  }
  return result({ ...base, ...out, messageParams: params }, stale);
}
