/**
 * Reads `saropa_baseline.json` (written by `dart run saropa_lints:baseline`, wired to the
 * `saropaLints.createBaseline` command in `setup.ts`) for the Config file tab's Baseline
 * subsection (Phase 4, PLAN_extension_ui_redesign.md §3 "Baseline: create / view diff / apply,
 * with the current baseline file rendered as a table").
 *
 * WHY read-only here: the baseline file's shape (`{version, generated, violations: {file:
 * {rule: [lines]}}}`, `lib/src/baseline/baseline_file.dart` `toJson`) is generated and consumed
 * entirely by the Dart CLI (`bin/baseline.dart`) — this module only needs to summarize it for
 * display. "Create" and "Apply" are the SAME action from the UI's perspective: the CLI writes
 * both the JSON file AND the `baseline: file: ...` config block in one run (see `bin/baseline.dart`
 * `_writeBaselineConfig`, gated by `--skip-config` which the extension's `runCreateBaseline` does
 * not pass), so there is no separate "apply" step to wire up — the existing `saropaLints.createBaseline`
 * command already does both, and this tab's "Create / refresh baseline" button reuses it.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';

const BASELINE_FILENAME = 'saropa_baseline.json';

export interface BaselineSummary {
  version: unknown;
  generated: string | undefined;
  fileCount: number;
  totalViolations: number;
  /** Top rule codes by violation count, descending, capped for display. */
  topRules: Array<{ rule: string; count: number }>;
}

/** Reads and summarizes `saropa_baseline.json`. Returns `undefined` when the file is absent or unparseable — the caller renders an empty state rather than an error, since "no baseline yet" is the common, expected case. */
export function readBaselineSummary(root: string, maxTopRules = 10): BaselineSummary | undefined {
  const filePath = path.join(root, BASELINE_FILENAME);
  if (!fs.existsSync(filePath)) return undefined;
  let raw: string;
  try {
    raw = fs.readFileSync(filePath, 'utf-8');
  } catch {
    return undefined;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return undefined;
  }
  if (typeof parsed !== 'object' || parsed === null) return undefined;
  const obj = parsed as Record<string, unknown>;
  const violations = obj.violations;
  const ruleCounts = new Map<string, number>();
  let fileCount = 0;
  let totalViolations = 0;
  if (typeof violations === 'object' && violations !== null) {
    for (const perFile of Object.values(violations as Record<string, unknown>)) {
      if (typeof perFile !== 'object' || perFile === null) continue;
      fileCount += 1;
      for (const [rule, lines] of Object.entries(perFile as Record<string, unknown>)) {
        const count = Array.isArray(lines) ? lines.length : 0;
        totalViolations += count;
        ruleCounts.set(rule, (ruleCounts.get(rule) ?? 0) + count);
      }
    }
  }
  const topRules = [...ruleCounts.entries()]
    .map(([rule, count]) => ({ rule, count }))
    .sort((a, b) => b.count - a.count || a.rule.localeCompare(b.rule))
    .slice(0, maxTopRules);
  return {
    version: obj.version,
    generated: typeof obj.generated === 'string' ? obj.generated : undefined,
    fileCount,
    totalViolations,
    topRules,
  };
}

/** Absolute path to the baseline file, for an "Open baseline file" action. */
export function baselineFilePath(root: string): string {
  return path.join(root, BASELINE_FILENAME);
}
