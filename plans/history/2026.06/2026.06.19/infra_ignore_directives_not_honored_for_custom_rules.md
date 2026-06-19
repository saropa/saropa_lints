# BUG: `infra` — analyzer `// ignore:` directives do not suppress saropa_lints custom-rule diagnostics under `dart analyze`

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

---

## Resolution (2026-06-19)

Reproduced with the local-source scan CLI (the repo's own `dart analyze` runs the
published pub.dev plugin snapshot, so it cannot exercise local edits). Findings against
the actual report paths:

- **`prefer_final_fields` (Case 1) — already honored.** It reports via `atNode` on the
  `FieldDeclaration`. A leading `// ignore: prefer_final_fields` (bare form, and with a
  trailing `-- reason` suffix) is suppressed by the existing node walk. Hypothesis A's
  premise that it reports via `atToken` does not hold for current source. If the published
  14.0.3 still showed it, the node-path fixes that landed since (the `atToken`
  declaration-name and doc-comment patches) close it on publish.
- **`avoid_recursive_calls` (Case 2) — real bug, fixed.** It reports via `atNode` on the
  inner self-call `MethodInvocation`, which can sit several lines below the `return` it is
  nested under. `IgnoreUtils.hasIgnoreComment`'s parent-chain walk compared every ancestor
  against the **leaf** node's start line, so a `// ignore:` written above the enclosing
  statement never satisfied the `commentLine == start - 1` guard once the leaf and the
  statement were on different lines. Fixed by recomputing each ancestor's own start line
  during the walk (using `firstTokenAfterCommentAndMetadata` for `AnnotatedNode`s so the
  doc-commented-field case does not regress). `lib/src/ignore_utils.dart`.
- **Hypothesis C (namespaced `saropa_lints/<rule>`) — not the failing link.** `\b<rule>\b`
  matches inside `saropa_lints/avoid_recursive_calls`; the namespaced reproducer failed for
  the same parent-walk reason as the bare form, now fixed.
- **Hypothesis B (`atOffset`) — not pursued.** The in-repo `atOffset` callers are all
  file/line/word-level diagnostics anchored at the unit's first token (pubspec/config
  concerns), where `// ignore_for_file:` — already handled by `atOffset` — is the
  meaningful suppression, not a line-level `// ignore:`. Neither demonstrated reproducer
  reaches `atOffset`. Left unchanged; revisit only if a specific offset-reported rule needs
  per-line suppression.

