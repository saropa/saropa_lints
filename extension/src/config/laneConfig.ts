/**
 * Decides whether a scan request may skip the "light lane" rules — those the
 * in-process analyzer plugin runs itself when the project is configured with
 * `lane: light` in `analysis_options_custom.yaml`.
 *
 * See `plans/PLAN_two_lane_daemon_architecture.md`. The Dart-side definition
 * of which rules those are lives in `lib/src/config/rule_lane.dart`; this
 * module never enumerates rules, it only answers "is the in-process lane
 * genuinely covering them right now?".
 *
 * `lane:` lives in the custom file (not under `plugins > saropa_lints:` in
 * `analysis_options.yaml`) to avoid `unsupported_option` warnings from the
 * Dart SDK's plugin-block validator, which hardcodes the allowed key set.
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

/** Matches a top-level `lane: <value>` in `analysis_options_custom.yaml`. */
const LANE_KEY = /^lane:\s*([^\s#]+)/m;

/**
 * Reads `lane:` as a top-level key from [content]. Returns the raw
 * lower-cased value, or undefined when the key is absent.
 *
 * Exported for unit testing without a workspace on disk.
 */
export function parseLaneFromCustomConfig(content: string): string | undefined {
  const match = LANE_KEY.exec(content);
  if (!match) return undefined;
  return match[1].trim().replace(/^['"]|['"]$/g, '').toLowerCase();
}

/** Counts leading whitespace (spaces and tabs) — mirrors Dart's `_leadingWhitespace`. */
function leadingWhitespace(value: string): number {
  let count = 0;
  while (count < value.length && (value[count] === ' ' || value[count] === '\t')) count++;
  return count;
}

/**
 * Deprecation fallback: reads `lane:` from the old `plugins > saropa_lints:`
 * block in `analysis_options.yaml`. Returns the raw lower-cased value, or
 * undefined when the key is absent.
 *
 * Mirrors Dart's `parseScalarFromPluginBlock(mainOptions, {'lane'})` in
 * `config_loader.dart` — projects that haven't migrated their `lane:` key
 * to `analysis_options_custom.yaml` still get the correct UI display.
 */
export function parseLaneFromPluginBlock(content: string): string | undefined {
  const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].replace(/\s+$/, '');
    if (!/^\s+saropa_lints:\s*(#.*)?$/.test(trimmed)) continue;
    const baseIndent = leadingWhitespace(lines[i]);
    for (let j = i + 1; j < lines.length; j++) {
      const inner = lines[j];
      const t = inner.replace(/^\s+/, '');
      if (t.length === 0 || t.startsWith('#')) continue;
      const ind = leadingWhitespace(inner);
      // Dedent to or past the `saropa_lints:` key means the block ended.
      if (ind <= baseIndent) break;
      const m = /^\s*lane:\s*([^\s#]+)/.exec(inner);
      if (m) {
        const v = m[1]?.trim();
        if (!v) continue;
        return v.replace(/^['"]|['"]$/g, '').toLowerCase();
      }
    }
  }
  return undefined;
}

/**
 * Reads the raw `lane:` value from [root]'s `analysis_options_custom.yaml`,
 * or `undefined` when the key is absent or the file cannot be read.
 *
 * Falls back to the old `plugins > saropa_lints: lane:` location in
 * `analysis_options.yaml` for unmigrated projects — mirrors the Dart
 * deprecation fallback in `_readWithDeprecationFallback`.
 *
 * Exposed separately from {@link projectConfiguresLightLane} (which collapses
 * absent/unrecognized values into a boolean) because the lane-picker UI needs
 * to distinguish "explicitly full", "explicitly light", and "not configured
 * yet" to render an accurate "current" marker.
 */
export function readRawLaneFromCustomConfig(root: string): string | undefined {
  // Primary: top-level key in custom config file.
  try {
    const yamlPath = path.join(root, 'analysis_options_custom.yaml');
    const content = fs.readFileSync(yamlPath, 'utf8');
    const value = parseLaneFromCustomConfig(content);
    if (value !== undefined) return value;
  } catch {
    // Custom file missing or unreadable — fall through to legacy check.
  }

  // Deprecation fallback: old plugin-block location in main file.
  try {
    const mainPath = path.join(root, 'analysis_options.yaml');
    const mainContent = fs.readFileSync(mainPath, 'utf8');
    return parseLaneFromPluginBlock(mainContent);
  } catch {
    return undefined;
  }
}

/** Values {@link writeLaneToCustomConfig} accepts — mirrors `RuleLane` in `lib/src/config/rule_lane.dart`. */
export type RuleLaneValue = 'light' | 'full';

/** Outcome of a {@link writeLaneToCustomConfig} call. */
export type WriteLaneResult =
  | { ok: true }
  | { ok: false; reason: 'no-file' | 'write-error'; message?: string };

/**
 * Writes `lane: <value>` into [root]'s `analysis_options_custom.yaml` as a
 * top-level key.
 *
 * Moved from `analysis_options.yaml` (under `plugins > saropa_lints:`) to
 * avoid `unsupported_option` warnings from the Dart SDK's plugin-block
 * validator, which hardcodes the allowed key set.
 *
 * Minimal-diff by design: if a live `lane:` line already exists, only its
 * value token is replaced — the trailing `# comment` is preserved verbatim.
 * Otherwise the key is appended after the `# ANALYSIS SETTINGS` section.
 *
 * Requires the custom file to exist (created by `dart run saropa_lints init`).
 */
export function writeLaneToCustomConfig(root: string, lane: RuleLaneValue): WriteLaneResult {
  const yamlPath = path.join(root, 'analysis_options_custom.yaml');
  let content: string;
  try {
    content = fs.readFileSync(yamlPath, 'utf8');
  } catch {
    return { ok: false, reason: 'no-file' };
  }

  // Preserve the file's original line ending style.
  const usesCRLF = content.includes('\r\n');
  const lines = content.replace(/\r\n?/g, '\n').split('\n');

  // Find an existing live `lane:` line (top-level, not commented).
  let liveLaneIndex = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/^lane:\s*[^\s#]/.test(lines[i])) {
      liveLaneIndex = i;
      break;
    }
  }

  if (liveLaneIndex !== -1) {
    // Replace only the value token; keep any trailing `# comment`.
    const parts = /^(lane:\s*)([^\s#]+)(.*)$/.exec(lines[liveLaneIndex]);
    lines[liveLaneIndex] = parts ? `${parts[1]}${lane}${parts[3]}` : `lane: ${lane}`;
  } else {
    // No live key yet — find `output:` or `log_level:` (siblings in the
    // ANALYSIS SETTINGS section) and insert after the last match. Falls
    // back to appending at end of file when neither anchor is present.
    let insertAt = lines.length;
    for (let i = 0; i < lines.length; i++) {
      if (/^output:\s?/.test(lines[i]) || /^log_level:\s?/.test(lines[i])) {
        insertAt = i + 1;
      }
    }
    lines.splice(insertAt, 0, `lane: ${lane}`);
  }

  try {
    fs.writeFileSync(yamlPath, lines.join(usesCRLF ? '\r\n' : '\n'), 'utf8');
  } catch (err) {
    return { ok: false, reason: 'write-error', message: err instanceof Error ? err.message : String(err) };
  }
  return { ok: true };
}

/**
 * True when [root]'s `analysis_options_custom.yaml` configures the light lane.
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
    const yamlPath = path.join(root, 'analysis_options_custom.yaml');
    const content = fs.readFileSync(yamlPath, 'utf8');
    const value = parseLaneFromCustomConfig(content);
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
