# Investigation: `no_magic_string` false positive on commented-out code (not a bug)

A bug report alleged `no_magic_string` fired on string literals inside `//`-commented-out `debugPrint(...)` calls in a downstream project's `lib/main.dart`. Code inspection confirmed this is impossible under any current code path and closed the report as a diagnostic-staleness artifact rather than a rule defect.

## Investigation

`NoMagicStringRule.runWithReporter` (`lib/src/rules/data/numeric_literal_rules.dart:406-434`) registers exclusively via `context.addSimpleStringLiteral`, the standard `custom_lint`/analyzer AST visitor callback. Comment trivia is never lexed into a `SimpleStringLiteral` node, so the callback structurally cannot fire on text inside a `//` comment.

The rule's four gating helpers, all in `lib/src/literal_context_utils.dart`, were audited to rule out any secondary raw-text scan:

- `isLiteralInConstContext` — walks `node.parent` checking `VariableDeclarationList`/`InstanceCreationExpression`/`ListLiteral`/`SetOrMapLiteral` const flags.
- `isInAnnotation` — walks `node.parent` checking for `Annotation`.
- `isInImportOrExport` — walks `node.parent` checking for `ImportDirective`/`ExportDirective`.
- `isStringUsedAsRegexPattern` — inspects the resolved `ArgumentList`/`InstanceCreationExpression`/`MethodInvocation` AST around the literal.

None of the four reads `context.fileContent` or performs regex/text scanning over raw source. The rule and its full dependency chain are AST-callback-driven only.

## Conclusion

Hypothesis A (stale diagnostic offset) from the original bug report is confirmed: the two reported firings were a Problems-panel diagnostic computed against a slightly earlier document version, before an edit commented out or moved the real string literal — the analyzer server had not yet reconciled the new version at read time. This matches the existing pitfall entry in `bugs/BUG_REPORT_GUIDE.md:332` ("Wrong line / column in Problems panel"), which already instructs reporters to restart the Dart Analysis Server and reconfirm with a fresh scan before filing. No rule code, test, or documentation-guidance change was required.

## Outcome

- No rule source changes — the rule's existing logic was already correct.
- `bugs/no_magic_string_false_positive_commented_out_code.md` updated in place with the resolution and evidence; left in `bugs/` (not moved to history) since no code fix landed — the report itself is the closure record.
- Added `test/rules/data/no_magic_string_comment_fp_test.dart`, a resolved-analyzer regression test (via `test/support/resolved_rule_harness.dart`) asserting `no_magic_string` does not fire on a commented-out string literal and does fire on the same literal once uncommented. Both assertions pass against current HEAD. This pins the AST-only behavior as a permanent guard, addressing the report's own noted "Fixture Gap" with a positive-behavior test rather than a staleness repro (which would require Dart Analysis Server-level infrastructure outside this package's test scope).
- CHANGELOG: added a Maintenance-section entry under `[Unreleased]` (no end-user-visible behavior changed, so it is not a top-level Fixed entry).

## Reflection follow-up

Of the handoff reflection's least-confident items, only one was concretely actionable within this package's scope: verifying the negative claim empirically rather than by code-path elimination alone. The regression test above does that. The remaining items (analyzer-plugin-host internals, IDE-level caching, the downstream `contacts` repo's exact `saropa_lints` version, and the original report's unverified line numbers) require access to systems/repos outside this package and were left as documented open uncertainty rather than force-closed.
