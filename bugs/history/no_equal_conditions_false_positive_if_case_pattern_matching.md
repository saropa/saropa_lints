# Bug Report: `no_equal_conditions` — False Positive on Dart 3 `if-case` Pattern Matching

## Diagnostic Reference

```json
[{
  "resource": "/D:/src/contacts/lib/models/contact/note_label_type.dart",
  "owner": "_generated_diagnostic_collection_name_#2",
  "code": "no_equal_conditions",
  "severity": 4,
  "message": "[no_equal_conditions] Same condition appears more than once in an if/else-if chain. The duplicate branch is unreachable because the first occurrence already handles all cases where the condition is true, making the repeated check dead code. {v5}\nRemove the duplicate condition and its branch, or correct the expression if a different condition was intended.",
  "source": "dart",
  "startLineNumber": 336,
  "startColumn": 16,
  "endLineNumber": 336,
  "endColumn": 20,
  "modelVersionId": 1,
  "origin": "extHost1"
}]
```

---

## Summary

The `no_equal_conditions` rule incorrectly flags Dart 3 `if-case` pattern matching branches as duplicate conditions. When an if-else-if chain uses `if (this case PatternA) ... else if (this case PatternB)`, the rule compares only the scrutinee expression (`this`) and ignores the pattern clause entirely. Since the scrutinee is the same in every branch, the rule treats all branches after the first as duplicates — even though each branch matches a **different pattern** and is fully reachable.

---

## The False Positive Scenario

### Real-World Example: Enum Extension Getter

`lib/models/contact/note_label_type.dart` (lines 331-347)

```dart
ContactNoteSpecialType? get specialType {
  if (this case SexOrGender) {
    return ContactNoteSpecialType.HealthMedical;
  } else if (this case MedicalCondition) {           // <- flagged: "this" seen before
    return ContactNoteSpecialType.HealthMedical;
  } else if (this case HarryPotterId) {              // <- flagged: "this" seen before
    return ContactNoteSpecialType.HarryPotter;
  } else if (this case StarWarsCharacterId) {        // <- flagged: "this" seen before
    return ContactNoteSpecialType.StarWars;
  } else if (this case StarTrekCharacterId) {        // <- flagged: "this" seen before
    return ContactNoteSpecialType.StarTrek;
  } else if (this case RickAndMortyCharacterId) {    // <- flagged: "this" seen before
    return ContactNoteSpecialType.RickAndMorty;
  }

  return null;
}
```

This is an enum extension method on `NoteLabelTypes` that maps certain enum values to a `ContactNoteSpecialType`. Each branch matches a **different enum value** — `SexOrGender`, `MedicalCondition`, `HarryPotterId`, etc. Every branch is reachable and none are dead code. The rule flags lines 334, 336, 338, 340, and 342 because it sees `this` repeated as the "condition."

### Generalized Pattern

Any if-else-if chain using Dart 3 `if-case` syntax where the same variable is matched against different patterns will trigger this false positive:

```dart
// All of these are falsely flagged as duplicates:
if (value case int x) {
  handleInt(x);
} else if (value case String s) {       // <- flagged: "value" seen before
  handleString(s);
} else if (value case List<int> l) {    // <- flagged: "value" seen before
  handleList(l);
}
```

```dart
// Same issue with any scrutinee:
if (widget.type case TypeA()) {
  buildA();
} else if (widget.type case TypeB()) {  // <- flagged: "widget.type" seen before
  buildB();
}
```

---

## Root Cause Analysis

The rule in `lib/src/rules/control_flow_rules.dart` (lines 1665-1719) uses `IfStatement.expression.toSource()` to extract conditions for comparison:

```dart
// Line 1697
final String conditionSource = current.expression.toSource();
```

For a traditional `if (x > 5)` statement, `expression` is the full boolean expression `x > 5`.

For a Dart 3 `if (this case SexOrGender)` statement, the AST separates the construct into:
- **`expression`**: the scrutinee — just `this`
- **`caseClause`**: the pattern — `case SexOrGender`

The rule only inspects `expression` and completely ignores `caseClause`. As a result:

| Statement | `expression.toSource()` | `caseClause` | Rule sees |
|---|---|---|---|
| `if (this case SexOrGender)` | `"this"` | `case SexOrGender` | `"this"` |
| `if (this case MedicalCondition)` | `"this"` | `case MedicalCondition` | `"this"` |
| `if (this case HarryPotterId)` | `"this"` | `case HarryPotterId` | `"this"` |

