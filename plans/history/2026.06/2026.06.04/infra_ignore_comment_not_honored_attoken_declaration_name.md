# BUG: `atToken(node.nameToken)` reports — a leading `// ignore:` above the declaration is never honored

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-04
Rule: infrastructure — affects EVERY rule that reports via `reporter.atToken(node.nameToken)` (declaration-name reporting). Confirmed users: `prefer_value_listenable_builder` (`performance_rules.dart:1504`), `avoid_global_key_misuse` (`performance_rules.dart:1618`).
File: `lib/src/saropa_lint_rule.dart` (`SaropaDiagnosticReporter.atToken`, line ~3025); `lib/src/ignore_utils.dart` (`hasIgnoreCommentOnToken`, line ~109)
Severity: High — for these rules there is NO working line-level suppression. A correctly-placed `// ignore:` on the line above the declaration is silently dropped; only `// ignore_for_file:` works.
Rule version: n/a (suppression infra) | Since: at least v13.11.11 | Updated: —

---

## Summary

When a rule reports on a declaration by its name token (`reporter.atToken(node.nameToken)`), suppression flows through `IgnoreUtils.hasIgnoreCommentOnToken`, which inspects only the **name token's own** `precedingComments`. A `// ignore:` written on the line immediately above the declaration attaches to the declaration's **first token** (e.g. the `class` keyword), not the name token, so it is never found. `atToken` does no ancestor walk and no `firstTokenAfterCommentAndMetadata` fallback. Net: line-level `// ignore:` cannot suppress any `atToken(nameToken)` diagnostic.

This is a sibling of `infra_ignore_comment_shadowed_by_doc_comment.md` (which is the `atNode` / `hasIgnoreComment` / doc-comment variant). Same root theme — a leading `// ignore:` lands on the declaration's first token, but suppression checks the wrong token — but a distinct code path.

---

## Attribution Evidence

```text
# The reporter path with no ancestor walk
lib\src\saropa_lint_rule.dart:3025:  void atToken(Token token, [LintCode? code]) {
lib\src\saropa_lint_rule.dart:3035:    if (IgnoreUtils.hasIgnoreCommentOnToken(token, _ruleName)) {

# The helper that only checks token.precedingComments
lib\src\ignore_utils.dart:109:  static bool hasIgnoreCommentOnToken(Token? token, String ruleName) {

# Rules that report via atToken(node.nameToken)
lib\src\rules\core\performance_rules.dart:1504:        reporter.atToken(node.nameToken, code);  // prefer_value_listenable_builder
lib\src\rules\core\performance_rules.dart:1618:        reporter.atToken(node.nameToken, code);  // avoid_global_key_misuse
```

**Diagnostic `source` / `owner` as seen in Problems panel:** `dart`, owner `_generated_diagnostic_collection_name_#2` (e.g. code `prefer_value_listenable_builder`, reported at the class-name column).

---

## Reproducer

```dart
// ignore: prefer_value_listenable_builder -- correctly placed, line directly above
class FooState extends State<Foo> {   // diagnostic STILL fires on `FooState`
  int _x = 0;
  void bump() => setState(() => _x++);
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

**Frequency:** Always, for any `atToken(node.nameToken)` diagnostic with a leading line-level `// ignore:`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `// ignore: <rule>` on the line immediately above the declaration suppresses the diagnostic reported on the declaration's name token (matches analyzer's line-based `// ignore:` semantics). |
| **Actual** | Not suppressed. Only `// ignore_for_file: <rule>` (raw string match via `isIgnoredForFile`) works. |

---

## AST Context

Token attachment, verified with a `package:analyzer` `parseString` probe on the reproducer:

```
classKeyword="class"   precedingComments=[// ignore: prefer_value_listenable_builder -- ...]   ← the ignore lives HERE
nameToken="FooState"   precedingComments=<null>                                                 ← atToken checks HERE → not found
```

