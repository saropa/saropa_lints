/**
 * Tuning for the LIVE analyzer plugin (the in-process lint engine inside the
 * Dart analysis server), as opposed to scans, which run in their own
 * processes.
 *
 * The plugin already guards itself (a hard RSS cap, panic threshold, and
 * opt-in graduated rule shedding), but those controls were only reachable
 * through an env var or hand-editing YAML. This module makes them a
 * one-click, machine-aware recommendation:
 *
 *  - `max_rss_mb` — the hard memory cap for live analysis.
 *  - `shed_rules: true` — degrade gracefully (drop expensive, then low-severity
 *    rules) instead of hitting the cliff where every rule pauses.
 *
 * The decision logic and the YAML edit are pure and unit-tested; only
 * {@link applyPluginMemoryConfig} touches the file system.
 */
import type { MachineSnapshot } from './machineResources';
import type { PerformanceProfile } from './scanResourceSettings';

/** Bounds for the recommended cap, in MB. Mirrors the plugin's own floor. */
export const MIN_RECOMMENDED_RSS_MB = 1536;
export const MAX_RECOMMENDED_RSS_MB = 4096;
/** Fraction of physical RAM the live plugin is recommended to stay under. */
export const PLUGIN_RAM_FRACTION = 0.35;
/** Machines at or under these are "small" and get a proactive offer. */
export const SMALL_MACHINE_TOTAL_MB = 8 * 1024;
export const SMALL_MACHINE_CORES = 4;

export interface PluginMemoryRecommendation {
  /** Hard cap for the live plugin, in MB. */
  readonly maxRssMb: number;
  /** Enable graceful rule shedding under memory pressure. */
  readonly shedRules: true;
}

/** Rounds [value] to the nearest [step] and clamps into [min, max]. */
function clampRound(value: number, min: number, max: number, step: number): number {
  const rounded = Math.round(value / step) * step;
  return Math.min(max, Math.max(min, rounded));
}

/** The recommended live-analysis memory cap for [machine]. */
export function recommendedPluginRssMb(machine: MachineSnapshot): number {
  return clampRound(
    machine.totalMb * PLUGIN_RAM_FRACTION,
    MIN_RECOMMENDED_RSS_MB,
    MAX_RECOMMENDED_RSS_MB,
    256,
  );
}

/**
 * What to recommend for live analysis given the chosen profile: only the
 * gentle profile asks for tighter limits. Balanced and fast leave the plugin
 * on its adaptive defaults (60% of RAM, no shedding), which is right for
 * machines with room.
 */
export function recommendPluginMemory(
  profile: PerformanceProfile,
  machine: MachineSnapshot,
): PluginMemoryRecommendation | null {
  if (profile !== 'gentle') return null;
  return { maxRssMb: recommendedPluginRssMb(machine), shedRules: true };
}

/** True when [key] is set (uncommented) at the top level of [content]. */
export function hasActiveKey(content: string, key: string): boolean {
  return new RegExp(`^${key}\\s*:`, 'm').test(content);
}

/** Whether the machine is small enough to warrant a proactive offer. */
export function isSmallMachine(machine: MachineSnapshot): boolean {
  return machine.totalMb <= SMALL_MACHINE_TOTAL_MB || machine.cores <= SMALL_MACHINE_CORES;
}

/**
 * Whether to proactively offer live-analysis limits: only on a small machine
 * whose config sets neither knob yet (the user's explicit choice, including
 * `shed_rules: false`, is never second-guessed).
 */
export function shouldOfferSmallMachineTuning(
  machine: MachineSnapshot,
  customConfig: string,
): PluginMemoryRecommendation | null {
  if (!isSmallMachine(machine)) return null;
  if (hasActiveKey(customConfig, 'max_rss_mb') || hasActiveKey(customConfig, 'shed_rules')) {
    return null;
  }
  return { maxRssMb: recommendedPluginRssMb(machine), shedRules: true };
}

/**
 * Sets a top-level `key: value` in YAML [content]. An existing line —
 * active or commented out (the placeholder `init` writes) — is replaced in
 * place; otherwise the key is appended. Never touches other lines.
 */
export function upsertTopLevelKey(
  content: string,
  key: string,
  value: string | number | boolean,
): string {
  const line = `${key}: ${String(value)}`;
  const pattern = new RegExp(`^[# ]*${key}\\s*:.*$`, 'm');
  if (pattern.test(content)) return content.replace(pattern, line);
  const separator = content.length === 0 || content.endsWith('\n') ? '' : '\n';
  return `${content}${separator}${line}\n`;
}

/** Applies [rec] to YAML [content]. */
export function applyRecommendationToContent(
  content: string,
  rec: PluginMemoryRecommendation,
): string {
  let updated = upsertTopLevelKey(content, 'shed_rules', rec.shedRules);
  updated = upsertTopLevelKey(updated, 'max_rss_mb', rec.maxRssMb);
  return updated;
}
