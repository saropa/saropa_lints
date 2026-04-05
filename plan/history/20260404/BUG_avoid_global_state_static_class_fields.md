# BUG: avoid_global_state flags static class fields and/or reports wrong line numbers

**Rule**: `avoid_global_state`
**Severity**: False positive / incorrect line reporting
**Date**: 2026-03-25
**Status**: Resolved (2026-04-04) — reporter changed from VariableDeclaration to TopLevelVariableDeclaration to fix offset calculation; added test coverage for static class fields, const/final with doc comments
**Related**: [BUG_avoid_global_state_const_false_positive.md](BUG_avoid_global_state_const_false_positive.md) — may share a root cause

## Summary

The rule reports violations at lines corresponding to static class fields or class declarations, not top-level variable declarations. The detection logic at lines 462-477 of `structure_rules.dart` only iterates `TopLevelVariableDeclaration` nodes, so static fields inside classes should never be flagged.

## Affected Files

All paths below are in a consumer project, not in this repo.

### 1. `lib/utils/event/event_popup_menu_utils.dart` — Line 11

**Reported at**: `class EventPopupMenuUtils {` (a class declaration, not a variable)

**File contents**: This file has **zero** top-level variable declarations. All state is inside the class:
- L12: `static List<EventLabelTypes>? _sortedEventLabelTypes;` (private static field with controlled getter)

**Verdict**: Pure false positive. No top-level mutable variable exists in this file.

### 2. `lib/database/isar/isar_database_config.dart` — Line 60

**Reported at**: `static bool skippedByGate = false;` (a static field inside `IsarConfig` class)

**File contents**: There IS a genuine top-level mutable variable at **line 40**:
```dart
Isar? _isar;
```

**Verdict**: Genuine violation exists but is reported at the wrong line. L40 (`Isar? _isar;`) is the actual top-level mutable. L60 is a static class field that shouldn't be flagged.

### 3. `lib/utils/system/locale/locale_enum.dart` — Line 468

**Reported at**: End of file (line 468 is an empty line / EOF)

**File contents**: The actual top-level mutable is at **line 451**:
```dart
List<LocaleEnum>? _sortedLocaleEnums;
```

**Verdict**: Genuine violation exists but line number is off by 17 lines. Points to EOF instead of the variable.

### 4. `lib/models/user/user_badge_enum.dart` — Line 549

**Reported at**: Inside a function body (`return null;` or closing brace)

**File contents**: The actual top-level mutable is at **line 553**:
```dart
List<UserBadgeType> _sortedUserBadgeType = <UserBadgeType>[...];
```

**Verdict**: Genuine violation exists but line number is off by 4 lines.

## Root Cause Analysis

The `reporter.atNode(variable)` call at line 472 reports via the `AnnotatedNode` codepath in `SaropaDiagnosticReporter.atNode()` (`saropa_lint_rule.dart:2684-2696`). Since `VariableDeclaration` extends `Declaration` extends `AnnotatedNode`, the reporter:

1. Computes `adjustedOffset = node.firstTokenAfterCommentAndMetadata.offset`
2. Computes `length = node.end - adjustedOffset`
3. Calls `_rule.reportAtOffset(adjustedOffset, length)` — raw byte offset, not AST node

For `VariableDeclaration` nodes, `firstTokenAfterCommentAndMetadata` should return the variable name token (since doc comments and metadata belong to the parent `TopLevelVariableDeclaration`, not the child `VariableDeclaration`). This means `adjustedOffset` should point to the correct location. Yet the reported line numbers are consistently wrong, suggesting the offset-to-line mapping is broken or stale.

Two distinct issues:

1. **False detection**: `event_popup_menu_utils.dart` has no top-level mutable variables at all — something is generating a phantom violation. The AST filter (`declaration is TopLevelVariableDeclaration`) makes this impossible from the rule code alone.
2. **Wrong line numbers**: For files that DO have genuine violations (isar_database_config.dart, locale_enum.dart, user_badge_enum.dart), the reported line numbers don't match the actual variable locations. The offsets are inconsistent (+20, +17, -4 lines), ruling out a simple off-by-N error.

## Test Coverage Gap

The existing unit tests (`structure_rules_test.dart:462-472`) are **stubs** — they assert string literals, not actual rule detection. The fixture file (`example_core/lib/structure/avoid_global_state_fixture.dart`) covers the basic positive case but lacks negative cases for:
- Files with only static class fields (no top-level vars)
- `const` or `final` top-level variables with doc comments
- Line number accuracy verification

## Suggested Investigation

1. **Add negative test cases** to the fixture: a class with only static fields and no top-level vars — should produce 0 violations.
2. **Add const/final test cases** to the fixture: top-level `const` and `final` vars preceded by doc comments — should produce 0 violations (cross-validates the related const false positive bug).
3. **Inspect the `AnnotatedNode` codepath** (`saropa_lint_rule.dart:2684-2696`): verify that `firstTokenAfterCommentAndMetadata` on a `VariableDeclaration` returns the name token, not a token from the parent or a sibling node.
4. **Compare `reportAtOffset` vs `reportAtNode`**: test whether replacing `reportAtOffset(adjustedOffset, length)` with `reportAtNode(node)` for `VariableDeclaration` nodes produces correct line numbers.
5. **Check for stale analysis cache**: the consumer project may have cached results from an older version of the rule or file. Clear the analyzer cache and re-run to see if the symptoms persist.
