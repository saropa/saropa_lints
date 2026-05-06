# False positive: `avoid_unused_assignment` flags definite assignment via if/else branches

## Summary

The `avoid_unused_assignment` rule produces **false positives** when a `final` variable (declared without an initializer) is definitively assigned in both branches of an if/else statement and then read later. The rule treats the two branch assignments as sequential overwrites, but they are **mutually exclusive** — exactly one branch executes, and the variable is read afterward.

## Severity

**High** — 4 false positives in a single method (`alignDateTime`), all following the same idiomatic Dart pattern. This pattern is endorsed by the Dart language itself (definite assignment analysis for `final` locals). Flagging it undermines developer trust in the rule.

## Affected rule

- **Rule:** `avoid_unused_assignment`
- **Source:** `lib/src/rules/code_quality_rules.dart` (lines 3662-3805)
- **Version tag:** `{v3}`
- **Configured severity:** `DiagnosticSeverity.INFO`

## Reproduction

### File

`saropa_dart_utils/lib/datetime/date_time_calendar_extensions.dart`

### Minimal reproducer

```dart
void example(bool condition, int a, int b) {
  final int value;
  if (condition) {
    value = a;    // FLAGGED: "Variable is assigned a value that is never read
                  //           before being overwritten or going out of scope"
  } else {
    value = b;
  }

  print(value);   // value IS read here — the warning is wrong
}
```

### Actual code (4 occurrences)

```dart
@useResult
DateTime alignDateTime({
  required Duration alignment,
  bool roundUp = false,
}) {
  if (alignment == Duration.zero) {
    return this;
  }

  final int hours;
  if (alignment.inDays > 0) {
    hours = hour;          // LINE 156 — FLAGGED
  } else {
    hours = alignment.inHours > 0 ? hour % alignment.inHours : 0;
  }

  int minutes;
  if (alignment.inHours > 0) {
    minutes = minute;      // LINE 163 — FLAGGED
  } else {
    minutes = alignment.inMinutes > 0 ? minute % alignment.inMinutes : 0;
  }

  int seconds;
  if (alignment.inMinutes > 0) {
    seconds = second;      // LINE 170 — FLAGGED
  } else {
    seconds = alignment.inSeconds > 0 ? second % alignment.inSeconds : 0;
  }

  int milliseconds;
  if (alignment.inSeconds > 0) {
    milliseconds = millisecond;  // LINE 177 — FLAGGED
  } else {
    milliseconds = alignment.inMilliseconds > 0
        ? millisecond % alignment.inMilliseconds
        : 0;
  }

  var microseconds = alignment.inMilliseconds > 0 ? microsecond : 0;

  // ALL four flagged variables are read here:
  final Duration correction = Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: milliseconds,
    microseconds: microseconds,
  );

  if (correction == Duration.zero) {
    return this;
  }

  final DateTime corrected = subtract(correction);
  return roundUp ? corrected.add(alignment) : corrected;
}
```

### Diagnostic output (all 4 warnings)

| Line | Column | Flagged expression |
|-----:|-------:|:-------------------|
| 156 | 7-19 | `hours = hour` |
| 163 | 7-23 | `minutes = minute` |
| 170 | 7-23 | `seconds = second` |
| 177 | 7-33 | `milliseconds = millisecond` |

All four produce the identical message:

> [avoid_unused_assignment] Variable is assigned a value that is never read before being overwritten or going out of scope. The assignment wastes computation, and the unused result often signals a logic error where the value was meant to be used in a subsequent expression or return statement. {v3}

## Root cause analysis

The rule's data flow analysis in `_AssignmentUsageVisitor` collects **all assignments** to a variable name into a flat list, then iterates the list looking for consecutive assignments where the first is "unused before overwrite." The check sequence for each assignment pair is:

1. `_isInsideLoop(current)` — skip if inside a loop body
2. `_isInsideConditionalOnly(next)` — skip if the **next** assignment is inside an `if` **without** an `else`
3. `_nextAssignmentReadsVariable(next, varName)` — skip if the next assignment's RHS reads the variable