The parser attaches all comments preceding a token to that token's `precedingComments`; the first real token after the `// ignore:` line is the `class` keyword, so the directive hangs off `class`, not the name. `hasIgnoreCommentOnToken(nameToken)` walks `nameToken.precedingComments` (null) and returns false.

---

## Root Cause

`SaropaDiagnosticReporter.atToken` (`saropa_lint_rule.dart:3025-3041`) checks suppression with only:

- `_isBaselined(token.offset)`
- `_isIgnoredForFile()` (raw string match — this is why `ignore_for_file` works)
- `IgnoreUtils.hasIgnoreCommentOnToken(token, _ruleName)` — inspects `token.precedingComments` ONLY (`ignore_utils.dart:109-123`)

There is no ancestor walk (unlike `atNode` → `_isSuppressed` → `hasIgnoreComment`) and no awareness that `token` is a declaration name whose leading comment is attached to the enclosing declaration's first token. So the leading `// ignore:` is unreachable.

---

## Suggested Fix

Make declaration-name reporting honor the same leading `// ignore:` that the analyzer's line-based mechanism (and developers) expect. Options:

1. **Preferred — report the declaration node, not the bare name token.** Add a reporter overload such as `atNamedDeclaration(Declaration node)` (or pass the owning node alongside the token) that highlights the name range but runs suppression through the node path (`_isSuppressed` → `hasIgnoreComment`). Then fix `hasIgnoreComment` to also probe `firstTokenAfterCommentAndMetadata.precedingComments` for `AnnotatedNode`s (see sibling report `infra_ignore_comment_shadowed_by_doc_comment.md`) so the leading and doc-commented-leading cases both resolve. Migrate `performance_rules.dart:1504` and `:1618` (and any other `atToken(node.nameToken)` sites) to it.
2. **Cheaper — make `atToken` line-aware.** Give `atToken` access to the unit `LineInfo` and walk backward from `token` to the first token of `token`'s line, then check that token's `precedingComments` for a standalone `// ignore:` on the line above (the same `commentLine == nodeStartLine - 1` + start-of-line validation `hasIgnoreComment` already uses). This keeps the token-only call sites unchanged.
3. At minimum, document that `atToken`-reported diagnostics are only suppressible via `// ignore_for_file:`, so downstream users stop placing line-level ignores that silently do nothing.

