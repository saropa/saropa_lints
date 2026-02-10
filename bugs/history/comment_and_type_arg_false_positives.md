# Remaining Issues

Issues from the original report that are **not false positives** (correct rule behavior):

  lib\flutter_mocks.dart:2775:32 • [prefer_explicit_type_arguments] • INFO
  lib\flutter_mocks.dart:2776:31 • [prefer_explicit_type_arguments] • INFO
  lib\flutter_mocks.dart:3157:55 • [prefer_explicit_type_arguments] • INFO

These are empty list literals `[]` returning `List<dynamic>` with no typed context.
Consider adding `// ignore_for_file: prefer_explicit_type_arguments` to flutter_mocks.dart.

  lib\require_subscription_status_check_example.dart:118:11 • [prefer_explicit_type_arguments] • INFO

`Future.delayed(...)` without explicit type argument. Could be `Future<void>.delayed(...)`.

## Fixed (2026-02-10)

- 30+ `prefer_no_commented_out_code` false positives on prose labels (`OK:`, `BAD:`, `GOOD:`, `LINT:`, `expect_lint:`) — fixed by removing `:` from code detection pattern
- 1 `prefer_capitalized_comment_start` false positive on continuation comment — fixed by detecting consecutive-line comments
- 2 `prefer_explicit_type_arguments` false positives on context-typed empty collections (`[]` where return type provides `List<int>`) — fixed by checking inferred type arguments
- 15 stale issues on deleted `new_rules_fixture.dart` — removed
