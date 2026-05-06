# prefer_correct_for_loop_increment — comment exemption not implemented (RESOLVED)

**Rule:** `prefer_correct_for_loop_increment`  
**File:** `lib/src/rules/data/collection_rules.dart` — `PreferCorrectForLoopIncrementRule`  
**Status:** Resolved  
**Date:** 2026-03-03

## Resolution summary

The correction message stated users could "add a comment explaining why a non-standard increment step is necessary," but the implementation did not check for comments. Implemented comment exemption:

1. **Comment check:** Before reporting, the rule now calls `_hasExplanatoryIncrementComment(node, context.lineInfo)`, which collects comments on the same line as the `for` or the line immediately above (from `node.beginToken.precedingComments` and, if body is a Block, `body.beginToken.precedingComments`), and matches combined text against a case-insensitive pattern: `\b(step|increment|spacing|stride|non-?standard|intentional)\b`. If a match is found, the rule does not report for that for statement.

2. **Quick fix:** `AddForLoopIncrementCommentFix` inserts a placeholder explanatory comment above the for loop so the exemption applies.

3. **Fixture and tests:** `_good253CommentExemption` (comment exempts, no expect_lint), `_bad253UnrelatedComment` and `_bad253CommentTooFarAbove` (still trigger; expect_lint). Unit tests document exemption and false-positive avoidance.

## References

- Original bug: `bugs/prefer_correct_for_loop_increment_comment_exemption_not_implemented.md` (moved to history)
- Fixture: `example_core/lib/collection/prefer_correct_for_loop_increment_fixture.dart`
- Tests: `test/collection_rules_test.dart` (prefer_correct_for_loop_increment group)
