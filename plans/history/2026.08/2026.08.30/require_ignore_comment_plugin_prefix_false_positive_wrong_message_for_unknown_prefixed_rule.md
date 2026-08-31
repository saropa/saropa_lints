# BUG: `require_ignore_comment_plugin_prefix` — Wrong diagnostic message when prefixed rule name is unregistered

**Status: Fixed**

Created: 2026-08-30
Rule: `require_ignore_comment_plugin_prefix`
File: `lib/src/rules/stylistic/formatting_rules.dart` (line ~1218–1229)
Severity: High — misleading message causes downstream devs to add a prefix that's already there
Rule version: 15.2.4

---

## Summary

When an `// ignore:` comment uses the `saropa_lints/` prefix with a rule name
that is NOT registered in saropa_lints (e.g. a core Dart lint like
`avoid_positional_boolean_parameters`), the IDE Problems panel shows the
**bare-name diagnostic** message ("without the required saropa_lints/ prefix")
instead of the **unknown-prefixed-name diagnostic** ("not a registered
saropa_lints rule"). The prefix is already present, so the message is wrong and
sends the developer on a wild-goose chase.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_ignore_comment_plugin_prefix'" lib/src/rules/
# lib/src/rules/stylistic/formatting_rules.dart:1174: 'require_ignore_comment_plugin_prefix',
# lib/src/rules/stylistic/formatting_rules.dart:1285: 'require_ignore_comment_plugin_prefix',
```

**Emitter registration:** `lib/src/rules/stylistic/formatting_rules.dart:1174`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dartAnalysisLSP`

---

## Reproducer

```dart
class Example {
  // Core Dart lint — NOT a saropa_lints rule. The saropa_lints/ prefix is wrong.
  static void toggle(
    String name,
    int index,
    // ignore: saropa_lints/avoid_positional_boolean_parameters -- reason
    bool checked,
  ) {}
}
```

Also reproduces with `// ignore_for_file:`:

```dart
// ignore_for_file: saropa_lints/lines_longer_than_100_chars -- vendored port
```

**Frequency:** Always — any `// ignore:` with `saropa_lints/` prefix and an
unregistered suffix triggers the wrong message.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `[require_ignore_comment_plugin_prefix] This // ignore: comment uses saropa_lints/ prefix but 'avoid_positional_boolean_parameters' is not a registered saropa_lints rule — the suppression has no effect because the analyzer matches ignore comments by exact rule id.` |
| **Actual** | `[require_ignore_comment_plugin_prefix] This // ignore: comment references a saropa_lints rule without the required saropa_lints/ prefix — the IDE and analyzer will not suppress this diagnostic. Prefix each saropa_lints rule name with saropa_lints/ so the suppression works.` |

The actual message tells the developer to add a prefix that is already there.

---

## Root Cause

### Hypothesis A: Dynamic LintCode override not surfaced by custom_lint / analysis server

`_checkPrecedingComments` (line 1209) runs two independent checks:

1. `_hasBareRuleName` → reports with the static `_code` (line 1220)
2. `_firstUnknownPrefixedSuffix` → reports with a dynamic `LintCode` from
   `_buildUnknownPrefixedCode` (line 1225–1229)

For the reproducer, `_hasBareRuleName` correctly returns `false` (the name
starts with `saropa_lints/`). `_firstUnknownPrefixedSuffix` correctly returns
`'avoid_positional_boolean_parameters'` (not in `_allSaropaRuleNames`). Only
the second diagnostic fires.

The dynamic `LintCode` passed to `reporter.atToken(comment, _buildUnknownPrefixedCode(...))` carries the correct "not a registered rule" message. But the
IDE Problems panel displays the static `_code` message instead.

Both `LintCode` instances share the same code name string
`'require_ignore_comment_plugin_prefix'`. The analysis server or `custom_lint`
protocol may resolve the message from the rule's registered `LintCode` (the
static `_code`) rather than the per-diagnostic override, since the code name
matches.

### Hypothesis B: Reporter ignores the override parameter

`SaropaDiagnosticReporter.atToken` may discard the second argument and always
use the rule's default `LintCode`. Check `SaropaDiagnosticReporter`
implementation.

