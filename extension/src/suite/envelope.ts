/**
 * Producer for the Saropa Diagnostic Envelope — the one cross-tool shape that
 * `saropa_lints`, `saropa_drift_advisor`, and `saropa-log-capture` all emit and
 * consume so a developer's static code, live database, and runtime behavior
 * become one correlated picture.
 *
 * The envelope schema is owned canonically by the Drift Advisor plan (Section 2
 * of `saropa_drift_advisor/plans/67-saropa-suite-integration.md`); this module is
 * the Lints producer side (plan requirement R1). It turns the live findings model
 * ({@link ViolationsData}) into `source: "lints"` diagnostics written to
 * `<workspace>/.saropa/diagnostics/lints.json` — the offline mirror the two
 * sibling extensions read when the analyzer is not the active tool.
 *
 * Deliberately dependency-free of `vscode` so it is unit-testable in isolation
 * (the same pattern the other live-model files follow). The production glue that
 * reads live diagnostics and triggers the write lives in `exporter.ts`; the file
 * write here uses only Node built-ins.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import type { RuleMetadataData, Violation, ViolationsData } from '../violationsReader';
import { getRuleDocUrl } from '../ruleMetadata';

/** Schema version of the envelope this producer emits (canonical: Advisor plan §2.2). */
export const ENVELOPE_SCHEMA_VERSION = 1;

/** Producer name stamped into every envelope this package writes. */
export const LINTS_PRODUCER_NAME = 'saropa_lints';

/** Workspace-relative directory the three tools share for offline mirrors (plan §2.3). */
export const DIAGNOSTICS_DIR = path.join('.saropa', 'diagnostics');

/** This producer's mirror file name; siblings read `advisor.json` / `log-capture.json`. */
export const LINTS_MIRROR_FILENAME = 'lints.json';

/** The three severities the suite standardized on (Lints' own error/warning/info triple). */
export type EnvelopeSeverity = 'error' | 'warning' | 'info';

/**
 * The category vocabulary the envelope defines. Lints emits the subset it can
 * derive from a static rule: `drift` (the flagship Drift Health loop keys on it),
 * `security`, `performance`, `a11y`, or `other`. The `crash | schema | data`
 * members exist in the shared schema for the siblings; Lints never produces them.
 */
export type EnvelopeCategory =
  | 'drift'
  | 'security'
  | 'performance'
  | 'a11y'
  | 'other';

/** A primary, click-through action attached to a diagnostic (plan §2.1 `fix`). */
export interface EnvelopeFix {
  kind: 'quickFix' | 'command' | 'doc';
  title: string;
  command?: string;
  args?: unknown[];
  uri?: string;
}

/** One cross-tool diagnostic (plan §2.1). Lints fills the static-analysis fields. */
export interface SaropaDiagnostic {
  id: string;
  source: 'lints';
  severity: EnvelopeSeverity;
  category: EnvelopeCategory;
  title: string;
  ruleId: string;
  location: {
    file: string;
    line?: number;
  };
  fix?: EnvelopeFix;
  docUri?: string;
  /** Stamped only when the caller supplies a commit (plan §6 / requirement R6). */
  commitSha?: string;
}

/** The wire envelope (plan §2.2). */
export interface SaropaEnvelope {
  schemaVersion: number;
  producer: { name: string; version: string };
  generatedAt: string;
  diagnostics: SaropaDiagnostic[];
}

/** Inputs the builder needs that are not on the findings model itself. */
export interface BuildEnvelopeOptions {
  /** The extension's own version, stamped into `producer.version`. */
  producerVersion: string;
  /** ISO 8601 timestamp; passed in (not read from a clock) so tests stay deterministic. */
  generatedAt: string;
  /** Already-localized label for the deep-link fix action (§2.4: strings cross the boundary localized). */
  fixTitle: string;
  /** Per-rule metadata (rule type, tags, CWE ids) used to derive `category`. */
  catalog?: Record<string, RuleMetadataData>;
  /** Current commit SHA for cross-commit correlation; omitted until requirement R6. */
  commitSha?: string;
}

/**
 * Derive the envelope `category` from the rule id and its catalog metadata.
 *
 * Order matters: `drift` is checked first because the suite's flagship loop joins
 * on it, and a Drift rule can also carry a security/performance tag — the Drift
 * lens must win so the Drift Health panel finds it. After that, security
 * (rule-type, a CWE mapping, or the explicit tag) outranks performance and a11y
 * because a vulnerability mis-bucketed as perf is the worse failure. `other` is
 * the honest fallback for rules with no domain signal rather than a guess.
 */
export function deriveCategory(
  ruleId: string,
  meta: RuleMetadataData | undefined,
): EnvelopeCategory {
  if (ruleId.includes('drift')) return 'drift';

  const tags = meta?.tags ?? [];
  const isSecurity =
    meta?.ruleType === 'vulnerability' ||
    meta?.ruleType === 'securityHotspot' ||
    (meta?.cweIds?.length ?? 0) > 0 ||
    tags.includes('security');
  if (isSecurity) return 'security';

  if (tags.includes('performance')) return 'performance';
  if (tags.includes('accessibility')) return 'a11y';
  return 'other';
}

