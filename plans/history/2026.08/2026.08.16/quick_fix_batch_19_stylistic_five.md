# Quick Fix Batch 19: Five Stylistic Quick Fixes

Five previously fix-less stylistic lint rules were given quick-fix producers, closing an item from `plans/QUICK_FIX_PLAN.md`'s missing-fixes inventory. One producer shipped with a structural bug (wrong offset-resolution API for token-based diagnostics), caught and corrected during review before commit.

## Rules fixed

| Rule | Fix producer | Strategy |
|---|---|---|
| `prefer_doc_comments_over_regular` | `PreferDocCommentFix` | Insert `/` after `//` to make `///` |
| `avoid_explicit_type_declaration` | `RemoveExplicitTypeFix` | Delete the `TypeAnnotation` node + trailing space |
| `prefer_adjacent_strings` | `PreferAdjacentStringsFix` | Strip `+` operators between string literals |
| `prefer_borderradius_circular` | `PreferBorderRadiusCircularFix` | Rewrite `BorderRadius.all(Radius.circular(r))` → `BorderRadius.circular(r)` |
| `prefer_sizedbox_over_container` | `PreferSizedBoxOverContainerFix` | Rename `Container(...)` → `SizedBox(...)` |

New files: `lib/src/fixes/stylistic/{prefer_doc_comment_fix,remove_explicit_type_fix,prefer_adjacent_strings_fix,prefer_borderradius_circular_fix,prefer_sizedbox_over_container_fix}.dart`.

Wired via `fixGenerators` in `lib/src/rules/stylistic/stylistic_rules.dart` (3 rules) and `lib/src/rules/stylistic/stylistic_widget_rules.dart` (2 rules).

## Defect found and fixed during review

`PreferDocCommentFix` initially resolved its edit offset from `coveringNode.offset`. The rule (`PreferDocCommentsOverRegularRule`) reports via `reporter.atOffset(offset: target.offset, length: target.length)` on a **comment token**, not an AST node — comments are not part of any declaration node's own source range, so `coveringNode` resolves to the nearest enclosing declaration (`class`, `String`, etc.), not the `//` token. The fix's `prefix != '//' → return` guard meant the bug produced no crash, only a silently no-op quick fix for every case the rule targets (comments preceding classes/methods/functions/fields).

Fixed by switching to `diagnosticOffset`/`diagnosticLength` — the pattern already established by the sibling fix `PreferPeriodAfterDocFix` (`lib/src/fixes/stylistic/prefer_period_after_doc_fix.dart`) for the same class of token-based diagnostic. Also added the `try/catch` + `developer.log` defensive wrapper around `addDartFileEdit` to both `PreferDocCommentFix` and `RemoveExplicitTypeFix`, matching the convention in `DeleteNodeFix`/`ReplaceNodeFix`.

## Testing

- `test/scan/rule_quick_fix_presence_test.dart`: added import + 5 `hasFix(...)` presence assertions. `dart test test/scan/rule_quick_fix_presence_test.dart` → 201/201 pass.
- No apply-and-diff-output test was added. The repo has no existing harness that applies a quick fix and asserts on the resulting text — `test/scan/fix_application_smoke_test.dart` only checks class/`FixKind` existence, and `test/scan/fix_application_dart_fix_dry_run_test.dart` runs `dart fix --dry-run` without asserting content. Building that harness was out of scope for this batch; flagged as an open gap. This is the class of gap that let the `PreferDocCommentFix` offset bug ship undetected by any test — only manual/agent code review caught it.

## Known non-bugs noted during review

- `PreferAdjacentStringsFix._collectParts`'s handling of nested `BinaryExpression` operands is unreachable given `PreferAdjacentStringsRule._isPureStringLiteral`'s current leaf restriction (`SimpleStringLiteral`/`AdjacentStrings` only) — left as defensive code, not simplified.
- `const` keyword detection in `PreferBorderRadiusCircularFix`/`PreferSizedBoxOverContainerFix` via `node.keyword?.lexeme == 'const'` does not track implicit (context-inferred) const; confirmed this cannot produce a compile error since Dart auto-promotes a non-`const`-keyword literal in an already-const context.

## Finish Report (2026-08-16)

Five quick-fix producers implemented and wired for previously fix-less stylistic rules. Deep review (delegated to a subagent) surfaced one critical defect — `PreferDocCommentFix` used `coveringNode` instead of `diagnosticOffset`/`diagnosticLength` for a token-based diagnostic, making the fix a silent no-op for its entire target case. Corrected using the established `PreferPeriodAfterDocFix` pattern before commit. All 201 tests in the quick-fix presence suite pass. No apply-and-verify test harness exists in this repo for quick fixes generally; this batch did not add one, consistent with existing repo precedent, though this is the gap class that let the defect ship past automated tests.
