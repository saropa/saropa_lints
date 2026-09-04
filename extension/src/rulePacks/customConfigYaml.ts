/**
 * Read/write the 8 top-level `analysis_options_custom.yaml` keys that had no UI before
 * Phase 4 of the extension UI redesign (PLAN_extension_ui_redesign.md §2.2 "Config file" tab):
 * `max_issues`, `output`, `platforms`, `severities`, `banned_usage`, `saropa_tier`,
 * `runtime_tier`, `diagnostic_statistics`.
 *
 * WHY a dedicated module instead of extending `configWriter.ts` in place: `configWriter.ts`
 * owns exactly one section (RULE OVERRIDES) and its regexes are scoped to that marker. Mixing
 * eight more independent top-level keys into the same file would make every regex's "where does
 * this section end" boundary harder to reason about. Splitting per-concern keeps each writer's
 * blast radius to its own key.
 *
 * WHY line-scanning instead of a full YAML AST library: this mirrors the Dart-side parser
 * (`lib/src/native/config_loader.dart`, `lib/src/init/custom_overrides_core.dart`) byte-for-byte
 * in shape — both sides agree on "a top-level key's block runs from its `key:` line to the next
 * line at column 0 that starts a new top-level key (or EOF)". A generic YAML library would parse
 * correctly but re-serialize the WHOLE file (reordering keys, losing the "DO NOT EDIT" banner
 * comment, normalizing quote style) — exactly the "regex-based edits corrupt the file on comments
 * and key ordering" failure this module exists to avoid. Every writer below touches only the
 * bytes of the one block it owns, exactly like `writeRulePacksEnabled` in `rulePackYaml.ts`.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import { FLUTTER_EMBEDDER_PLATFORMS } from '../pubspecReader';

const CUSTOM_FILENAME = 'analysis_options_custom.yaml';

/**
 * The single source of truth for "which top-level `analysis_options_custom.yaml` keys does this
 * module know how to read/write". Phase 4's coverage guard
 * (`extension/src/test/rulePacks/configFileCardCoverage.test.ts`) asserts every key here maps to
 * a rendered Config file tab card — so a 9th key added to this array without also wiring a card
 * in `rulePacksWebviewProvider.ts`'s `CONFIG_FILE_KEY_TO_CARD` fails that test instead of silently
 * shipping with no UI, which is exactly the "invisible setting" failure mode this whole dashboard
 * exists to close off (see PLAN_extension_ui_redesign.md §1 principle 4).
 */
export const CUSTOM_YAML_TOP_LEVEL_KEYS = [
  'max_issues',
  'output',
  'platforms',
  'severities',
  'banned_usage',
  'saropa_tier',
  'runtime_tier',
  'diagnostic_statistics',
] as const;
export type CustomYamlTopLevelKey = (typeof CUSTOM_YAML_TOP_LEVEL_KEYS)[number];

/** Valid severity override values (mirrors `DiagnosticSeverity` in config_loader.dart). */
export const SEVERITY_LEVELS = ['ERROR', 'WARNING', 'INFO', 'false'] as const;
export type SeverityLevel = (typeof SEVERITY_LEVELS)[number];

/** Valid `output:` scalar values (config_loader.dart `_loadOutputConfig`). */
export const OUTPUT_MODES = ['terminal', 'file', 'both'] as const;

/** The five cumulative tiers, for `saropa_tier:` / `runtime_tier:` selects. */
export const CUSTOM_YAML_TIERS = [
  'essential',
  'recommended',
  'professional',
  'comprehensive',
  'pedantic',
] as const;

function customFilePath(root: string): string {
  return path.join(root, CUSTOM_FILENAME);
}

function readFileOrEmpty(root: string): string {
  const p = customFilePath(root);
  if (!fs.existsSync(p)) return '';
  // Normalize line endings up front so every regex below (all authored against `\n`) works
  // identically on a Windows-authored file with `\r\n` line endings.
  return fs.readFileSync(p, 'utf-8').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}