/**
 * Stable, product-scoped dedupe id for a finding (plan §2.1 `id`).
 *
 * Composed from the parts a sibling needs to round-trip back to the exact finding
 * via `saropaLints.openFinding`: the rule, the workspace-relative file, and the
 * 1-based line. The `lints:` prefix namespaces it so ids never collide with a
 * sibling's. {@link parseFindingId} is the inverse.
 */
export function buildFindingId(v: Violation): string {
  return `lints:${v.rule}:${v.file}:${v.line}`;
}

/** Parsed shape of a finding id; `null` when the string is not a Lints finding id. */
export interface ParsedFindingId {
  rule: string;
  file: string;
  line: number;
}

/**
 * Inverse of {@link buildFindingId}. The file portion may itself contain `:` on
 * Windows-style inputs, so we split off the known-position prefix and rule, then
 * treat the final colon-segment as the line and the remainder as the file — that
 * way a path is never corrupted by an interior colon.
 */
export function parseFindingId(id: string): ParsedFindingId | null {
  if (!id.startsWith('lints:')) return null;
  const body = id.slice('lints:'.length);
  const firstColon = body.indexOf(':');
  if (firstColon < 0) return null;
  const rule = body.slice(0, firstColon);
  const rest = body.slice(firstColon + 1);
  const lastColon = rest.lastIndexOf(':');
  if (lastColon < 0) return null;
  const file = rest.slice(0, lastColon);
  const line = Number.parseInt(rest.slice(lastColon + 1), 10);
  if (!rule || !file || !Number.isFinite(line)) return null;
  return { rule, file, line };
}

const VALID_SEVERITIES: ReadonlySet<string> = new Set(['error', 'warning', 'info']);

/** Coerce a model severity onto the envelope triple; unknown/absent collapses to `info`. */
function toEnvelopeSeverity(severity: string | undefined): EnvelopeSeverity {
  return severity && VALID_SEVERITIES.has(severity) ? (severity as EnvelopeSeverity) : 'info';
}

/**
 * Build the deep-link fix for a finding. Lints does not (yet) know per-rule which
 * rules ship a quick fix from the TypeScript side, so every finding gets the
 * always-available `command` deep-link into Rule Explain via the public
 * `saropaLints.explainRule` id (plan §3). A sibling envelope targeting Lints must
 * use one of those documented ids; this is the one Lints offers for a finding.
 */
function buildFix(ruleId: string, fixTitle: string): EnvelopeFix {
  return {
    kind: 'command',
    title: fixTitle,
    command: 'saropaLints.explainRule',
    args: [{ ruleId }],
  };
}

/**
 * Map one live finding to an envelope diagnostic. `location.file` is already
 * workspace-relative and forward-slashed upstream (the live model builds it with
 * `path.relative`), satisfying §2.4's ban on absolute home paths.
 */
function toDiagnostic(
  v: Violation,
  opts: BuildEnvelopeOptions,
): SaropaDiagnostic {
  const meta = opts.catalog?.[v.rule];
  const diagnostic: SaropaDiagnostic = {
    id: buildFindingId(v),
    source: 'lints',
    severity: toEnvelopeSeverity(v.severity),
    category: deriveCategory(v.rule, meta),
    title: v.message,
    ruleId: v.rule,
    location: { file: v.file, line: v.line },
    fix: buildFix(v.rule, opts.fixTitle),
    docUri: getRuleDocUrl(v.rule),
  };
  if (opts.commitSha) diagnostic.commitSha = opts.commitSha;
  return diagnostic;
}

/**
 * Build the full envelope from the live findings model. Pure and deterministic:
 * the timestamp and version come from `opts`, never a clock or global, so a test
 * can assert byte-for-byte output.
 */
export function buildLintsEnvelope(
  data: ViolationsData,
  opts: BuildEnvelopeOptions,
): SaropaEnvelope {
  const diagnostics = (data.violations ?? []).map((v) => toDiagnostic(v, opts));
  return {
    schemaVersion: ENVELOPE_SCHEMA_VERSION,
    producer: { name: LINTS_PRODUCER_NAME, version: opts.producerVersion },
    generatedAt: opts.generatedAt,
    diagnostics,
  };
}

/** Absolute path of this producer's mirror file under a workspace root. */
export function lintsMirrorPath(root: string): string {
  return path.join(root, DIAGNOSTICS_DIR, LINTS_MIRROR_FILENAME);
}

/**
 * Write the envelope to `<root>/.saropa/diagnostics/lints.json`, creating the
 * directory if needed. Returns the path written. Throws are the caller's to
 * handle — the analysis-settle hook swallows them so a transient write failure
 * (read-only tree, race) never disrupts linting.
 */
export function writeLintsEnvelope(root: string, envelope: SaropaEnvelope): string {
  const target = lintsMirrorPath(root);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, `${JSON.stringify(envelope, null, 2)}\n`, 'utf-8');
  return target;
}
