/**
 * Pure helpers for the accepted-findings lists (`saropa_accepted.yaml` beside
 * each package's `pubspec.yaml`): finding which list applies to a file, reading the scan CLI's `--check-accepted --format json`
 * output, building a list entry, and appending it to the file text.
 *
 * No `vscode` import, so the logic is unit-tested without the editor. The
 * VS Code wiring lives in `accepted-findings-commands.ts`; the list's
 * parsing, matching and stale rules live once in Dart
 * (`lib/src/accepted/`), which the CLI applies.
 */
import * as path from 'node:path';

/** File name of the list. Mirrors `kAcceptedFindingsFileName` in Dart. */
export const ACCEPTED_FILE_NAME = 'saropa_accepted.yaml';

/** Entry kinds the Dart parser accepts (`kAcceptedKinds`). */
export type AcceptedKind = 'accepted' | 'false_positive';

/** Per-entry verdict, matching Dart's `AcceptedEntryState` names. */
export type AcceptedEntryState = 'active' | 'staleFileMissing' | 'staleNoFinding' | 'notChecked';

/** One entry in the check JSON. */
export interface AcceptedCheckEntry {
  rule: string;
  file: string;
  kind: AcceptedKind | null;
  reason: string;
  line: number;
  state: AcceptedEntryState;
  hiddenCount: number;
  /** The entry's `max:` count; null or absent means unlimited. */
  max?: number | null;
  /** Findings reported again because `max` was reached. */
  aboveMaxCount?: number;
}

/** One invalid entry or parse failure in the check JSON. */
export interface AcceptedCheckProblem {
  line: number;
  message: string;
}

/** Counts reported per list and as totals. */
export interface AcceptedCheckSummary {
  entryCount: number;
  active: number;
  stale: number;
  notChecked: number;
  problemCount: number;
  hiddenTotal: number;
  /** Absent in JSON from a package version without `max:`. */
  aboveMaxTotal?: number;
}

/**
 * One list file in the check JSON. The CLI reports one per package under the
 * scan target, because each file is matched against the list beside its own
 * nearest `pubspec.yaml`.
 */
export interface AcceptedCheckList {
  listPath: string;
  projectRoot: string;
  entries: AcceptedCheckEntry[];
  problems: AcceptedCheckProblem[];
  summary: AcceptedCheckSummary;
}

/**
 * Top-level JSON from `scan --check-accepted --format json` (version 2). An
 * empty `lists` means no list exists under the scanned folder.
 */
export interface AcceptedCheckResult {
  version: number;
  lists: AcceptedCheckList[];
  summary: AcceptedCheckSummary & { listCount: number };
}

/**
 * Parses the check JSON, or returns null when it is not the expected shape.
 * A null result is surfaced as an error by the caller, never as "clean", so
 * a broken run cannot pass for a healthy list.
 */
export function parseAcceptedCheckJson(raw: string): AcceptedCheckResult | null {
  try {
    const parsed = JSON.parse(raw) as Partial<AcceptedCheckResult>;
    if (!Array.isArray(parsed.lists) || !parsed.summary) return null;
    // Every list must carry what the markers need; one malformed list would
    // otherwise drop its problems silently.
    const ok = parsed.lists.every((l: Partial<AcceptedCheckList>) =>
      typeof l?.listPath === 'string' && Array.isArray(l.entries) && Array.isArray(l.problems) && !!l.summary);
    return ok ? (parsed as AcceptedCheckResult) : null;
  } catch {
    return null;
  }
}

/**
 * Combines the results of several CLI runs (one per workspace folder) into
 * one. A list reached by two runs (overlapping folders) is kept once, so its
 * markers and counts are not doubled.
 */
