/**
 * Crash-to-rule attribution — the consumer half of the suite's flagship loop
 * (plan requirement R3). Log Capture parses runtime crash families and writes a
 * `crash`-category diagnostic to `<workspace>/.saropa/diagnostics/log-capture.json`
 * whose `ruleId` carries a stable crash-family signature prefixed `crash:`. Lints
 * owns the mapping from that signature to the static rule(s) that would have
 * prevented the crash, turning production telemetry into a static-analysis
 * feedback loop ("this crash class is covered by rule X — enable it").
 *
 * The boundary is firm: Log Capture owns the *signature* (a frozen contract — see
 * the table below, source of truth `saropa-log-capture/src/modules/diagnostics/
 * crash-signature.ts`); Lints owns the *mapping*. Renaming a signature would
 * silently break this, so {@link CRASH_SIGNATURES} mirrors the frozen set exactly
 * and the unit test pins it.
 *
 * Deliberately `vscode`-free so it is unit-testable in isolation (same pattern as
 * {@link ./envelope} and {@link ./siblingEnvelopes}); the only IO is an injectable
 * Node file read. The `vscode` glue that turns a suggestion into the "enable rule
 * X" toast lives in {@link ./crashCoverageNudge}.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import { DIAGNOSTICS_DIR } from './envelope';
import type { ReadFileFn } from './siblingEnvelopes';

// Re-exported so consumers and tests get the injectable-reader type from this
// module's surface without reaching into the sibling-envelope module.
export type { ReadFileFn } from './siblingEnvelopes';

/** Prefix Log Capture stamps on a crash-family `ruleId`; stripped to get the signature. */
export const CRASH_PREFIX = 'crash:';

/** Log Capture's mirror file, read here as the crash-signature source. */
export const LOG_CAPTURE_FILENAME = 'log-capture.json';

/**
 * The frozen crash-family signature set Log Capture emits (the `crash:` prefix
 * stripped). This MUST stay byte-identical to Log Capture's
 * `crash-signature.ts` — it is a cross-tool contract, not a local choice. An
 * incoming signature outside this set is ignored, not an error, so a newer Log
 * Capture that adds a family never breaks an older Lints (forward tolerance,
 * plan §2.4).
 */
export type CrashSignature =
  | 'state-error-no-element'
  | 'range-error-index'
  | 'null-check-operator'
  | 'late-init'
  | 'concurrent-modification'
  | 'type-error-cast'
  | 'format-exception'
  | 'no-such-method'
  | 'assertion-failed'
  | 'stack-overflow'
  | 'out-of-memory'
  | 'anr';

/**
 * Signature → the Lints rule(s) that prevent that crash class. Each rule id is a
 * real rule in `lib/src/rules/` (the unit test cross-checks against the catalog).
 * The order within a family is most-direct-first: the rule whose threat model is
 * the exact crash leads, broader rules follow. An empty array is a deliberate
 * "no static rule covers this family yet" — a new-rule backlog signal (plan §5),
 * not an omission. `assertion-failed`, `format-exception`, `no-such-method`,
 * `out-of-memory`, and `anr` map to the nearest applicable rules; some families
 * (stack-overflow via mutual recursion across files) are only partially covered.
 */
export const CRASH_SIGNATURE_TO_RULES: Readonly<Record<CrashSignature, readonly string[]>> = {
  // `Bad state: No element` — `.first`/`.last`/`.single` on an empty iterable. No
  // single generic rule yet covers bare `.first`; the package-specific
  // empty-result rules are the concrete preventers shipped today.
  'state-error-no-element': [
    'geocoding_unchecked_first',
    'image_picker_multi_result_unchecked_empty',
    'image_picker_lost_data_empty_check_missing',
    'device_calendar_retrieve_events_empty_params',
  ],
  // `RangeError (index)` — `list[i]` past the end / negative index.
  'range-error-index': [
    'avoid_builder_index_out_of_bounds',
    'avoid_accessing_collections_by_constant_index',
    'avoid_enum_values_by_index',
  ],
  // `Null check operator used on a null value` — the `!` bang on null.
  'null-check-operator': [
    'avoid_non_null_assertion',
    'avoid_null_assertion',
    'avoid_ios_force_unwrap_in_callbacks',
  ],
  // `LateInitializationError` — a `late` field read before assignment.
  'late-init': [
    'avoid_unassigned_late_fields',
    'avoid_late_without_guarantee',
    'require_late_access_check',
    'require_late_initialization_in_init_state',
  ],
  // `Concurrent modification during iteration`.
  'concurrent-modification': ['avoid_collection_mutating_methods'],
  // `type 'X' is not a subtype of type 'Y'` — a failed `as` cast.
  'type-error-cast': [
    'avoid_unsafe_cast',
    'avoid_unrelated_type_casts',
    'avoid_removed_cast_error',
  ],
  // `FormatException` — parsing malformed input without `tryParse`/validation.
  'format-exception': [
    'prefer_try_parse_for_dynamic_data',
    'avoid_datetime_parse_unvalidated',
  ],
  // `NoSuchMethodError` — method/getter on null or an untyped dynamic.
  'no-such-method': [
    'avoid_dynamic_type',
    'require_null_safe_json_access',
    'prefer_correct_json_casts',
  ],
  // `Failed assertion` — an `assert(...)` tripped at runtime.
  'assertion-failed': ['avoid_assert_in_production'],
  // `Stack Overflow` — unbounded recursion.
  'stack-overflow': ['avoid_recursive_calls', 'avoid_recursive_widget_calls'],
  // `OutOfMemoryError` / heap exhaustion.
  'out-of-memory': [
    'avoid_large_images_in_memory',
    'avoid_loading_full_pdf_in_memory',
    'avoid_unbounded_cache_growth',
    'avoid_memory_intensive_operations',
  ],
  // Application Not Responding — main-thread block.
  anr: [
    'avoid_blocking_main_thread',
    'avoid_blocking_database_ui',
    'prefer_compute_for_heavy_work',
  ],
};

