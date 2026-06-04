# BUG: `atToken(node.nameToken)` reports — a leading `// ignore:` above the declaration is never honored

**Status: Open**

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

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

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