All three produce `"this"` → the rule reports the second and third as duplicates.

---

## Suggested Fixes

### Option A: Include the Case Clause in Condition Key (Recommended)

When the `IfStatement` has a `caseClause`, append the pattern source to the condition key so that different patterns produce different keys:

```dart
IfStatement? current = node;
while (current != null) {
  // Include case clause in condition key when present
  String conditionSource = current.expression.toSource();
  if (current.caseClause != null) {
    conditionSource += ' case ${current.caseClause!.toSource()}';
  }
  conditions.add(conditionSource);
  conditionNodes.add(current.expression);
  // ...
}
```

This produces unique keys like `"this case SexOrGender"`, `"this case MedicalCondition"`, etc., so different patterns are no longer flagged as duplicates. Genuinely duplicate patterns (`if (x case int y) ... else if (x case int y)`) would still be caught.

### Option B: Skip If-Case Statements Entirely

If the rule's semantics aren't well-defined for pattern matching, skip any `IfStatement` that has a `caseClause`:

```dart
while (current != null) {
  // Skip if-case branches — pattern matching makes each unique
  if (current.caseClause == null) {
    final String conditionSource = current.expression.toSource();
    conditions.add(conditionSource);
    conditionNodes.add(current.expression);
  }
  // ...
}
```

This is simpler but less thorough — it won't catch genuinely duplicated if-case patterns.

### Option C: Hybrid — Skip Mixed Chains

If any branch in the if-else-if chain uses `if-case`, bail out of the entire chain check, since mixed boolean/pattern chains are semantically complex:

```dart
IfStatement? current = node;
bool hasCaseClause = false;
while (current != null) {
  if (current.caseClause != null) {
    hasCaseClause = true;
    break;
  }
  // ...
}
if (hasCaseClause) return; // Skip chain entirely
```

---

## Patterns That Should Be Recognized

| Pattern | Currently Flagged | Should Be Flagged |
|---|---|---|
| `if (x > 5) ... else if (x > 5)` | Yes | **Yes** (genuine duplicate) |
| `if (x > 5) ... else if (x > 10)` | No | No |
| `if (this case A) ... else if (this case B)` | **Yes** | **No** (different patterns) |
| `if (this case A) ... else if (this case A)` | Yes | **Yes** (genuine duplicate pattern) |
| `if (v case int x) ... else if (v case String s)` | **Yes** | **No** (different type patterns) |
| `if (v case int x) ... else if (v case int y)` | **Yes** | **Yes** (same type pattern, dead code) |

---

## Current Workaround

Developers must suppress the rule for the entire getter:

```dart
// ignore: no_equal_conditions
```

This works but suppresses the rule entirely, losing coverage for genuine duplicates.

---

## Affected Files

| File | Lines | What |
|---|---|---|
| `lib/src/rules/control_flow_rules.dart` | 1690-1717 | `NoEqualConditionsRule.runWithReporter()` — extracts only `expression`, ignores `caseClause` |
| `lib/src/rules/control_flow_rules.dart` | 1697 | `current.expression.toSource()` — should also include `current.caseClause?.toSource()` |
| `example_core/lib/control_flow/no_equal_conditions_fixture.dart` | 111-129 | Test fixture — no if-case test cases exist |

---

## Missing Test Coverage

The test fixture (`no_equal_conditions_fixture.dart`) has no Dart 3 `if-case` examples. The following should be added:

```dart
// GOOD: Different patterns on same scrutinee — should NOT trigger
void _goodIfCaseDifferentPatterns() {
  if (x case int i) {
    doA();
  } else if (x case String s) {
    doB();
  } else if (x case List<int> l) {
    doC();
  }
}

// BAD: Same pattern on same scrutinee — SHOULD trigger
// expect_lint: no_equal_conditions
void _badIfCaseSamePattern() {
  if (x case int i) {
    doA();
  } else if (x case int i) {
    doB(); // Dead code — same pattern
  }
}

// GOOD: Enum if-case — should NOT trigger
enum Color { red, green, blue }
void _goodEnumIfCase(Color c) {
  if (c case Color.red) {
    doA();
  } else if (c case Color.green) {
    doB();
  } else if (c case Color.blue) {
    doC();
  }
}
```

---

## Priority

**High** — Dart 3 pattern matching with `if-case` is idiomatic Dart and increasingly common, especially in enum extensions and type-narrowing code. Every if-else-if chain that uses `if-case` with more than one branch triggers this false positive, producing multiple warnings per chain. This erodes trust in the rule and forces widespread suppression comments.