export function mergeCheckResults(results: AcceptedCheckResult[]): AcceptedCheckResult {
  const byPath = new Map<string, AcceptedCheckList>();
  for (const r of results) {
    for (const l of r.lists) {
      if (!byPath.has(l.listPath)) byPath.set(l.listPath, l);
    }
  }
  const lists = [...byPath.values()];
  const sum = (k: keyof AcceptedCheckSummary): number => lists.reduce((a, l) => a + (l.summary[k] ?? 0), 0);
  return {
    version: 2,
    lists,
    summary: {
      listCount: lists.length,
      entryCount: sum('entryCount'),
      active: sum('active'),
      stale: sum('stale'),
      notChecked: sum('notChecked'),
      problemCount: sum('problemCount'),
      hiddenTotal: sum('hiddenTotal'),
      aboveMaxTotal: sum('aboveMaxTotal'),
    },
  };
}

/**
 * The package root whose list applies to [filePath]: the nearest folder at
 * or above the file holding `pubspec.yaml`, or undefined when none does.
 * Mirrors `acceptedRootFor` in Dart, which the analyzer plugin and every CLI
 * producer use; writing to any other folder (the workspace's first project,
 * say) would create an entry no producer reads for this file.
 */
export function findPackageRoot(filePath: string, exists: (p: string) => boolean): string | undefined {
  let dir = path.dirname(filePath);
  for (;;) {
    if (exists(path.join(dir, 'pubspec.yaml'))) return dir;
    const parent = path.dirname(dir);
    // dirname of a filesystem root is itself: no package encloses the file.
    if (parent === dir) return undefined;
    dir = parent;
  }
}

/** A problem to place on the list file, before localization. */
export interface ListMarker {
  /** 0-based line for `vscode.Range`. */
  line: number;
  severity: 'warning' | 'error';
  /** Which message template applies. */
  kind: 'staleFileMissing' | 'staleNoFinding' | 'invalid';
  rule?: string;
  file?: string;
  message?: string;
}

/**
 * Markers for the Problems panel: stale entries as warnings, invalid ones as
 * errors (they hide nothing, which the author did not intend). Active and
 * not-checked entries get none: not-checked means "outside this run's
 * scope", which is not a defect.
 */
export function markersFromCheck(result: AcceptedCheckList): ListMarker[] {
  const markers: ListMarker[] = [];
  for (const e of result.entries) {
    if (e.state !== 'staleFileMissing' && e.state !== 'staleNoFinding') continue;
    markers.push({ line: toZeroBased(e.line), severity: 'warning', kind: e.state, rule: e.rule, file: e.file });
  }
  for (const p of result.problems) {
    markers.push({ line: toZeroBased(p.line), severity: 'error', kind: 'invalid', message: p.message });
  }
  return markers;
}

/** 1-based CLI line to 0-based editor line, clamped at the first line. */
function toZeroBased(line: number): number {
  return Number.isFinite(line) && line > 1 ? line - 1 : 0;
}

/**
 * The saropa rule name of a Problems-panel diagnostic, or undefined for
 * anything else. Saropa rules always prefix their message with `[rule_name]`
 * (project invariant), so requiring the prefix to equal the code keeps the
 * "Accept in this file" action off SDK lints and other plugins, whose
 * diagnostics the list cannot hide.
 */
export function saropaRuleOf(message: string, code: unknown): string | undefined {
  const value = typeof code === 'object' && code !== null && 'value' in code
    ? String((code as { value: unknown }).value)
    : typeof code === 'string' ? code : undefined;
  if (!value || !/^[a-z0-9_]+$/.test(value)) return undefined;
  return message.startsWith(`[${value}]`) ? value : undefined;
}

/**
 * Project-relative, forward-slash path of [filePath], or undefined when it is
 * outside [root]. Entries match on this exact form, so a file outside the
 * project can never be listed.
 */
export function projectRelativePath(root: string, filePath: string): string | undefined {
  const rel = path.relative(root, filePath);
  if (!rel || rel.startsWith('..') || path.isAbsolute(rel)) return undefined;
  return rel.split(path.sep).join('/');
}

/**
 * One YAML list item. Values are JSON-quoted: a JSON string is a valid YAML
 * double-quoted scalar, so a reason containing `:` or `#` cannot break the
 * file or change its meaning.
 */