Tests: 4 new cases in `test/utils/ignore_utils_test.dart` (group "leading ignore above a
multi-line enclosing statement"); existing 65 cases still pass. Verified end-to-end with
`dart run saropa_lints scan` — `avoid_recursive_calls` is now suppressed for an `// ignore:`
above a multi-line `return` and still fires on an un-annotated recursive function.

Created: 2026-06-19
Scope: Infrastructure — diagnostic suppression wiring (`SaropaDiagnosticReporter` + `IgnoreUtils`), not a single rule's detection logic
File: `lib/src/saropa_lint_rule.dart` (reporter at ~line 2980), `lib/src/ignore_utils.dart`
Severity: **High** — without working per-line suppression, downstream projects must disable an entire rule in `analysis_options.yaml` to silence one intentional / false-positive site, losing the rule everywhere else in the project.

---

## Summary

Placing an analyzer ignore comment on the line immediately above a `saropa_lints`
diagnostic does **not** suppress that diagnostic when running `dart analyze`. Both the
bare rule-id form (`// ignore: prefer_final_fields`) and the namespaced form the bug
guide recommends (`// ignore: saropa_lints/avoid_recursive_calls`) were tried; both
still report the underlying diagnostic.

By contrast, `// ignore:` for **built-in** analyzer/lints rules in the same files works
correctly (e.g. `// ignore: avoid_print` suppresses the SDK `avoid_print`). The gap is
specific to `saropa_lints`' plugin-emitted diagnostics.

Expected: an `// ignore: <rule_id>` (and/or `// ignore: saropa_lints/<rule_id>`) on the
line above a custom-rule violation suppresses it under `dart analyze`, matching built-in
lint behavior. Actual: not suppressed.

---

## Attribution Evidence

All rules named in this report are defined in `saropa_lints` (`lib/src/rules/`), so the
bug belongs in this repo. Grep results:

```bash
grep -rn "'avoid_recursive_calls'"  lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:615:    'avoid_recursive_calls',

grep -rn "'prefer_final_fields'"    lib/src/rules/
# lib/src/rules/core/class_constructor_rules.dart:2583:    'prefer_final_fields',

grep -rn "'prefer_commenting_analyzer_ignores'" lib/src/rules/
# lib/src/rules/testing/debug_rules.dart:420:    'prefer_commenting_analyzer_ignores',

grep -rn "'document_analyzer_ignore_rationale'" lib/src/rules/
# lib/src/rules/stylistic/stylistic_rules.dart:5373:    'document_analyzer_ignore_rationale',
```

**Emitter:** all `saropa_lints` rules report through a shared wrapper,
`SaropaDiagnosticReporter` (`lib/src/saropa_lint_rule.dart:2980`), whose `atNode` /
`atToken` / `atOffset` methods call the native `AnalysisRule.reportAtNode` /
`reportAtOffset` / `reportAtToken`. Rules do **not** call the raw `reportAtNode`
directly — `grep -rn '\.reportAt' lib/src/rules/` returns 0 matches — so the bug is in
the shared emission/suppression path, not in any one rule.

**Plugin architecture (decisive):** the plugin is built on the **native analyzer plugin
API**, `package:analysis_server_plugin` (`pubspec.yaml:68` → `analysis_server_plugin:
^0.3.14`), via `Plugin` / `AnalysisRule` (`lib/main.dart:36`,
`lib/src/saropa_lint_rule.dart:2083` `abstract class SaropaLintRule extends
AnalysisRule`). It is **not** a `custom_lint` plugin — there is no `PluginBase` /
`createPlugin` / `DartLintRule`. This matters for the fix (see "Suggested Fix"): the
common "extend `DartLintRule`, custom_lint honors `// ignore:` automatically" advice does
not apply, because this plugin handles ignores itself.

---

## Reproducer

**Frequency:** Always (observed in `saropa_drift_advisor`, `saropa_lints` `^14.0.2`, still
present after resolving to `14.0.3`).

### Case 1 — bare rule id, leading comment

```dart
class Entry {
  // ignore: prefer_final_fields -- mutated cross-class via entry.count++
  int count = 1; // STILL LINTS [prefer_final_fields] — should be suppressed
}
```

`dart analyze` still reports `[prefer_final_fields]` on the `int count = 1;` line.

### Case 2 — namespaced form recommended by `BUG_REPORT_GUIDE.md`

The guide's "Common Pitfalls" row "`// ignore:` ignored for a `saropa_lints` rule"
recommends `// ignore: saropa_lints/<rule_name>`:

```dart
List<Object?> normalizeDvrJsonList(List<Object?> value) {
  // ignore: saropa_lints/avoid_recursive_calls -- structural JSON recursion, depth-bounded
  return value
      .map((e) => normalizeDvrJsonValue(e as Object?))
      .toList(growable: false); // STILL LINTS [avoid_recursive_calls]
}
```

`dart analyze` still reports `[avoid_recursive_calls]`.

### Control — built-in rule (works)

```dart
// ignore: avoid_print -- intentional diagnostic output for the CLI scan command
print('saropa_lints scan complete'); // correctly suppressed (SDK avoid_print)
```

The SDK rule's diagnostic IS suppressed, confirming the user's `analysis_options.yaml`
ignore wiring and comment placement are correct, and isolating the failure to
`saropa_lints`-emitted diagnostics.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `// ignore: <rule_id>` (or `// ignore: saropa_lints/<rule_id>`) on the line immediately above a custom-rule violation suppresses it under `dart analyze`, exactly like a built-in lint's `// ignore:` |
| **Actual** | The custom-rule diagnostic is still reported on that line; only built-in-rule ignores are honored |

---

## Key Evidence: the plugin reads the directive but still emits

The two `saropa_lints` rules whose entire purpose is to police ignore comments —
`prefer_commenting_analyzer_ignores` (`lib/src/rules/testing/debug_rules.dart:420`) and
`document_analyzer_ignore_rationale` (`lib/src/rules/stylistic/stylistic_rules.dart:5373`)
— **do** recognize the ignore comment's presence/format (they fire or clear based on it).
That proves the plugin parses the directive line. The underlying diagnostic is
nonetheless emitted, so the failure is in the path that connects "directive seen" to
"diagnostic suppressed", not in comment parsing per se.

The suppression machinery clearly exists and is wired in:

- `SaropaDiagnosticReporter.atNode` calls `_isSuppressed(offset, node)` before
  `_rule.reportAtNode(node)` (`lib/src/saropa_lint_rule.dart:3008`-`3022`).
- `_isSuppressed` calls `IgnoreUtils.hasIgnoreComment(node, _ruleName)`
  (`lib/src/saropa_lint_rule.dart:3090`).
- `IgnoreUtils.hasIgnoreComment` (`lib/src/ignore_utils.dart:226`) walks the node, its
  ancestors, leading/trailing comments, ternary branches, etc., matching the rule name
  via `_commentNamesRule` with `\b<name>\b` word boundaries.

So the report path is designed to honor `// ignore:`. Something in the wiring is not
firing under `dart analyze`. Root-cause hypotheses below isolate where.

---

## Root Cause (hypotheses — need maintainer confirmation against a live `dart analyze`)

The suppression logic exists in source; the question is which branch fails to fire under
`dart analyze`. Candidates, most-to-least likely:

### Hypothesis A — `atToken` path lacks node-level ignore checking (affects `prefer_final_fields`)

`SaropaDiagnosticReporter.atToken` (`lib/src/saropa_lint_rule.dart:3025`-`3055`) checks
baseline, `// ignore_for_file:`, and a token-level leading/trailing ignore
(`IgnoreUtils.hasLeadingIgnoreCommentBeforeToken` /
`hasIgnoreCommentOnToken`) — but it does **not** call `IgnoreUtils.hasIgnoreComment`
(the node/ancestor walk that `atNode` uses via `_isSuppressed`). If `prefer_final_fields`
reports via `atToken` on the field's **name** token, a leading `// ignore:` above the
field declaration attaches to the declaration's first token / the field's variable list,
not to the bare name token. `hasLeadingIgnoreCommentBeforeToken` walks back only across
tokens on the **same line** as the name token (`lib/src/ignore_utils.dart:192`-`199`); a
leading comment on the line *above* may not be reached for a `FieldDeclaration` whose
type/modifiers sit between the comment and the name. **Check:** which reporter method
does `prefer_final_fields` call, and on which token/node?

### Hypothesis B — `atOffset` path has no node-level ignore check at all (affects offset-reported rules)

`atOffset` (`lib/src/saropa_lint_rule.dart:3058`-`3071`) checks only baseline +
`ignore_for_file`. It has **no** line-level `// ignore:` handling at all (the comment in
source even says "File-level only — no AST node available"). Any rule that reports via a
raw offset/length instead of a node or token cannot be suppressed by a line-level
`// ignore:`. **Check:** whether `avoid_recursive_calls` and the other affected rules
ultimately reach `atOffset`.

### Hypothesis C — namespaced form `saropa_lints/<rule>` not specifically parsed

`_commentNamesRule` (`lib/src/ignore_utils.dart:115`-`128`) matches `\b<ruleName>\b`.
With underscores being word characters and `/` a non-word character, `\bavoid_recursive_calls\b`
*should* match inside `saropa_lints/avoid_recursive_calls`. So the namespaced form is not
obviously the failure on its own — which points the namespaced reproducer at the same
underlying `atNode`/`atOffset` gap as the bare form, rather than at name-matching.
**Check:** add a direct unit test of `IgnoreUtils.hasIgnoreComment` with both
`avoid_recursive_calls` and `saropa_lints/avoid_recursive_calls` comment text to confirm
matching is not the failing link.

### Hypothesis D — native plugin under `dart analyze` CLI vs analysis server divergence

The plugin's own `IgnoreUtils` filtering is belt-and-suspenders on top of whatever the
native `analysis_server_plugin` framework does with `// ignore:`. Under the IDE
(analysis server) the framework may apply its own ignore-info filtering to
`AnalysisRule`-emitted diagnostics; under the `dart analyze` CLI path it may not, or may
apply it differently, so the plugin's own filtering becomes the only line of defense — and
if that filtering misses (Hypotheses A/B), nothing suppresses the diagnostic. The user
reports `dart analyze` as the failing ground truth. **Check:** does the same `// ignore:`
suppress the diagnostic inside VS Code (analysis server) while failing under
`dart analyze`? A CLI-only failure points squarely at the framework's CLI ignore-info path
not being applied to native-plugin diagnostics.

---

## Suggested Fix

This plugin is **not** `custom_lint`; it is a native `analysis_server_plugin`
`AnalysisRule` plugin. The fix is therefore about routing every report path through a
single node-aware ignore check (and/or letting the framework's ignore-info filter run),
not about switching to `DartLintRule`.

1. **Unify the three report paths on node-level ignore checking.** `atNode` already calls
   `_isSuppressed` → `IgnoreUtils.hasIgnoreComment`. Give `atToken` and `atOffset` the
   same node-level check whenever a node is available. Concretely:
   - For `atToken`: in addition to the existing token checks, when the diagnostic
     corresponds to a declaration name, resolve the enclosing node and run
     `IgnoreUtils.hasIgnoreComment(enclosingNode, _ruleName)` so a leading `// ignore:`
     above the declaration suppresses it (closes Hypothesis A).
   - For `atOffset`: where rules can pass the originating node, add an optional node
     parameter and route through `_isSuppressed`, so offset-reported diagnostics gain
     line-level `// ignore:` handling (closes Hypothesis B). Where genuinely no node
     exists, document that limitation in the rule's docs.
2. **Verify the framework ignore-info filter under `dart analyze`.** Confirm whether
   `analysis_server_plugin` applies the analyzer's `IgnoreInfo` filtering to
   `AnalysisRule`-emitted diagnostics on the CLI path. If it does, the plugin's manual
   `IgnoreUtils` filter is redundant and the real fix is to stop the manual path from
   *also* needing to fire; if it does not, the manual `IgnoreUtils` path is load-bearing
   and Hypotheses A/B are the whole bug (closes Hypothesis D).
3. **Confirm name matching for the namespaced form.** Add a direct
   `IgnoreUtils.hasIgnoreComment` unit test for both `avoid_recursive_calls` and
   `saropa_lints/avoid_recursive_calls` (closes Hypothesis C). If the namespaced form does
   not match, extend `_commentNamesRule` to strip a leading `saropa_lints/` plugin
   namespace before the `\b` match.
4. **Document the exact accepted ignore syntax** for `saropa_lints` rules in the rule
   docs / README once the path is fixed, and update the `BUG_REPORT_GUIDE.md`
   "Common Pitfalls" row to state the verified working form.

---

## Fixture / Test Gap

Add fixtures + unit tests asserting suppression actually fires under the real report
paths, not just that `IgnoreUtils` returns `true` in isolation:

1. `prefer_final_fields` — field with a leading `// ignore: prefer_final_fields` on the
   line above → expect **NO** diagnostic. (Exercises the `atToken` path, Hypothesis A.)
2. `avoid_recursive_calls` — recursive function with leading
   `// ignore: avoid_recursive_calls` and with
   `// ignore: saropa_lints/avoid_recursive_calls` → expect **NO** diagnostic in both.
   (Exercises `atNode`/`atOffset` + the namespaced form, Hypotheses B/C.)
3. A control with a built-in rule (`avoid_print`) to confirm the harness reflects real
   `dart analyze` ignore behavior.
4. A direct `IgnoreUtils.hasIgnoreComment` test covering the bare and `saropa_lints/`-
   prefixed comment text.

---

## Impact / Downstream Evidence

In `saropa_drift_advisor`, the inability to annotate individual intentional sites forced
**whole rules** to be disabled in `analysis_options.yaml` (e.g.
`prefer_logger_over_print`, `require_log_level_for_production`, and several
confirmed-false-positive rules), because a single `// ignore:` could not silence one
site without losing the rule project-wide. That is exactly the failure this report's
**High** severity describes: per-line suppression is the only mechanism that lets a
downstream project keep a rule while exempting one justified location.

---

## Environment

- saropa_lints version: **14.0.3** (was `^14.0.2` when first observed; bug persists)
- Plugin framework: `analysis_server_plugin: ^0.3.14` (native analyzer plugin API, **not**
  custom_lint)
- Dart SDK version: **3.12.1**
- custom_lint: run via CLI in the downstream toolchain; `dart analyze` used as the ground
  truth for this report (per `BUG_REPORT_GUIDE.md`, prefer `dart analyze` / CI over the
  IDE plugin cache)
- Triggering project: `saropa_drift_advisor`
- Affected report paths: `SaropaDiagnosticReporter.atToken` / `atOffset`
  (`lib/src/saropa_lint_rule.dart:3025`, `:3058`); node-level check
  `IgnoreUtils.hasIgnoreComment` (`lib/src/ignore_utils.dart:226`)

---

## Finish Report (2026-06-19)

### Defect

`IgnoreUtils.hasIgnoreComment` failed to honor a leading `// ignore:` directive when the
diagnostic was reported on an AST node nested inside a multi-line statement and that node
sat on a later line than the statement keyword. The headline case was
`avoid_recursive_calls`, which reports on the inner self-call `MethodInvocation`; an
`// ignore: avoid_recursive_calls` written above a multi-line `return` never suppressed it.

### Root cause

`hasIgnoreComment` computed a single `nodeStartLine` from the flagged leaf node and then
walked the leaf's ancestors, passing that **leaf** line to every ancestor's leading-comment
check. The placement guard in `_hasValidLeadingIgnoreComment` requires
`commentLine == referenceLine - 1` (directive on the line immediately above). For an
enclosing statement whose first line differs from the leaf's line, the guard compared the
directive against the wrong line and never matched, so the suppression was silently dropped.
The single-line case worked only because leaf line and statement line coincided.

### Fix

In the ancestor walk (`lib/src/ignore_utils.dart`), recompute each ancestor's own start
line from `current.offset` instead of reusing the leaf's `nodeStartLine`. For an
`AnnotatedNode`, the reference offset is taken from `firstTokenAfterCommentAndMetadata`
rather than `current.offset`, because an annotated declaration's `offset` points at its
`///` doc-comment token while the leading `// ignore:` (and the post-doc probe in
`_nodeHasLeadingIgnore`) hangs off the declaration keyword — using `current.offset` there
would have regressed the doc-commented-field suppression case.

### Scope decisions

- `prefer_final_fields` (report Case 1) was already suppressed by the existing node path;
  the report's premise that it routes through `atToken` does not hold for current source.
- `atOffset` (report Hypothesis B) was left unchanged: every in-repo `atOffset` caller is a
  file/line/word-level diagnostic anchored at the unit's first token (pubspec/config), where
  `// ignore_for_file:` — already handled — is the meaningful suppression. No demonstrated
  reproducer reaches `atOffset`.

### Verification

- `test/utils/ignore_utils_test.dart`: 4 new cases under "leading ignore above a multi-line
  enclosing statement" (deeper-line node, same-line node, no-directive control, unrelated
  rule name); full file 69 cases pass. `test/integrity/defensive_coding_test.dart` (52)
  unaffected.
- End-to-end via `dart run saropa_lints scan`: `avoid_recursive_calls` is suppressed for an
  `// ignore:` above a multi-line `return` and still fires on an un-annotated recursive
  function.
- Scoped `dart analyze` of the changed files: no issues.

### Files

- `lib/src/ignore_utils.dart` — ancestor-walk per-node reference-line fix.
- `test/utils/ignore_utils_test.dart` — regression group.
- `CHANGELOG.md` — user-facing Fixed entry under `[Unreleased]`.
