/**
 * Consumer side of the Saropa Suite integration (plan requirement R2). Reads the
 * sibling extensions' offline diagnostic mirrors —
 * `.saropa/diagnostics/advisor.json` (Drift Advisor) and
 * `.saropa/diagnostics/log-capture.json` (Log Capture) — and correlates them back
 * to the Lints rules they reference, so the holistic dashboard can badge a rule
 * row with runtime evidence ("Advisor confirms this at runtime", "Log Capture saw
 * N occurrences").
 *
 * The correlation key is the protocol contract, not a guess: a sibling marks a
 * Lints rule as the static counterpart of its runtime issue by pointing the
 * diagnostic's `fix.command` at one of Lints' public deep-link ids with a
 * `{ ruleId }` arg (Advisor plan §4 R1 — e.g. a missing-index issue links to
 * `saropaLints.explainRule` for `require_database_index`). We count only those
 * explicit cross-references; an unrelated sibling diagnostic contributes nothing.
 *
 * Tolerant by design (§2.4): unknown fields are ignored, a missing or malformed
 * file yields no evidence rather than throwing, so a half-written mirror during a
 * sibling's own write never disrupts the dashboard. `vscode`-free for unit tests;
 * the only IO is a Node file read, injectable.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import { DIAGNOSTICS_DIR } from './envelope';

/** The two sibling mirror files Lints consumes, keyed by their producer source. */
export const SIBLING_MIRRORS: ReadonlyArray<{ source: SiblingSource; filename: string }> = [
  { source: 'advisor', filename: 'advisor.json' },
  { source: 'log-capture', filename: 'log-capture.json' },
];

export type SiblingSource = 'advisor' | 'log-capture';

/** The Lints deep-link command ids a sibling `fix.command` may target (plan §3). */
const LINTS_DEEP_LINK_COMMANDS: ReadonlySet<string> = new Set([
  'saropaLints.explainRule',
  'saropaLints.enableRule',
  'saropaLints.openFinding',
]);

/**
 * The subset of an incoming envelope diagnostic this consumer reads. Everything
 * else in the canonical schema (location, sql, table, severity, …) is ignored
 * here — R2 only needs the cross-reference, and tolerating extra fields is the
 * compatibility contract.
 */
interface IncomingDiagnostic {
  fix?: {
    command?: unknown;
    args?: unknown;
  };
}

interface IncomingEnvelope {
  diagnostics?: unknown;
}

/** Runtime evidence accumulated for one Lints rule across the sibling mirrors. */
export interface RuleEvidence {
  /** Number of Drift Advisor runtime issues that reference this rule. */
  advisorCount: number;
  /** Number of Log Capture signals that reference this rule. */
  logCaptureCount: number;
}

/** Injectable file reader so tests need no real filesystem. Returns null when absent. */
export type ReadFileFn = (absPath: string) => string | null;

/** Default reader: read the file, or null on any IO error (missing / unreadable). */
function defaultReadFile(absPath: string): string | null {
  try {
    return fs.readFileSync(absPath, 'utf-8');
  } catch {
    return null;
  }
}

/**
 * Pull the Lints rule id a sibling diagnostic cross-references, or undefined when
 * it does not target a Lints deep-link. Reads `fix.args[0].ruleId` only when
 * `fix.command` is one of the documented ids — the precise protocol signal.
 */
function referencedLintsRule(diag: IncomingDiagnostic): string | undefined {
  const command = diag.fix?.command;
  if (typeof command !== 'string' || !LINTS_DEEP_LINK_COMMANDS.has(command)) return undefined;
  const args = diag.fix?.args;
  if (!Array.isArray(args) || args.length === 0) return undefined;
  const first = args[0];
  if (first && typeof first === 'object' && 'ruleId' in first) {
    const ruleId = (first as { ruleId: unknown }).ruleId;
    if (typeof ruleId === 'string' && ruleId.trim().length > 0) return ruleId.trim();
  }
  return undefined;
}

/** Parse one mirror file's diagnostics array, tolerating malformed/missing input. */
function parseDiagnostics(raw: string | null): IncomingDiagnostic[] {
  if (raw === null) return [];
  try {
    const parsed = JSON.parse(raw) as IncomingEnvelope;
    return Array.isArray(parsed.diagnostics) ? (parsed.diagnostics as IncomingDiagnostic[]) : [];
  } catch {
    // A sibling mid-write or a corrupt file must not break the dashboard.
    return [];
  }
}

/** Ensure an evidence row exists for a rule, then return it. */
function evidenceFor(map: Map<string, RuleEvidence>, ruleId: string): RuleEvidence {
  let row = map.get(ruleId);
  if (!row) {
    row = { advisorCount: 0, logCaptureCount: 0 };
    map.set(ruleId, row);
  }
  return row;
}

/**
 * Build the rule → runtime-evidence map from both sibling mirrors under `root`.
 * Empty map when neither file exists or neither references a Lints rule.
 */
export function buildSuiteEvidence(
  root: string,
  readFile: ReadFileFn = defaultReadFile,
): Map<string, RuleEvidence> {
  const evidence = new Map<string, RuleEvidence>();
  for (const { source, filename } of SIBLING_MIRRORS) {
    const diagnostics = parseDiagnostics(readFile(path.join(root, DIAGNOSTICS_DIR, filename)));
    for (const diag of diagnostics) {
      const ruleId = referencedLintsRule(diag);
      if (!ruleId) continue;
      const row = evidenceFor(evidence, ruleId);
      if (source === 'advisor') row.advisorCount++;
      else row.logCaptureCount++;
    }
  }
  return evidence;
}

/** True when a rule has any runtime evidence — keeps the badge logic in one place. */
export function hasEvidence(evidence: RuleEvidence | undefined): boolean {
  return !!evidence && (evidence.advisorCount > 0 || evidence.logCaptureCount > 0);
}