function writeFile(root: string, content: string): boolean {
  try {
    fs.writeFileSync(customFilePath(root), content, 'utf-8');
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Scalars: max_issues, output, saropa_tier, runtime_tier
// ---------------------------------------------------------------------------

/** Reads a single top-level `key: value` scalar line. Returns undefined when absent. */
export function readScalarKey(root: string, key: string): string | undefined {
  const content = readFileOrEmpty(root);
  const pattern = new RegExp(`^${key}:\\s*(\\S.*?)\\s*$`, 'm');
  const match = pattern.exec(content);
  if (!match) return undefined;
  // Strip a trailing inline comment (`# ...`) and surrounding quotes, matching how the
  // Dart-side scalar readers treat `key: value # comment` throughout config_loader.dart.
  const raw = match[1].replace(/\s+#.*$/, '').trim();
  if ((raw.startsWith('"') && raw.endsWith('"')) || (raw.startsWith("'") && raw.endsWith("'"))) {
    return raw.slice(1, -1);
  }
  return raw;
}

/**
 * Writes (or removes, when `value` is undefined) a single top-level scalar line.
 * Preserves the rest of the file untouched — replaces the existing line in place when present,
 * otherwise appends a new line before the RULE OVERRIDES section (or at EOF if that section is
 * itself absent, e.g. a freshly-created file), matching the insertion point `rulePackYaml.ts`
 * already uses for `rule_packs:` so all Phase-4-added keys land in the same neighborhood.
 */
export function writeScalarKey(root: string, key: string, value: string | undefined): boolean {
  let content = readFileOrEmpty(root);
  const linePattern = new RegExp(`^${key}:.*$`, 'm');
  if (value === undefined) {
    if (linePattern.test(content)) {
      content = content.replace(linePattern, '').replace(/\n{3,}/g, '\n\n');
    }
    return writeFile(root, content);
  }
  const line = `${key}: ${value}`;
  if (linePattern.test(content)) {
    content = content.replace(linePattern, line);
  } else {
    const overridesMarker = '# RULE OVERRIDES';
    const idx = content.indexOf(overridesMarker);
    if (idx >= 0) {
      content = content.slice(0, idx) + line + '\n\n' + content.slice(idx);
    } else {
      content = content.trimEnd() + (content.trim().length > 0 ? '\n' : '') + line + '\n';
    }
  }
  return writeFile(root, content);
}

// ---------------------------------------------------------------------------
// platforms: map of platform name -> boolean
// ---------------------------------------------------------------------------

/** Reads the `platforms:` block. Defaults every known platform to `false` when the block is absent — mirrors `tiers.defaultPlatforms` conservatively (the extension has no pubspec-detection fallback the Dart init CLI has, so an absent block means "nothing declared" rather than "ios/android on"). */
export function readPlatforms(root: string): Map<string, boolean> {
  const result = new Map<string, boolean>();
  for (const p of FLUTTER_EMBEDDER_PLATFORMS) result.set(p, false);
  const content = readFileOrEmpty(root);
  const sectionMatch = /^platforms:\s*$/m.exec(content);
  if (!sectionMatch) return result;
  const lines = content.slice(sectionMatch.index + sectionMatch[0].length).split('\n');
  for (const line of lines) {
    if (line.trim() === '' || line.trimStart().startsWith('#')) continue;
    if (!line.startsWith('  ')) break; // dedent ends the block, same convention as every other reader here
    const m = /^\s*([\w-]+):\s*(true|false)/.exec(line);
    if (m) result.set(m[1], m[2] === 'true');
  }
  return result;
}

/**
 * Rewrites the whole `platforms:` block from a full map (the UI renders one checkbox per known
 * platform, so a "save" always supplies the complete set — there is no partial-update case to
 * support, unlike severities/banned_usage which grow by user-added rows).
 */
export function writePlatforms(root: string, platforms: ReadonlyMap<string, boolean>): boolean {
  let content = readFileOrEmpty(root);
  const blockPattern = /^platforms:\s*\n(?:[ \t]+\S[^\n]*\n|\s*\n)*/m;
  const body = [...platforms.entries()]
    .map(([name, on]) => `  ${name}: ${on}`)
    .join('\n');
  const block = `platforms:\n${body}\n`;
  if (blockPattern.test(content)) {
    content = content.replace(blockPattern, block);
  } else {
    content = content.trimEnd() + '\n\n' + block;
  }
  return writeFile(root, content);
}

// ---------------------------------------------------------------------------
// severities: map of rule -> ERROR|WARNING|INFO|false
// ---------------------------------------------------------------------------

export interface SeverityEntry {
  rule: string;
  level: SeverityLevel;
}

/** Reads every `severities:` entry, in file order. */
export function readSeverities(root: string): SeverityEntry[] {
  const content = readFileOrEmpty(root);
  const sectionMatch = /^severities:\s*$/m.exec(content);
  if (!sectionMatch) return [];
  const entries: SeverityEntry[] = [];
  const lines = content.slice(sectionMatch.index + sectionMatch[0].length).split('\n');
  for (const line of lines) {
    if (line.trim() === '' || line.trimStart().startsWith('#')) continue;
    if (!line.startsWith('  ')) break;
    const m = /^\s*([\w.]+):\s*(\S+)/.exec(line);
    if (!m) continue;
    const raw = m[2].toUpperCase();
    // Only ERROR/WARNING/INFO/false are meaningful to the Dart-side parser (config_loader.dart
    // `_loadSeverityOverrides`); anything else is a malformed line the UI should not surface.
    const level: SeverityLevel | undefined =
      raw === 'ERROR' || raw === 'WARNING' || raw === 'INFO' ? (raw as SeverityLevel) : raw === 'FALSE' ? 'false' : undefined;
    if (level) entries.push({ rule: m[1], level });
  }
  return entries;
}

/** Sets (or updates in place) one rule's severity override, creating the `severities:` block if absent. */
export function writeSeverityEntry(root: string, rule: string, level: SeverityLevel): boolean {
  let content = readFileOrEmpty(root);
  const value = level === 'false' ? 'false' : level;
  if (!/^severities:\s*$/m.test(content)) {
    content = content.trimEnd() + `\n\nseverities:\n  ${rule}: ${value}\n`;
    return writeFile(root, content);
  }
  const entryPattern = new RegExp(`^(\\s*${rule}:\\s*)\\S+`, 'm');
  const sectionMatch = /^severities:\s*$/m.exec(content)!;
  const before = content.slice(0, sectionMatch.index);
  let section = content.slice(sectionMatch.index);
  // Only rewrite an existing entry within the severities block's own text — otherwise a rule
  // name that happens to also appear as a RULE OVERRIDES key elsewhere could be matched instead.
  const blockEnd = findTopLevelBlockEnd(section, 'severities');
  const block = section.slice(0, blockEnd);
  const rest = section.slice(blockEnd);
  const updatedBlock = entryPattern.test(block)
    ? block.replace(entryPattern, `$1${value}`)
    : block.trimEnd() + `\n  ${rule}: ${value}\n`;
  section = updatedBlock + rest;
  return writeFile(root, before + section);
}

/** Removes one rule's severity override (reverts to tier/pack default). */
export function removeSeverityEntry(root: string, rule: string): boolean {
  const content = readFileOrEmpty(root);
  const sectionMatch = /^severities:\s*$/m.exec(content);
  if (!sectionMatch) return true; // nothing to remove
  const before = content.slice(0, sectionMatch.index);
  const section = content.slice(sectionMatch.index);
  const blockEnd = findTopLevelBlockEnd(section, 'severities');
  const block = section.slice(0, blockEnd);
  const rest = section.slice(blockEnd);
  const linePattern = new RegExp(`^\\s*${rule}:\\s*\\S+.*\\n?`, 'm');
  const updatedBlock = block.replace(linePattern, '');
  return writeFile(root, before + updatedBlock + rest);
}

/** Finds where a top-level `key:` block ends: the first line back at column 0 that is not blank/comment, or EOF. */
function findTopLevelBlockEnd(sectionText: string, key: string): number {
  const lines = sectionText.split('\n');
  let offset = lines[0].length + 1; // skip the `key:` line itself
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i];
    if (line.trim() === '' || line.trimStart().startsWith('#')) {
      offset += line.length + 1;
      continue;
    }
    if (!line.startsWith(' ') && !line.startsWith('\t')) {
      // Back at column 0 with real content — this is the next top-level key.
      return offset;
    }
    offset += line.length + 1;
  }
  return sectionText.length;
}

// ---------------------------------------------------------------------------
// banned_usage: entries: [{identifier, reason}]
// ---------------------------------------------------------------------------

export interface BannedUsageEntry {
  identifier: string;
  reason: string;
}

/** Reads every `banned_usage.entries` item (mirrors `loadBannedUsageConfig` in banned_usage_config.dart). */
export function readBannedUsage(root: string): BannedUsageEntry[] {
  const content = readFileOrEmpty(root);
  const sectionMatch = /^banned_usage:\s*$/m.exec(content);
  if (!sectionMatch) return [];
  const afterSection = content.slice(sectionMatch.index + sectionMatch[0].length);
  const entriesMatch = /^\s+entries:\s*$/m.exec(afterSection);
  if (!entriesMatch) return [];
  const lines = afterSection.slice(entriesMatch.index + entriesMatch[0].length).split('\n');
  const result: BannedUsageEntry[] = [];
  let current: Partial<BannedUsageEntry> | null = null;
  for (const line of lines) {
    if (line.trim() === '' || line.trimStart().startsWith('#')) continue;
    if (!line.startsWith('  ')) break; // dedent past the entries block
    const idMatch = /^\s*-\s*identifier:\s*["']?([^"'\s]+)["']?\s*$/.exec(line);
    if (idMatch) {
      if (current?.identifier) result.push({ identifier: current.identifier, reason: current.reason ?? '' });
      current = { identifier: idMatch[1] };
      continue;
    }
    const reasonMatch = /^\s+reason:\s*["']?(.+?)["']?\s*$/.exec(line);
    if (reasonMatch && current) {
      current.reason = reasonMatch[1];
    }
  }
  if (current?.identifier) result.push({ identifier: current.identifier, reason: current.reason ?? '' });
  return result;
}

/** Rewrites the entire `banned_usage.entries` list from the full set — same "small list, full replace" rationale as `writePlatforms`. */
export function writeBannedUsage(root: string, entries: readonly BannedUsageEntry[]): boolean {
  let content = readFileOrEmpty(root);
  const blockPattern = /^banned_usage:\s*\n(?:[ \t]+\S[^\n]*\n|\s*\n)*/m;
  const body = entries
    .map((e) => `    - identifier: '${e.identifier.replace(/'/g, "''")}'\n      reason: '${e.reason.replace(/'/g, "''")}'`)
    .join('\n');
  const block = entries.length === 0 ? '' : `banned_usage:\n  entries:\n${body}\n`;
  if (blockPattern.test(content)) {
    content = content.replace(blockPattern, block);
  } else if (block) {
    content = content.trimEnd() + '\n\n' + block;
  }
  return writeFile(root, content);
}

// ---------------------------------------------------------------------------
// diagnostic_statistics: thresholds: { rule: { warn?, fail? } }
// ---------------------------------------------------------------------------

export interface DiagnosticThreshold {
  rule: string;
  warn?: number;
  fail?: number;
}

/** Reads every `diagnostic_statistics.thresholds` entry (mirrors `_loadDiagnosticStatisticsConfig`). */
export function readDiagnosticThresholds(root: string): DiagnosticThreshold[] {
  const content = readFileOrEmpty(root);
  const sectionMatch = /^diagnostic_statistics:\s*$/m.exec(content);
  if (!sectionMatch) return [];
  const lines = content.slice(sectionMatch.index + sectionMatch[0].length).split('\n');
  const result: DiagnosticThreshold[] = [];
  let inThresholds = false;
  let current: DiagnosticThreshold | null = null;
  for (const line of lines) {
    if (line.trim() === '' || line.trimStart().startsWith('#')) continue;
    if (!line.startsWith('  ')) break;
    if (/^\s{2}thresholds:\s*$/.test(line)) {
      inThresholds = true;
      continue;
    }
    if (/^\s{2}baseline:\s*$/.test(line)) {
      inThresholds = false;
      continue;
    }
    if (!inThresholds) continue;
    const ruleMatch = /^\s{4}([\w_.-]+):\s*$/.exec(line);
    if (ruleMatch) {
      if (current) result.push(current);
      current = { rule: ruleMatch[1] };
      continue;
    }
    const thresholdMatch = /^\s{6}(warn|fail):\s*(\d+)\s*$/.exec(line);
    if (thresholdMatch && current) {
      if (thresholdMatch[1] === 'warn') current.warn = Number(thresholdMatch[2]);
      else current.fail = Number(thresholdMatch[2]);
    }
  }
  if (current) result.push(current);
  return result;
}

/** Reads the optional `diagnostic_statistics.baseline.file` path. */
export function readDiagnosticStatisticsBaselineFile(root: string): string | undefined {
  const content = readFileOrEmpty(root);
  const sectionMatch = /^diagnostic_statistics:\s*$/m.exec(content);
  if (!sectionMatch) return undefined;
  const lines = content.slice(sectionMatch.index + sectionMatch[0].length).split('\n');
  let inBaseline = false;
  for (const line of lines) {
    if (line.trim() === '' || line.trimStart().startsWith('#')) continue;
    if (!line.startsWith('  ')) break;
    if (/^\s{2}baseline:\s*$/.test(line)) {
      inBaseline = true;
      continue;
    }
    if (/^\s{2}\S/.test(line)) inBaseline = false;
    if (inBaseline) {
      const m = /^\s{4}file:\s*["']?(.+?)["']?\s*$/.exec(line);
      if (m) return m[1];
    }
  }
  return undefined;
}

/** Rewrites the whole `diagnostic_statistics.thresholds` map from the full set — same rationale as `writePlatforms`. Preserves `baseline:` (read separately, written only via {@link writeDiagnosticStatisticsBaselineFile}) by keeping it out of the replaced block when present. */
export function writeDiagnosticThresholds(root: string, thresholds: readonly DiagnosticThreshold[]): boolean {
  let content = readFileOrEmpty(root);
  const sectionPattern = /^diagnostic_statistics:\s*\n(?:[ \t]+\S[^\n]*\n|\s*\n)*/m;
  const existingBaselineFile = readDiagnosticStatisticsBaselineFile(root);
  const thresholdsBody = thresholds
    .map((t) => {
      const lines = [`    ${t.rule}:`];
      if (t.warn !== undefined) lines.push(`      warn: ${t.warn}`);
      if (t.fail !== undefined) lines.push(`      fail: ${t.fail}`);
      return lines.join('\n');
    })
    .join('\n');
  const baselineBlock = existingBaselineFile
    ? `  baseline:\n    file: ${existingBaselineFile}\n`
    : '';
  const block =
    thresholds.length === 0 && !existingBaselineFile
      ? ''
      : `diagnostic_statistics:\n${thresholds.length > 0 ? `  thresholds:\n${thresholdsBody}\n` : ''}${baselineBlock}`;
  if (sectionPattern.test(content)) {
    content = content.replace(sectionPattern, block);
  } else if (block) {
    content = content.trimEnd() + '\n\n' + block;
  }
  return writeFile(root, content);
}

/** Sets the `diagnostic_statistics.baseline.file` path, preserving existing thresholds. */
export function writeDiagnosticStatisticsBaselineFile(root: string, filePath: string | undefined): boolean {
  const thresholds = readDiagnosticThresholds(root);
  let content = readFileOrEmpty(root);
  const sectionPattern = /^diagnostic_statistics:\s*\n(?:[ \t]+\S[^\n]*\n|\s*\n)*/m;
  const thresholdsBody = thresholds
    .map((t) => {
      const lines = [`    ${t.rule}:`];
      if (t.warn !== undefined) lines.push(`      warn: ${t.warn}`);
      if (t.fail !== undefined) lines.push(`      fail: ${t.fail}`);
      return lines.join('\n');
    })
    .join('\n');
  const baselineBlock = filePath ? `  baseline:\n    file: ${filePath}\n` : '';
  const block =
    thresholds.length === 0 && !filePath
      ? ''
      : `diagnostic_statistics:\n${thresholds.length > 0 ? `  thresholds:\n${thresholdsBody}\n` : ''}${baselineBlock}`;
  if (sectionPattern.test(content)) {
    content = content.replace(sectionPattern, block);
  } else if (block) {
    content = content.trimEnd() + '\n\n' + block;
  }
  return writeFile(root, content);
}