---

## Suggested Fix

**Option 1 (preferred):** Use a distinct code name for the unknown-suffix
variant, e.g. `'require_ignore_comment_plugin_prefix_unknown_rule'`. This
guarantees the analysis server treats them as separate diagnostics with
separate messages.

**Option 2:** If `SaropaDiagnosticReporter.atToken` discards the override,
fix it to propagate the per-diagnostic `LintCode`.

---

## Fixture Gap

The fixture at `example*/lib/stylistic/require_ignore_comment_plugin_prefix_fixture.dart` should include:

1. **`// ignore: saropa_lints/nonexistent_rule_name`** — expect LINT with "not a registered rule" message
2. **`// ignore_for_file: saropa_lints/nonexistent_rule_name`** — expect LINT with "not a registered rule" message
3. **`// ignore: saropa_lints/avoid_print_in_release`** — expect NO lint (registered rule, correct prefix)

---

## Changes Made

**Root cause:** `SaropaDiagnosticReporter.atToken` accepts an optional `LintCode` override but ignores it — the reporter always calls `_rule.reportAtToken(token)` which reads `diagnosticCode`, the rule's single static `_code`. Both bare-name and unknown-prefix diagnostics displayed the same "add prefix" message.

**Fix:** Added a `_pendingCode` field and overrode `diagnosticCode` in `RequireIgnoreCommentPluginPrefixRule` to return `_pendingCode ?? super.diagnosticCode`. Before reporting the unknown-prefix diagnostic, the rule sets `_pendingCode` to the dynamic `LintCode` from `_buildUnknownPrefixedCode()` and clears it immediately after. Since reporting is synchronous, this is safe.

**Files changed:**
- `lib/src/rules/stylistic/formatting_rules.dart` — added `_pendingCode` field, `diagnosticCode` override, and swapped the unknown-prefix reporting path to set/clear `_pendingCode` instead of passing the code to `atToken()`

---

## Tests Added

Existing fixture coverage at `example/lib/formatting/require_ignore_comment_plugin_prefix_fixture.dart` already includes unknown-prefixed cases (lines 50-69). The fix changes only which message is displayed, not whether the lint fires.

---

## Commits

See git log for `fix: require_ignore_comment_plugin_prefix wrong message for unknown prefixed rule`.

---

## Finish Report (2026-08-30)

`require_ignore_comment_plugin_prefix` displayed the "add prefix" message when an `// ignore: saropa_lints/unknown_name` comment referenced a non-existent rule. The correct message — "not a registered saropa_lints rule" — was constructed but never surfaced because `SaropaDiagnosticReporter.atToken` ignores its optional `LintCode` parameter; it always reads `diagnosticCode` from the rule instance.

**Fix approach:** `RequireIgnoreCommentPluginPrefixRule` now overrides `diagnosticCode` to check a `_pendingCode` field first. Before reporting the unknown-prefix diagnostic, the rule sets `_pendingCode` to the dynamic `LintCode` from `_buildUnknownPrefixedCode()`, reports, then clears it in a `try/finally` block. Synchronous reporting guarantees no interleaving.

**Alternatives considered:**
- Separate rule class for the unknown-prefix case: architecturally clean but heavyweight (new registration, tier assignment, config surface).
- Generic message covering both cases: degrades UX for the common bare-name case.
- Fix the reporter to forward the code parameter: blocked by documented design decision ("the rule's diagnosticCode is always used").

**Risk:** The `_pendingCode` swap is safe only while reporting is synchronous. If `SaropaDiagnosticReporter` or `AnalysisRule.reportAtToken` ever becomes async, the pattern breaks silently. The `try/finally` guard prevents stale state in the throw path but not in an async interleaving path

---

## Environment

- saropa_lints version: 15.2.4
- Dart SDK version: (current stable)
- custom_lint version: (current)
- Triggering project: `d:\src\contacts`
- Triggering files:
  - `lib/service/emergency/emergency_tip_checklist_service.dart:88`
  - `lib/utils/zxcvbn/src/zxcvbn_matching.dart:8`