**The gap:** Step 2 only suppresses the warning when the next assignment is in a **conditional-only** (if-without-else) block, treating it as a "may-overwrite." But in the failing case, both assignments are inside an if/else, so neither is conditional-only — both are "must-execute within their branch." The rule sees two "must-overwrite" assignments and flags the first, not recognizing that they are in **mutually exclusive branches** of the same if/else construct.

**What the rule misses:** When two assignments to the same variable are in the `if` branch and the `else` branch of the **same** if/else statement, they are not sequential — they are alternatives. Exactly one executes. This is a **definite assignment** pattern, not a "write then overwrite" pattern. Dart's own flow analysis understands this (otherwise `final` variables assigned this way would cause compile errors).

## Proposed fix

Add a check for **sibling branch assignments** — when two consecutive assignments to the same variable are in opposite branches (`if` vs `else`) of the same parent `IfStatement`, suppress the warning.

### Suggested logic (pseudocode)

```dart
/// Returns true if [a] and [b] are in opposite branches of the
/// same if/else statement (mutually exclusive execution paths).
bool _areInOppositeBranches(AstNode a, AstNode b) {
  final ifStatementA = _findAncestorIfStatement(a);
  final ifStatementB = _findAncestorIfStatement(b);

  if (ifStatementA == null || ifStatementB == null) return false;
  if (ifStatementA != ifStatementB) return false;

  // Same IfStatement — check they are in different branches
  final aInThen = ifStatementA.thenStatement.containsOffset(a.offset);
  final bInElse = ifStatementA.elseStatement?.containsOffset(b.offset) ?? false;
  final aInElse = ifStatementA.elseStatement?.containsOffset(a.offset) ?? false;
  final bInThen = ifStatementA.thenStatement.containsOffset(b.offset);

  return (aInThen && bInElse) || (aInElse && bInThen);
}
```

Then insert this check in the main loop before flagging:

```dart
// Existing checks...
if (_isInsideLoop(current)) continue;
if (_isInsideConditionalOnly(next)) continue;
if (_nextAssignmentReadsVariable(next, entry.key)) continue;

// NEW: Skip if assignments are in opposite branches of the same if/else
if (_areInOppositeBranches(current, next)) continue;

reporter.atNode(current, code);
```

## Additional patterns to consider

The fix should also handle:

1. **Chained else-if:** `if (a) { x = 1; } else if (b) { x = 2; } else { x = 3; }` — three assignments, all mutually exclusive
2. **Nested if/else within branches:** assignments deeper in the tree but still within mutually exclusive top-level branches
3. **Switch statements (if applicable):** same pattern with exhaustive switch cases

## Test cases to add

```dart
// Should NOT flag — definite assignment via if/else
void testDefiniteAssignmentIfElse() {
  final int x;
  if (condition) {
    x = 1;
  } else {
    x = 2;
  }
  print(x);
}

// Should NOT flag — definite assignment via if/else-if/else
void testDefiniteAssignmentChainedElseIf() {
  final int x;
  if (a) {
    x = 1;
  } else if (b) {
    x = 2;
  } else {
    x = 3;
  }
  print(x);
}

// SHOULD flag — if without else, variable unused after
void testTruePositiveConditionalOnly() {
  int x = 1;
  if (condition) {
    x = 2;
  }
  x = 3;        // previous assignments unused
  print(x);
}

// SHOULD flag — both branches assign, but variable is never read
void testTruePositiveNeverRead() {
  int x;
  if (condition) {
    x = 1;
  } else {
    x = 2;
  }
  // x is never used
}
```

## Workaround

Until fixed, the affected code can use either:

1. **Inline conditional expression** (loses readability for complex conditions):
   ```dart
   final hours = alignment.inDays > 0
       ? hour
       : (alignment.inHours > 0 ? hour % alignment.inHours : 0);
   ```

2. **Ignore comment** (noisy):
   ```dart
   // ignore: avoid_unused_assignment
   hours = hour;
   ```

Neither is ideal. The current code is idiomatic Dart and should not require suppression.

## Related

- Previous false positive fixes: `bugs/history/false_positives/avoid_unused_assignment_false_positive_*.md`
- The existing `_isInsideConditionalOnly()` was likely added to address a similar class of false positive but only covers the "if-without-else" case, not the "both-branches-of-if-else" case.
