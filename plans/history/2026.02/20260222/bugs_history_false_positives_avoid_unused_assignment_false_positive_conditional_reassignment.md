# Bug: `avoid_unused_assignment` false positive when variable is read before conditional overwrite

## Resolution

**Fixed.** Added three checks: skip loop-body assignments, skip may-overwrite conditionals (if without else), skip assignments where the next overwrite reads the variable on RHS.

## Summary

The `avoid_unused_assignment` rule incorrectly flags assignments where the
variable is subsequently reassigned inside a conditional block (`if` statement),
even though the reassignment **reads the old value** before overwriting it.
The rule does not distinguish between "overwritten without reading" and
"read-then-overwritten" (which is a legitimate use of the old assignment).

## Severity

**False positive** -- the rule claims the value "is never read before being
overwritten or going out of scope," but the value IS read as part of the
overwriting expression itself. Following the lint's advice to remove the
assignment would break the code.

## Reproduction

### Minimal example 1: Sequential conditional transformations

```dart
bool isEquals(String? other, {
  bool ignoreCase = true,
  bool normalizeApostrophe = true,
}) {
  if (other == null) return false;
  String first = this;
  String second = other;

  if (ignoreCase) {
    // FLAGGED: avoid_unused_assignment  (line 593)
    first = first.toLowerCase();
    // FLAGGED: avoid_unused_assignment  (line 594)
    second = second.toLowerCase();
  }

  if (normalizeApostrophe) {
    first = first.replaceAll(_apostropheRegex, "'");    // reads first ← from line 593
    second = second.replaceAll(_apostropheRegex, "'");  // reads second ← from line 594
  }

  return first == second;  // reads both
}
```

**Data flow trace:**

```
first = this                          // initial assignment
  │
  ├─ if (ignoreCase):
  │    first = first.toLowerCase()    // FLAGGED ← but first IS read here (RHS)
  │         │                         //            AND read on line 598 (RHS)
  │         │                         //            AND read on line 602
  │         ▼
  ├─ if (normalizeApostrophe):
  │    first = first.replaceAll(...)  // reads first from ignoreCase block
  │         │
  │         ▼
  └─ return first == second           // reads first
```

The assignment `first = first.toLowerCase()` on line 593:

1. **Reads** the old `first` (from `this`) as `first.toLowerCase()`
2. The new `first` is **read** on line 598 as `first.replaceAll(...)` (if `normalizeApostrophe` is true)
3. The new `first` is **read** on line 602 as `first == second`

### Minimal example 2: Pipeline transformation

```dart
String? removeSingleCharacterWords({
  bool trim = true,
  bool removeMultipleSpaces = true,
}) {
  if (isEmpty) return this;
  String result = removeAll(_singleCharWordRegex);

  if (removeMultipleSpaces) {
    // FLAGGED: avoid_unused_assignment  (line 770)
    result = result.replaceAll(RegExp(r'\s+'), ' ');
  }

  if (trim) {
    result = result.trim();  // reads result from line 770
  }

  return result.isEmpty ? null : result;  // reads result
}
```

### Lint output

```
line 593 col 7 • [avoid_unused_assignment] Variable is assigned a value
that is never read before being overwritten or going out of scope. The
assignment wastes computation, and the unused result often signals a
logic error where the value was meant to be used in a subsequent
expression or return statement. {v3}
```

### All affected locations (4 instances)

| File                                | Line | Variable | Overwrite reads old value?     | Subsequent reads?   |
| ----------------------------------- | ---- | -------- | ------------------------------ | ------------------- |
| `lib/string/string_extensions.dart` | 593  | `first`  | Yes (`first.toLowerCase()`)    | Lines 598, 602      |
| `lib/string/string_extensions.dart` | 594  | `second` | Yes (`second.toLowerCase()`)   | Lines 599, 602      |
| `lib/string/string_extensions.dart` | 770  | `result` | Yes (`result.replaceAll(...)`) | Lines 773, 775      |
| `lib/string/string_extensions.dart` | 304  | `str`    | Yes (`str.substringSafe(...)`) | Lines 307, 309, 312 |

## Root cause

The rule's analysis appears to treat conditional blocks as potential overwrites
without checking whether:

