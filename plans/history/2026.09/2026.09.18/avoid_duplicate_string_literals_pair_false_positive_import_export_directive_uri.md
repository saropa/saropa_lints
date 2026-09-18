# BUG: `avoid_duplicate_string_literals_pair` — Flags a Directive URI That Cannot Legally Be Deduplicated

**Status: Closed**

Created: 2026-09-18
Rule: `avoid_duplicate_string_literals_pair`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~3830)
Severity: False positive
Rule version: v1 | Since: v4.13.0 | Updated: not found in source (no separate "Updated" marker in the doc comment — only "Since: v4.13.0 | Rule version: v1")

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD.

---

## Summary

`'drift_debug_import_result.dart'` is flagged as a "duplicate string literal" because it appears in both an `import` directive and an `export` directive in the same file. Dart requires directive URIs to be string literals — there is no Dart-legal refactor that deduplicates them (no `const`, no shared variable; the analyzer rejects a non-literal directive URI outright). The rule's own codebase already has a utility, `isInImportOrExport`, used by a sibling rule to skip exactly this case, but this rule does not call it.

---

## Attribution Evidence

```bash
$ grep -rn "'avoid_duplicate_string_literals_pair'" lib/src/rules/
lib/src/rules/code_quality/code_quality_avoid_rules.dart:3830:    'avoid_duplicate_string_literals_pair',

$ grep -rn "'avoid_duplicate_string_literals_pair'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches, confirms the rule is not defined downstream)
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:3830` (barrel-exported at `lib/src/rules/all_rules.dart:21`)
**Rule class:** `AvoidDuplicateStringLiteralsPairRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
// LINT (false positive) — the URI literal below is flagged as a
// duplicate of the one in the export directive further down.
import 'drift_debug_import_result.dart';

export 'drift_debug_import_result.dart'; // LINT (false positive)
```

Taken verbatim from `saropa_drift_advisor/lib/src/drift_debug_import.dart:3` (import) and `:11` (export) — the file imports `DriftDebugImportResult` for its own use and re-exports it so callers of `DriftDebugImportProcessor` get the result type without a second import, a standard "processor file re-exports its result type" pattern.

**Frequency:** Always — any file that both imports and re-exports (or imports the same URI twice across `import`/`export`/`part`) the same library triggers this, since directive URIs must be textually identical literals by language rule.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — directive URIs are compiler-mandated string literals, not extractable to a constant |
| **Actual** | `[avoid_duplicate_string_literals_pair] String literal appears 2+ times in this file. Consider extracting to a constant.` reported at both the `import` and `export` URI literals |

---

## AST Context

```
CompilationUnit
  ├─ ImportDirective
  │     └─ SimpleStringLiteral ('drift_debug_import_result.dart')  ← 1st occurrence
  ...
  └─ ExportDirective
        └─ SimpleStringLiteral ('drift_debug_import_result.dart')  ← reported here (2nd occurrence)
```

---

## Root Cause

`AvoidDuplicateStringLiteralsPairRule.runWithReporter` (`code_quality_avoid_rules.dart:3866-3887`) registers `context.addSimpleStringLiteral` and, for every `SimpleStringLiteral` node, checks only `_shouldSkipString` (`code_quality_avoid_rules.dart:3889-3907`):

```dart
bool _shouldSkipString(String value) {
  if (AvoidDuplicateStringLiteralsRule._isDomainInherentLiteral(value)) return true;
  if (value.startsWith('package:') || value.startsWith('dart:')) return true;
  if (value.startsWith('http://') || value.startsWith('https://')) return true;
  if (value.startsWith(r'$') && !value.contains(' ')) return true;
  if (value.startsWith('assets/') || value.startsWith('images/')) return true;
  return false;
}
```

This is a **value-text-only** filter — it never inspects `node.parent`, so it cannot tell a directive URI apart from an ordinary string literal used as data. A relative import like `'drift_debug_import_result.dart'` matches none of the five prefix/pattern checks (no `package:`/`dart:` prefix, not a URL, not an asset path), so it falls through and is tracked/counted like any other literal.

Critically, the codebase already has exactly the right utility for this: `isInImportOrExport` (`lib/src/literal_context_utils.dart:53`, walking `node.parent` up to any `UriBasedDirective`), and it is already used by a sibling rule in the very same category of "literal context" checks — `NoMagicStringRule` (`lib/src/rules/data/numeric_literal_rules.dart:425`: `if (isInImportOrExport(node)) return;`). `AvoidDuplicateStringLiteralsPairRule` simply never calls it.

---

## Suggested Fix

