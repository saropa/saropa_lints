# BUG: `IgnoreUtils.hasIgnoreComment` — `// ignore:` between a `///` doc comment and a declaration is silently shadowed (suppression never fires)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-03
Rule: infrastructure — affects EVERY rule that reports on a child node of a doc-commented declaration. First surfaced via `avoid_missing_enum_constant_in_map`.
File: `lib/src/ignore_utils.dart` (`hasIgnoreComment`, line ~142); consumed by `lib/src/saropa_lint_rule.dart` (`_isSuppressed`, line ~3067)
Severity: High — a correctly-placed `// ignore:` is ignored, so teams cannot suppress a diagnostic on any declaration that carries a `///` doc comment. There is no working narrow-suppression for these sites.
Rule version: n/a (suppression infra) | Since: at least v13.11.11 | Updated: —

---

## Summary

When a `// ignore: <rule>` directive is placed on the line immediately above a declaration that ALSO carries a `///` documentation comment, the directive is not honored: the diagnostic still fires. The directive works fine when the declaration has no doc comment. The cause is that `IgnoreUtils.hasIgnoreComment` walks each ancestor's `beginToken.precedingComments`, and for an `AnnotatedNode` (e.g. `FieldDeclaration`) carrying a doc comment, `beginToken` resolves to the **doc-comment token**, whose own `precedingComments` is `null`. The `// ignore:` is attached to `firstTokenAfterCommentAndMetadata` (the real keyword, e.g. `static`), which the walker never inspects.

---

## Attribution Evidence

The suppression mechanism is saropa_lints' own code (the analyzer's built-in line-based `// ignore:` is not what runs here; rules call `reporter.atNode`, which routes through `_isSuppressed` → `IgnoreUtils.hasIgnoreComment`).

```text
# Rule that surfaced the bug — IS defined here
lib\src\rules\code_quality\code_quality_variables_rules.dart:147: 'avoid_missing_enum_constant_in_map',

# The suppression helper — IS defined here
lib\src\ignore_utils.dart:142:  static bool hasIgnoreComment(AstNode node, String ruleName) { ... }

# The reporter that calls it
lib\src\saropa_lint_rule.dart:3008:  void atNode(AstNode node, [LintCode? code]) { ... }
lib\src\saropa_lint_rule.dart:3067:  bool _isSuppressed(int offset, AstNode node) { ... }
lib\src\saropa_lint_rule.dart:3076:    if (IgnoreUtils.hasIgnoreComment(node, _ruleName)) {
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:143` (`AvoidMissingEnumConstantInMapRule`), reported via `reporter.atNode(node)` at `code_quality_variables_rules.dart:204`.
**Suppression class:** `IgnoreUtils` (`lib/src/ignore_utils.dart`), `SaropaDiagnosticReporter._isSuppressed` (`lib/src/saropa_lint_rule.dart:3067`).
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart`, owner `_generated_diagnostic_collection_name_#2`, code `avoid_missing_enum_constant_in_map`.

---

## Reproducer

Minimal Dart code. Both fields have a correctly-placed `// ignore:` on the line immediately above the declaration. Only the doc-commented one keeps firing.

```dart
enum Scope { all, contacts, emergency }

class A {
  // ignore: avoid_missing_enum_constant_in_map -- all intentionally absent
  static const Map<Scope, int> caseNoDoc = <Scope, int>{   // OK — suppressed
    Scope.contacts: 10,
    Scope.emergency: 5,
  };

  /// Doc line one.
  /// Doc line two.
  // ignore: avoid_missing_enum_constant_in_map -- all intentionally absent
  static const Map<Scope, int> caseWithDoc = <Scope, int>{ // BUG — still LINTS
    Scope.contacts: 10,
    Scope.emergency: 5,
  };
}
```

**Frequency:** Always, whenever the suppressed declaration carries a `///` doc comment AND the rule reports on a child node (here the `<Scope,int>{...}` initializer) rather than the `FieldDeclaration` itself.