1. The overwriting expression itself reads the old value (e.g.,
   `x = x.transform()` reads `x` on the RHS before assigning)
2. Not all code paths through the conditionals overwrite the variable (e.g.,
   when `ignoreCase` is false, the assignment on line 593 is skipped, but
   the value from line 588 `first = this` flows directly to line 598 or 602)

### Analysis error pattern

The rule sees this structure:

```dart
x = A;          // assignment 1
if (cond1) {
  x = f(x);    // assignment 2 -- rule sees "x overwritten" → flags assignment 1
}
if (cond2) {
  x = g(x);    // assignment 3 -- rule sees "x overwritten" → flags assignment 2
}
return x;
```

But the correct analysis is:

- Assignment 1 IS read: by `f(x)` in assignment 2 (RHS), and directly on `return x` if `cond1` is false
- Assignment 2 IS read: by `g(x)` in assignment 3 (RHS), and directly on `return x` if `cond2` is false

### Likely detection gap

The rule does not perform proper **may-overwrite** vs **must-overwrite**
analysis. It treats an assignment inside an `if` block as if it **always**
executes, when in fact it only executes when the condition is true. On the
false branch, the old value flows through unchanged.

Additionally, the rule may not check whether the RHS of the overwriting
assignment reads the variable being assigned (i.e., `x = x.transform()` is
both a read and a write of `x`).

## Suggested fix

### Fix 1: Check if overwriting assignment reads the old value

Before flagging an assignment as unused, check whether any subsequent
overwriting assignment reads the variable on its RHS:

```dart
bool doesAssignmentReadVariable(AssignmentExpression assignment, String varName) {
  // Check if the RHS references the same variable
  final rhs = assignment.rightHandSide;
  return referencesVariable(rhs, varName);
}
```

If any overwriting assignment reads the old value, the original assignment
is NOT unused.

### Fix 2: Account for conditional (may-overwrite) paths

An assignment inside an `if` block (without an `else`) is a **may-overwrite**,
not a **must-overwrite**. The old value is still live on the else path:

```dart
// When checking if `x = A` is unused:
if (cond) {
  x = B;      // may-overwrite (only if cond is true)
}
use(x);        // reads x -- could be A (cond false) or B (cond true)
               // Therefore x = A IS read on the false path
```

Only flag an assignment as unused if it is **must-overwritten** on ALL paths
before being read. This requires either:

- Proper reaching-definitions analysis on the CFG, or
- Recognizing that assignments inside `if` blocks without `else` are always
  may-overwrites

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Conditional pipeline: each step reads the previous value
void pipeline(bool step1, bool step2) {
  String value = 'input';
  if (step1) {
    value = value.toUpperCase();  // reads old value on RHS
  }

  if (step2) {
    value = value.trim();  // reads value (from step1 or original)
  }
  print(value);
}

// Self-referencing assignment
void selfRef() {
  String s = 'hello';
  if (true) {
    s = s + ' world';  // RHS reads s
  }
  print(s);
}

// Variable read after conditional overwrite
void readAfter() {
  int x = computeA();
  if (condition) {
    x = computeB(x);  // reads x from computeA()
  }

  return x;  // reads x (either from computeA or computeB)
}

// Should STILL flag (true positives, no change):

// Unconditionally overwritten without reading
void unconditionalOverwrite() {
  String value = 'first';  // FLAGGED: never read
  value = 'second';        // unconditional overwrite, RHS doesn't reference `value`
  print(value);
}

// Overwritten in both if and else without reading
void bothBranches() {
  int x = 1;  // FLAGGED: never read
  if (condition) {
    x = 2;  // doesn't read old x
  } else {
    x = 3;  // doesn't read old x
  }
  print(x);
}
```

## Impact

Sequential conditional transformations are a standard pattern in text processing,
data normalization, and configuration pipelines:

```dart
// Normalize user input
String input = rawInput;
if (shouldTrim) input = input.trim();
if (shouldLower) input = input.toLowerCase();
if (shouldNormalize) input = input.normalize();
return input;
```

Every assignment in this chain would be falsely flagged. This pattern is
especially common in utility libraries, form validators, and data import/export
code.