/** Fast membership set for validating an incoming signature against the frozen set. */
const KNOWN_SIGNATURES: ReadonlySet<string> = new Set(Object.keys(CRASH_SIGNATURE_TO_RULES));

/** Default reader: read the file, or null on any IO error (missing / unreadable). */
function defaultReadFile(absPath: string): string | null {
  try {
    return fs.readFileSync(absPath, 'utf-8');
  } catch {
    return null;
  }
}

/** The subset of an incoming Log Capture diagnostic this consumer reads. */
interface IncomingCrashDiagnostic {
  category?: unknown;
  ruleId?: unknown;
}

interface IncomingEnvelope {
  diagnostics?: unknown;
}

/**
 * Pull the crash signature from one incoming diagnostic, or undefined when it is
 * not a known crash row. Requires `category === "crash"` AND a `ruleId` of the
 * form `crash:<signature>` whose signature is in the frozen set — anything else
 * (a non-crash diagnostic, a missing prefix, a signature from a newer Log
 * Capture) is ignored rather than treated as an error.
 */
function crashSignatureOf(diag: IncomingCrashDiagnostic): CrashSignature | undefined {
  if (diag.category !== 'crash') return undefined;
  const ruleId = diag.ruleId;
  if (typeof ruleId !== 'string' || !ruleId.startsWith(CRASH_PREFIX)) return undefined;
  const signature = ruleId.slice(CRASH_PREFIX.length).trim();
  return KNOWN_SIGNATURES.has(signature) ? (signature as CrashSignature) : undefined;
}

/**
 * Read `log-capture.json` under `root` and count crash diagnostics per signature.
 * Tolerant by design (plan §2.4): a missing / truncated / malformed file or a
 * non-array `diagnostics` yields an empty map rather than throwing, so a sibling
 * mid-write never disrupts Lints. Counts repeat occurrences of the same family.
 */
export function readCrashCounts(
  root: string,
  readFile: ReadFileFn = defaultReadFile,
): Map<CrashSignature, number> {
  const counts = new Map<CrashSignature, number>();
  const raw = readFile(path.join(root, DIAGNOSTICS_DIR, LOG_CAPTURE_FILENAME));
  if (raw === null) return counts;

  let parsed: IncomingEnvelope;
  try {
    parsed = JSON.parse(raw) as IncomingEnvelope;
  } catch {
    return counts;
  }
  if (!Array.isArray(parsed.diagnostics)) return counts;

  for (const diag of parsed.diagnostics as IncomingCrashDiagnostic[]) {
    const signature = crashSignatureOf(diag);
    if (!signature) continue;
    counts.set(signature, (counts.get(signature) ?? 0) + 1);
  }
  return counts;
}

/**
 * One actionable suggestion: a runtime crash family was observed and a static
 * rule that would prevent it is currently disabled. `occurrences` is how many
 * crash diagnostics of that family Log Capture recorded, surfaced so the toast
 * can convey "seen N times" rather than a bare prompt.
 */
export interface CrashRuleSuggestion {
  signature: CrashSignature;
  ruleId: string;
  occurrences: number;
}

/**
 * The R3 core: for each crash family Log Capture saw, emit a suggestion for every
 * mapped rule that is currently disabled — those are the rules whose static check
 * would have caught the class that crashed in the wild. Enabled rules and
 * families with no observed crash produce nothing. One suggestion per
 * (signature, disabled-rule) pair, ordered by the family's most-direct-first map.
 */
export function findCrashCoveredDisabledRules(
  root: string,
  disabledRules: ReadonlySet<string>,
  readFile: ReadFileFn = defaultReadFile,
): CrashRuleSuggestion[] {
  const counts = readCrashCounts(root, readFile);
  const suggestions: CrashRuleSuggestion[] = [];
  for (const [signature, occurrences] of counts) {
    for (const ruleId of CRASH_SIGNATURE_TO_RULES[signature]) {
      if (disabledRules.has(ruleId)) {
        suggestions.push({ signature, ruleId, occurrences });
      }
    }
  }
  return suggestions;
}