In `AvoidDuplicateStringLiteralsPairRule._shouldSkipString`/`runWithReporter` (`code_quality_avoid_rules.dart:3866-3907`), add the same guard `NoMagicStringRule` already uses:

```dart
context.addSimpleStringLiteral((SimpleStringLiteral node) {
  final String value = node.value;
  if (value.length < _minLength) return;
  if (isInImportOrExport(node)) return;   // <-- add this line
  if (_shouldSkipString(value)) return;
  ...
});
```

The same gap likely exists in the sibling rule `AvoidDuplicateStringLiteralsRule` (`code_quality_avoid_rules.dart:1150-1219`, the lower-threshold variant this file's `_shouldSkipString` delegates `_isDomainInherentLiteral` to) — its `runWithReporter`/`_shouldSkipString` pair has the identical shape and the identical missing `isInImportOrExport` call. Worth checking in the same fix pass since it shares the exact same false-positive mechanism.

---

## Fixture Gap

Fixture: `example/lib/code_quality/avoid_duplicate_string_literals_pair_fixture.dart` (confirmed to exist).

Missing NO-LINT case:
1. **Same relative URI string used in both an `import` and an `export` directive in one file** — expect NO lint (this report's exact reproducer).
2. **Same URI repeated across two separate `import` directives with a `show`/`hide` combinator split** — expect NO lint, same rationale.

---

## Changes Made

_Not yet — open report._

---

## Tests Added

_Not yet — open report._

---

## Commits

_Not yet — open report._

---

## Environment

- saropa_lints version: 16.2.1 (resolved; checkout at 16.3.0/HEAD, rule source unchanged)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a — findings came from the `saropa_lints scan` CLI / VS Code extension
- Triggering project/file: `saropa_drift_advisor` 4.4.1, `lib/src/drift_debug_import.dart:3,11`, scan report `reports/20260918/20260918_081229_findings.json`

---

## Finish Report (2026-09-18)

**Verdict:** Report confirmed valid. The suggested fix was correct, and the same gap existed in the sibling rule `AvoidDuplicateStringLiteralsRule` as the report predicted — fixed both.

**Root cause:** `AvoidDuplicateStringLiteralsPairRule.runWithReporter` and `AvoidDuplicateStringLiteralsRule.runWithReporter` (`lib/src/rules/code_quality/code_quality_avoid_rules.dart`) track every `SimpleStringLiteral` value using a text-only `_shouldSkipString` filter that never inspects `node.parent`. A directive URI (`import`/`export`/`part`) is a Dart-mandated string literal with no legal path to extraction as a constant, but a relative URI such as `'drift_debug_import_result.dart'` matches none of the five prefix/pattern skip checks (no `package:`/`dart:` prefix, not a URL, not an asset path), so it fell through and was counted like any ordinary literal. The existing semantic guard `isInImportOrExport` (`lib/src/literal_context_utils.dart:53`), already used by `NoMagicStringRule`, was never called by either duplicate-literal rule.

**Fix:** Added `if (isInImportOrExport(node)) return;` immediately after the min-length check and before `_shouldSkipString` in both rules' `context.addSimpleStringLiteral` callbacks in `lib/src/rules/code_quality/code_quality_avoid_rules.dart`. `literal_context_utils.dart` was already imported in this file, so no new import was needed. This is a semantic (AST-parent) check, not a name/string heuristic, so it does not introduce new false negatives on ordinary string literals.

**Fixture changes:**
- `example/lib/code_quality/avoid_duplicate_string_literals_pair_fixture.dart` — added a GOOD case: the same relative URI (`package:saropa_lints_example/flutter_mocks.dart`) used in both an `import` and an `export` directive.
- `example/lib/code_quality/avoid_duplicate_string_literals_fixture.dart` — added a GOOD case: the same relative URI repeated across two `import` directives (one aliased) and an `export` directive.
- Both fixtures pass `dart analyze` with no issues.

**Tests added:** `test/rules/code_quality/avoid_duplicate_string_literals_directive_behavior_test.dart` (new) — resolved-rule-harness regression tests for both rules:
- Silent when the same relative URI is used in an import and an export directive (both rules).
- Still fires on ordinary duplicated string literals (both rules), proving no false-negative regression.

`dart test test/rules/code_quality/avoid_duplicate_string_literals_directive_behavior_test.dart` — **4/4 tests passing.**

**Files changed:**
- `lib/src/rules/code_quality/code_quality_avoid_rules.dart`
- `example/lib/code_quality/avoid_duplicate_string_literals_pair_fixture.dart`
- `example/lib/code_quality/avoid_duplicate_string_literals_fixture.dart`
- `test/rules/code_quality/avoid_duplicate_string_literals_directive_behavior_test.dart` (new)