Real-world site that triggered this report: `d:\src\contacts\lib\views\home\home_tab.dart:1353` (`_capByScope`), where a `// ignore:` on line 1352 sits below a `///` block (1340–1349) and is not honored.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `// ignore: avoid_missing_enum_constant_in_map` on the line above the declaration suppresses the diagnostic, regardless of a preceding `///` doc comment. |
| **Actual** | Diagnostic is suppressed when no doc comment is present, but still fires when a `///` doc comment precedes the `// ignore:`. |

---

## AST Context

The rule reports on the map literal (an initializer), NOT on the `FieldDeclaration`. `hasIgnoreComment` therefore walks UP from the literal, checking each ancestor's `beginToken.precedingComments`:

```
FieldDeclaration (static const Map<Scope,int> caseWithDoc = ...)   ← ancestor checked
  ├─ documentationComment  ///Doc line one. /// Doc line two.
  └─ VariableDeclarationList (const Map<Scope,int> ...)
        └─ VariableDeclaration (caseWithDoc = <Scope,int>{...})
              └─ SetOrMapLiteral <Scope,int>{...}                   ← node reported here
```

Token-structure probe (parsed with `package:analyzer` `parseString`) — the decisive evidence:

```
--- caseNoDoc ---
  ancestor=FieldDeclaration beginToken="static" isCommentToken=false
      precedingComments=[// ignore: ... case no doc]                ← walker finds it → SUPPRESSED

--- caseWithDoc ---
  ancestor=FieldDeclaration beginToken="/// Doc line one." isCommentToken=true
      precedingComments=<null>                                      ← walker reads null → NOT suppressed
    firstTokenAfterCommentAndMetadata="static"
      precedingComments=[/// Doc line one.][/// Doc line two.][// ignore: ... case with doc]
                                                                    ← the ignore lives HERE, never inspected
```

`AnnotatedNodeImpl.beginToken` returns `documentationComment.beginToken` when a doc comment is present. A `CommentToken`'s own `precedingComments` is `null`, so the chain that actually holds the `// ignore:` (hanging off `firstTokenAfterCommentAndMetadata`) is never walked.

---

## Root Cause

### Confirmed mechanism

`IgnoreUtils.hasIgnoreComment` (`lib/src/ignore_utils.dart:142`) inspects ignore comments only via `token.precedingComments`, and the tokens it inspects are each ancestor's `beginToken` (line ~239: `_hasValidLeadingIgnoreComment(current.beginToken, ...)`), plus the node's own `beginToken` (line ~154).