export function buildEntryYaml(
  entry: { rule: string; file: string; kind: AcceptedKind; reason: string },
  indent = '  ',
): string {
  const pad = `${indent}  `;
  return [
    `${indent}- rule: ${entry.rule}`,
    `${pad}file: ${JSON.stringify(entry.file)}`,
    `${pad}kind: ${entry.kind}`,
    `${pad}reason: ${JSON.stringify(entry.reason)}`,
  ].join('\n') + '\n';
}

/**
 * Whether the list text already has an entry for [rule] in [file]. A finding
 * above an entry's `max:` still offers "Accept in this file", and appending a
 * second entry would only create an invalid duplicate that hides nothing.
 * Reads block and one-line flow items; anything else is left to the Dart
 * parser, which reports duplicates.
 */
export function hasEntry(existing: string, rule: string, file: string): boolean {
  // Comments are dropped first so a commented-out entry does not count.
  const text = existing.replace(/^\s*#.*$/gm, '');
  return text.split(/^\s*-(?=\s)/m).slice(1).some(
    (item) => itemValue(item, 'rule') === rule && normalizeFile(itemValue(item, 'file')) === file,
  );
}

/** The value of [key] in one list item, unquoted, or undefined. */
function itemValue(item: string, key: 'rule' | 'file'): string | undefined {
  // Anchored on a line start, `{` or `,` so "file:" inside a reason is skipped.
  const m = new RegExp(String.raw`(?:^|[{,])[ \t]*${key}[ \t]*:[ \t]*("(?:[^"\\]|\\.)*"|'[^']*'|[^,}#\r\n]+)`, 'm').exec(item);
  if (!m) return undefined;
  const raw = m[1].trim();
  if (raw.startsWith("'")) return raw.slice(1, -1);
  if (!raw.startsWith('"')) return raw;
  try {
    return JSON.parse(raw) as string;
  } catch {
    // A YAML-only escape: compare the text between the quotes.
    return raw.slice(1, -1);
  }
}

/** Same normalization as Dart's `normalizeAcceptedFile`, for comparison. */
function normalizeFile(file: string | undefined): string | undefined {
  return file?.split(path.win32.sep).join('/').replace(/^(\.\/)+/, '');
}

/** Header written when the list file does not exist yet. */
const NEW_FILE_HEADER = [
  '# Reviewed saropa_lints findings: one entry per rule + file, with a reason.',
  '# Listed findings are hidden from the Problems panel and exports.',
  '# Check for stale or invalid entries: dart run saropa_lints scan --check-accepted',
  'version: 1',
  'accepted:',
].join('\n') + '\n';

/**
 * Returns the new file text with [entry] appended, or null when the existing
 * text has a shape this simple appender cannot extend safely (e.g. a flow
 * list `accepted: []`, or `accepted:` followed by another top-level key).
 * The caller then asks the user to edit by hand instead of risking a
 * rewrite that changes other entries.
 */
export function appendEntry(
  existing: string | undefined,
  entry: { rule: string; file: string; kind: AcceptedKind; reason: string },
): string | null {
  if (existing === undefined || existing.trim() === '') {
    return NEW_FILE_HEADER + buildEntryYaml(entry);
  }
  const text = existing.endsWith('\n') ? existing : `${existing}\n`;
  const lines = text.split('\n');
  const keyIndex = lines.findIndex((l) => /^accepted:\s*(#.*)?$/.test(l));
  if (keyIndex < 0) {
    // No list yet: any other `accepted:` form (flow list, scalar) is unsafe.
    if (lines.some((l) => /^accepted:/.test(l))) return null;
    return `${text}accepted:\n${buildEntryYaml(entry)}`;
  }
  // Appending at the end is only correct when the block list is the last
  // top-level key; otherwise the item would land under a different key.
  const after = lines.slice(keyIndex + 1);
  if (after.some((l) => /^[^\s#-]/.test(l))) return null;
  // Match the existing item indentation (`- ` vs `  - `); mixing the two
  // styles under one key is a YAML error.
  const firstItem = after.find((l) => /^\s*-\s/.test(l));
  const indent = firstItem ? (/^(\s*)-/.exec(firstItem)?.[1] ?? '  ') : '  ';
  return text + buildEntryYaml(entry, indent);
}
