/**
 * Decides whether a scan request may skip the "light lane" rules — those the
 * in-process analyzer plugin runs itself when the project is configured with
 * `lane: light` under `plugins.saropa_lints` in `analysis_options.yaml`.
 *
 * See `plans/PLAN_two_lane_daemon_architecture.md`. The Dart-side definition
 * of which rules those are lives in `lib/src/config/rule_lane.dart`; this
 * module never enumerates rules, it only answers "is the in-process lane
 * genuinely covering them right now?".
 *
 * **Why this is not just a YAML read.** Excluding the light lane from the scan
 * is only safe while the plugin is actually reporting. If the yaml says
 * `lane: light` but the plugin is silent — a crashed isolate, a stale compiled
 * plugin, an analysis server that never loaded it — then excluding those rules
 * from the scan too would make ~200 error/warning-level rules invisible in
 * BOTH lanes, with nothing on screen to indicate it. That failure is silent
 * and dangerous, whereas the opposite failure (not excluding while the plugin
 * IS alive) merely double-reports a finding, which is visible and harmless.
 * So the gate demands positive evidence of liveness and fails toward
 * duplicates, never toward silence.
 */
import * as path from 'node:path';
import * as fs from 'node:fs';
import { verifyPluginLiveness } from '../pluginLiveness';

/**
 * Matches `lane: <value>` nested under `plugins:` → `saropa_lints:`.
 *
 * Mirrors the Dart parser `parseScalarFromPluginBlock`
 * (`lib/src/config/runtime_tier_cap.dart`): indentation-scoped, comment- and
 * blank-line tolerant. Kept deliberately small — a full YAML parse of the
 * consumer's options file on every save is disproportionate, and the only key
 * read here is a single scalar.
 */
const SAROPA_BLOCK_HEADER = /^\s+saropa_lints:\s*(?:#.*)?$/;
const LANE_KEY = /^\s*lane:\s*([^\s#]+)/;

/** Leading-space count, for indentation-scoped block detection. */
function leadingSpaces(line: string): number {
  return line.length - line.trimStart().length;
}

/**
 * Reads `lane:` from the plugin block of [content]. Returns the raw
 * lower-cased value, or undefined when the key is absent.
 *
 * Exported for unit testing without a workspace on disk.
 */
export function parseLaneFromPluginBlock(content: string): string | undefined {
  const lines = content.replace(/\r\n?/g, '\n').split('\n');
  for (let i = 0; i < lines.length; i++) {
    if (!SAROPA_BLOCK_HEADER.test(lines[i].trimEnd())) continue;
    const baseIndent = leadingSpaces(lines[i]);
    for (let j = i + 1; j < lines.length; j++) {
      const inner = lines[j];
      const trimmed = inner.trimStart();
      // Blanks and comments do not end the block; a commented-out key must
      // not stop the search for a live one below it.
      if (trimmed === '' || trimmed.startsWith('#')) continue;
      // Dedent to or past `saropa_lints:` means the block ended.
      if (leadingSpaces(inner) <= baseIndent) break;
      const match = LANE_KEY.exec(inner);
      if (match) {
        return match[1].trim().replace(/^['"]|['"]$/g, '').toLowerCase();
      }
    }
  }
  return undefined;
}

/**
 * True when [root]'s `analysis_options.yaml` configures the light lane.
 *
 * An absent/unrecognized `lane:` key reads as light — `light` is now the
 * Dart-side default (see `RuleLane` in `lib/src/config/rule_lane.dart`), so
 * this must agree or the two sides disagree about what the in-process plugin
 * is doing whenever a project just uncomments the plugin block without
 * writing an explicit `lane:` value. Safety does not depend on getting this
 * exactly right: an unreachable/disabled plugin block still reads `light`
 * here, but [resolveExcludeLane] additionally requires [pluginIsLive] before
 * ever excluding anything, so a disabled or unresponsive plugin still gets a
 * full scan regardless of this function's answer. An unreadable file reads
 * as "not light" (fails toward scanning everything).
 */
export function projectConfiguresLightLane(root: string): boolean {
  try {
    const yamlPath = path.join(root, 'analysis_options.yaml');
    const content = fs.readFileSync(yamlPath, 'utf8');
    const value = parseLaneFromPluginBlock(content);
    return value === undefined || value === 'light';
  } catch {
    return false;
  }
}

/**
 * How long a liveness verdict is reused before re-reading the plugin's report
 * file. Save-triggered scans can arrive every couple of seconds; re-running
 * the liveness check (which stats and parses a report file) on each one is
 * wasted I/O, while a stale-by-30s verdict cannot hide findings for longer
 * than one scan cycle.
 */
const LIVENESS_CACHE_MS = 30_000;

let cachedLiveness: { root: string; alive: boolean; at: number } | undefined;

/**
 * True when the in-process plugin is currently proving it runs — i.e.
 * `verifyPluginLiveness` reports `alive`. Cached per root for
 * {@link LIVENESS_CACHE_MS}.
 *
 * [now] is injectable so tests can drive cache expiry without waiting.
 */
export function pluginIsLive(root: string, now: number = Date.now()): boolean {
  const cached = cachedLiveness;
  if (cached && cached.root === root && now - cached.at < LIVENESS_CACHE_MS) {
    return cached.alive;
  }
  let alive = false;
  try {
    alive = verifyPluginLiveness(root).status === 'alive';
  } catch {
    // A liveness check that throws is not evidence of life. Fail toward
    // scanning everything.
    alive = false;
  }
  cachedLiveness = { root, alive, at: now };
  return alive;
}

/** Drops the cached liveness verdict. Called when the daemon is restarted. */
export function resetLivenessCache(): void {
  cachedLiveness = undefined;
}

/**
 * The `excludeLane` value to send with a scan request: `'light'` only when the
 * project configures the light lane AND the plugin is verifiably reporting;
 * otherwise undefined (scan everything).
 */
export function resolveExcludeLane(root: string): 'light' | undefined {
  if (!projectConfiguresLightLane(root)) return undefined;
  if (!pluginIsLive(root)) return undefined;
  return 'light';
}