For a `FieldDeclaration` (or any `AnnotatedNode`) with a `///` doc comment:
- `beginToken` == the first doc-comment token (`/// Doc line one.`).
- A `CommentToken.precedingComments` is `null`.
- The `// ignore:` directive is in `firstTokenAfterCommentAndMetadata.precedingComments` (the `static` keyword's chain), which `hasIgnoreComment` never reads.

Net: the leading-ignore check returns `false` for every doc-commented declaration, so `_isSuppressed` (`saropa_lint_rule.dart:3076`) returns `false` and the diagnostic is reported.

The same gap applies to the node's own `beginToken` check and to every ancestor's `beginToken` check — none of them dereference `firstTokenAfterCommentAndMetadata` for `AnnotatedNode`s.

### Why it only bites "child-node" diagnostics

When a rule reports directly on the `FieldDeclaration` (an `AnnotatedNode`), `atNode` takes the `node is AnnotatedNode` branch (`saropa_lint_rule.dart:3009`) and computes `adjustedOffset = node.firstTokenAfterCommentAndMetadata.offset` — but suppression still flows through `_isSuppressed(adjustedOffset, node)` → `hasIgnoreComment(node, ...)`, which again checks `node.beginToken` (the doc comment). So even direct-on-declaration reports can be affected; the map-literal case just makes it obvious because the reported node is a descendant.

---

## Suggested Fix

In `IgnoreUtils.hasIgnoreComment` (`lib/src/ignore_utils.dart`), wherever an ancestor (or the node itself) is an `AnnotatedNode`, ALSO check `firstTokenAfterCommentAndMetadata.precedingComments`, not only `beginToken.precedingComments`.

Concretely, in the ancestor walk (around line 239) and the initial begin-token check (around line 154), add:

```dart
// AnnotatedNode.beginToken resolves to the doc-comment token when a ///
// block is present; that CommentToken's own precedingComments is null, so
// the // ignore: directive (which hangs off firstTokenAfterCommentAndMetadata)
// is invisible to a beginToken-only walk. Inspect the post-doc token too.
final Token probe = current is AnnotatedNode
    ? current.firstTokenAfterCommentAndMetadata
    : current.beginToken;
if (_hasValidLeadingIgnoreComment(probe, ruleName, nodeStartLine, lineInfo)) {
  return true;
}
```

Apply the same `firstTokenAfterCommentAndMetadata` fallback to the node's own initial check at line ~154 when `node` is an `AnnotatedNode`. (The map-literal node is not annotated, but doing this keeps direct-on-declaration reports correct too.)

Note: `_hasValidLeadingIgnoreComment`'s `commentLine == nodeStartLine - 1` guard already handles the "ignore must be on the line directly above" requirement, so widening the token probed does not loosen placement rules — the `/// Doc` lines themselves won't match because they don't contain `ignore:`.

---

## Fixture Gap

The fixture for ignore handling should cover doc-commented declarations. Add cases that pair a `///` block with a `// ignore:` directly above a declaration whose diagnostic targets a child node:

1. **Field with `///` doc + `// ignore:` above an incomplete enum-keyed map** — expect NO lint (suppression must work).
2. **Field with NO doc + `// ignore:` above the same map** — expect NO lint (regression guard for the path that already works).
3. **Field with `///` doc but NO `// ignore:`** — expect LINT (control; suppression must not over-fire).
4. **Top-level / method-local variant** to confirm the fix is not field-specific.

A unit test should assert the reported-diagnostic count is 0 for cases 1–2 and 1 for case 3, using a resolved-AST harness (the standalone `scan` CLI uses unresolved ASTs and cannot exercise this rule, which needs enum type resolution).

---

## Changes Made

`lib/src/ignore_utils.dart`:
- Added private helper `_nodeHasLeadingIgnore(node, ruleName, nodeStartLine, lineInfo)`. It checks `node.beginToken` AND, for an `AnnotatedNode` whose `firstTokenAfterCommentAndMetadata` differs from `beginToken`, the post-doc token too.
- `hasIgnoreComment` now calls `_nodeHasLeadingIgnore(...)` for both the node's-own check (line ~154) and the ancestor walk (line ~239), replacing the bare `_hasValidLeadingIgnoreComment(node.beginToken, ...)`.

Why BOTH tokens, not a replacement:
- For an `AnnotatedNode` with a `///` block, `beginToken` is the doc-comment token (a `CommentToken` whose own `precedingComments` is null), while the post-doc token (e.g. `static`) holds the doc lines AND the `// ignore:`. Probing the post-doc token is the doc-comment fix.
- But for an annotated declaration with NO doc comment (e.g. an inline `@Deprecated('x') static const ...`), `beginToken` is the `@` metadata token, which is where the `// ignore:` attaches; `firstTokenAfterCommentAndMetadata` (the `static`) does NOT hold it. A first cut that *replaced* `beginToken` with the post-doc token regressed this case. Keeping the `beginToken` probe and ADDING the post-doc probe fixes the doc case with zero regression: every site the old code suppressed is still covered by the unchanged `beginToken` check.

The `commentLine == nodeStartLine - 1` placement guard in `_hasValidLeadingIgnoreComment` is untouched, so widening the tokens inspected does not loosen the "ignore must be on the line directly above" rule (the `///` lines never match — they contain no `ignore:`).

---

## Tests Added

`test/utils/ignore_utils_test.dart` — new group `// ignore: below a /// doc comment` (5 cases), reporting on the child map-literal node so suppression flows through the ancestor walk:
1. Doc-commented field + `// ignore:` → suppressed (the bug; fails pre-fix).
2. No doc + `// ignore:` → suppressed (regression guard for the path that already worked).
3. Doc comment but NO `// ignore:` → NOT suppressed (control; suppression must not over-fire).
4. Inline-annotated field with NO doc + `// ignore:` → suppressed (regression guard proving the post-doc probe was ADDED, not substituted, for the `@`-metadata-token case).
5. Doc-commented top-level variable + `// ignore:` → suppressed (confirms the fix is not field-specific).

All 44 tests in the file pass. Also ran the four other test files whose fixtures contain `// ignore:` (`anti_pattern_detection`, `plan_additional_rules_31_40`, `formatting_rules`, `debug_rules`) plus `defensive_coding_test` — 101 + 52 pass, confirming no over-suppression regression. `dart analyze --fatal-infos` clean on the changed files.

Note: these exercise `IgnoreUtils.hasIgnoreComment` directly against the parsed (unresolved) AST, which is sufficient because the helper is purely token/comment-based. The resolved-AST harness called for in "Fixture Gap" would only be needed to drive the full `avoid_missing_enum_constant_in_map` rule end-to-end (enum type resolution); the suppression logic itself does not need it.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.11.11 (path/published parity — `d:\src\saropa_lints\pubspec.yaml` version 13.11.11; downstream `contacts` pins `^13.11.11`)
- Dart SDK version: 3.12.0 (stable)
- custom_lint version: n/a — saropa_lints runs as a native `analysis_server_plugin` (top-level `plugins:` block), not via custom_lint
- Triggering project/file: `d:\src\contacts\lib\views\home\home_tab.dart:1353` (`_capByScope`); reduced reproducer above verified with a `package:analyzer` `parseString` token probe.

---

## Finish Report (2026-06-03)

**Scope:** (A) Dart analyzer-plugin infrastructure. Touched `lib/src/ignore_utils.dart` (suppression helper) and `test/utils/ignore_utils_test.dart`. No new rule, so no `tiers.dart` / `LintImpact` / ROADMAP changes (suppression is cross-cutting infra, not a rule).

**Deep review outcome:** A first cut replaced the `beginToken` probe with `firstTokenAfterCommentAndMetadata`. Review caught that this regresses annotated declarations with no doc comment, where the `// ignore:` attaches to the `@` metadata token (== `beginToken`) and NOT to the post-doc keyword token. Final fix ADDS the post-doc probe via `_nodeHasLeadingIgnore` and keeps the `beginToken` probe, so the change can only ever suppress MORE (never fewer) sites than before — every previously-working suppression is preserved by the unchanged `beginToken` check.

**Known remaining gap (out of scope, not regressed):** when a rule reports DIRECTLY on a doc-commented `AnnotatedNode` (not a child node), `hasIgnoreComment` computes `nodeStartLine` from `node.offset`, which for an annotated node points at the doc-comment line, so a `// ignore:` below the doc may fall outside the `commentLine == nodeStartLine - 1` window. This pre-existing behavior is unchanged by this fix; the reported bug (child-node diagnostics, e.g. the map literal) is fully resolved. Not widened here to avoid loosening placement semantics without a separate reproducer.

**Tests:** `dart test test/utils/ignore_utils_test.dart` → 44 pass. Suppression-exercising rule tests (`anti_pattern_detection`, `plan_additional_rules_31_40`, `formatting_rules`, `debug_rules`) → 101 pass. `defensive_coding_test` (IgnoreUtils consumer) → 52 pass. `dart analyze --fatal-infos` on the changed files → no issues.

**CHANGELOG:** `### Fixed` bullet added under a new `[Unreleased]` section. (That section concurrently picked up an unrelated `pass_existing_stream_to_stream_builder` bullet from a parallel workstream; left in place — it is harmless docs and its code lands in a sibling commit.)

**Not committed (separate workstream):** `lib/src/rules/widget/widget_lifecycle_rules.dart`, `example/lib/widget_lifecycle/pass_existing_stream_to_stream_builder_fixture.dart`, `bugs/pass_existing_stream_to_stream_builder_missing_cache_method_exemption.md`, `bugs/avoid_missing_enum_constant_in_map_false_positive_sparse_null_handled_lookup.md`.