Audit for affected call sites: `grep -rn "atToken(node.nameToken" lib/src/rules/` (and any `atToken(` on a declaration's identifier/name token).

---

## Fixture Gap

Add suppression fixtures driven by a rule that reports via `atToken(node.nameToken)`:

1. **Leading `// ignore: <rule>` directly above the declaration** — expect NO diagnostic.
2. **Leading `// ignore:` above a `///`-doc-commented declaration** — expect NO diagnostic (overlaps the doc-comment sibling bug).
3. **`// ignore_for_file: <rule>`** — expect NO diagnostic (already works; regression guard).
4. **No ignore** — expect diagnostic (control).

---

## Changes Made

Chose the analyzer-consistent token-walkback over migrating ~46 `atToken(node.nameToken)` call sites. Routing through the node path (`hasIgnoreComment`) was rejected: it computes `nodeStartLine` from `node.offset`, which for a doc-commented declaration points at the `///` line, leaving the standard `///`-then-`// ignore:`-then-declaration ordering unsuppressed (the doc-comment sibling fix's documented "Known remaining gap"). Keying off the diagnostic token's own line resolves that ordering AND matches the analyzer's line-based `// ignore:` semantics (suppresses only the line immediately below the directive). Token/comment attachment for every case was verified with a `package:analyzer` `parseString` probe before coding.

`lib/src/ignore_utils.dart`:
- Added `hasLeadingIgnoreCommentBeforeToken(Token, String ruleName, LineInfo?)`. It walks back across the tokens sharing the diagnostic token's line to reach the line-leading token (e.g. the `class` keyword, where a leading `// ignore:` actually attaches), then reuses the unchanged `_hasValidLeadingIgnoreComment` placement guard. Returns false when `lineInfo` is null.
- Fixed `_isCommentAtLineStart`: a synthetic start-of-file token has offset `-1`, and `lineInfo.getLocation(-1)` clamps to line 1, which spuriously matched a line-1 comment's line and mislabeled a genuine first-line `// ignore:` as trailing. Now guarded with `prevToken.offset >= 0`. This also closes a latent gap for the node path when a declaration sits at the very top of a file.

`lib/src/saropa_lint_rule.dart`:
- `SaropaDiagnosticReporter.atToken` now checks `hasLeadingIgnoreCommentBeforeToken(token, _ruleName, currentUnit.lineInfo)` OR the legacy `hasIgnoreCommentOnToken`. OR semantics guarantee every previously-suppressed site stays suppressed — the change can only ever suppress MORE, never fewer. `currentUnit` is the unit under analysis during the synchronous callback, so its `lineInfo` matches the token (consistent with the existing token-path baseline/ignore-for-file checks).

The annotation case (a `// ignore:` placed above an `@`-annotation block, two lines above the name) is intentionally NOT suppressed: the diagnostic is reported on the name line, and the analyzer suppresses only the line directly below the directive. Honoring it would diverge from analyzer semantics.

---

## Tests Added

`test/utils/ignore_utils_test.dart` — new group `hasLeadingIgnoreCommentBeforeToken` (11 cases), driven by a `ClassDeclaration`'s `nameToken` (the exact `atToken(node.nameToken)` shape):
1. Leading `// ignore:` directly above the declaration → suppressed (the bug).
2. Same, declaration at the very top of file → suppressed (synthetic `-1` token regression guard).
3. `///` doc block then `// ignore:` adjacent to the declaration → suppressed (the doc-ordering case the node path missed).
4. Hyphenated rule name → suppressed.
5. Mid-file declaration with a leading `// ignore:` → suppressed.
6. `// ignore:` above an `@deprecated` block → NOT suppressed (analyzer-consistent).
7. `// ignore:` two lines up with a `///` between → NOT suppressed.
8. Different rule name → NOT suppressed.
9. No ignore → NOT suppressed (control).
10. Trailing `// ignore:` on prior code → NOT suppressed (not mistaken for leading).
11. Null `lineInfo` → false.

Verified end-to-end through the real reporter path with the `scan` CLI on the reproducer plus an un-ignored sibling state class: `prefer_value_listenable_builder` fires only on the un-ignored class; the `// ignore:`-annotated class is suppressed (both fired before the fix).

Regression suite: `test/utils/ignore_utils_test.dart` (55), and the suppression-exercising files `test/integrity/anti_pattern_detection_test.dart`, `test/integrity/defensive_coding_test.dart`, `test/rules/stylistic/formatting_rules_test.dart`, `test/rules/testing/debug_rules_test.dart` — 193 total, all pass. `dart analyze --fatal-infos` clean.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.11.11 (path/published parity; downstream `contacts` pins `^13.11.11`)
- Dart SDK version: 3.12.0 (stable)
- custom_lint version: n/a — runs as a native `analysis_server_plugin`
- Triggering project/file: `saropa/contacts` — `lib/components/contact/culture/culture_multi_select_dialog.dart:82` (`prefer_value_listenable_builder` on `_CultureMultiSelectEditorState`, line-81 `// ignore:` ineffective).

---

## Related

- `infra_ignore_comment_shadowed_by_doc_comment.md` — the `atNode` / `beginToken` / doc-comment variant of the same "leading `// ignore:` attaches to the wrong token" theme. A single fix to `hasIgnoreComment` + a node-based name reporter would close both.
- `plans/history/2026.06/2026.06.04/prefer_value_listenable_builder_false_positive_inplace_mutation_final_collection.md` — the FP that made this suppression gap visible (fixed and archived 2026-06-04).

---

## Finish Report (2026-06-04)

**Scope:** (A) Dart analyzer-plugin suppression infrastructure. Touched `lib/src/ignore_utils.dart`, `lib/src/saropa_lint_rule.dart`, `test/utils/ignore_utils_test.dart`, plus `CHANGELOG.md`. No new rule, so no `tiers.dart` / `LintImpact` / ROADMAP rule changes — suppression is cross-cutting infra.

**Approach chosen (and rejected alternative):** The bug proposed two fixes. The "preferred" node-based reporter (Option 1) was rejected: routing `atToken` through `hasIgnoreComment(node)` computes `nodeStartLine` from `node.offset`, which for a doc-commented declaration is the `///` line — leaving the standard `///`-then-`// ignore:`-then-declaration ordering unsuppressed (this is exactly the doc-comment sibling fix's documented "Known remaining gap"). It would also have required migrating ~46 `atToken(node.nameToken)` call sites. Instead implemented an analyzer-consistent token-walkback (Option 2 refined): key off the diagnostic token's OWN line, walk back to the line-leading token where the directive actually attaches, and reuse the existing placement guard. This resolves the doc-ordering case AND matches the analyzer's line-based `// ignore:` semantics (suppresses only the line immediately below the directive), with zero call-site churn.

**Empirical verification before coding:** token/comment attachment was probed with `package:analyzer` `parseString` for all four orderings (simple leading, doc-then-ignore, ignore-then-doc, ignore-above-annotation). The probe exposed a latent bug: a declaration at the very top of a file has a synthetic start-of-file `previous` token with offset `-1`, and `lineInfo.getLocation(-1)` clamps to line 1, which made `_isCommentAtLineStart` mislabel a genuine first-line `// ignore:` as trailing. Fixed with a `prevToken.offset >= 0` guard — this also closes the same latent gap on the node path.

**Changes:**
- `lib/src/ignore_utils.dart`: added `hasLeadingIgnoreCommentBeforeToken(Token, String, LineInfo?)`; guarded `_isCommentAtLineStart` against the synthetic `-1` token.
- `lib/src/saropa_lint_rule.dart`: `atToken` now checks the new helper OR the legacy `hasIgnoreCommentOnToken` (can only ever suppress MORE — every previously-working suppression preserved).

**Tests:** `test/utils/ignore_utils_test.dart` — new `hasLeadingIgnoreCommentBeforeToken` group (11 cases: leading, top-of-file, doc-then-ignore, hyphenated, mid-file, annotation-non-suppress, two-lines-up-non-suppress, wrong-rule, control, trailing-not-leading, null-lineInfo). File: 55 pass. Suppression-exercising regression files (`anti_pattern_detection`, `defensive_coding`, `formatting_rules`, `debug_rules`) + this file: 193 pass. `dart analyze --fatal-infos` clean. End-to-end through the real reporter via the `scan` CLI on the reproducer plus an un-ignored sibling `State` class: `prefer_value_listenable_builder` fires only on the un-ignored class (both fired pre-fix).

**Annotation case is intentionally NOT suppressed:** a `// ignore:` above an `@`-annotation block sits two lines above the name token the diagnostic reports on; the analyzer suppresses only the line directly below the directive, so honoring it would diverge from analyzer semantics.

**CHANGELOG:** added a `### Fixed` bullet to the existing `[Unreleased]` section (which already carried the related `prefer_value_listenable_builder` in-place-mutation bullet) and widened that section's overview to cover both fixes.

**Outstanding:** none for this bug. The sibling `infra_ignore_comment_shadowed_by_doc_comment.md` (already Fixed/archived) noted a node-path "Known remaining gap" for direct-on-doc-commented-node reports; that path is unchanged here (this fix is token-path only) and remains as previously documented — not regressed, not in scope.
