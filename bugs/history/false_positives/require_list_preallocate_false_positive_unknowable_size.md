# Bug: `require_list_preallocate` false positive when list size is unknowable at construction time

## Resolution

**Fixed.** `_isInsideConditionalWithinLoop` skips `add()` calls inside if/switch/ternary within a loop body — preallocation is impossible when size is data-dependent.


## Summary

The `require_list_preallocate` rule flags `List.add()` inside loops and
recommends preallocation, but fires even when the final list size cannot be
determined before the loop executes. In cases where the number of items added
depends on runtime conditional logic within the loop body, preallocation is
impossible without running the loop twice (once to count, once to populate),
which would be strictly worse for performance.

## Severity

**False positive** -- the rule's advice ("Preallocate the list with
`List.generate()`, `List.filled()`, or use `growable: false`") is not
actionable when the final size depends on runtime branching. Following the
advice literally would require either:
1. Over-allocating (wasting memory), or
2. Running the loop twice (wasting computation), or
3. Using a different data structure entirely (unnecessary refactoring)

## Reproduction

### Minimal example

```dart
List<String> splitCapitalizedUnicode({int minLength = 1}) {
  if (isEmpty) return <String>[];

  List<String> parts = split(pattern);

  if (minLength > 1 && parts.length > 1) {
    final List<String> mergedResult = <String>[];
    String currentBuffer = parts[0];

    for (int i = 1; i < parts.length; i++) {
      final String nextPart = parts[i];
      if (currentBuffer.length < minLength || nextPart.length < minLength) {
        // Merge: combine short segments
        currentBuffer += nextPart;
      } else {
        // Emit: add buffer to results and start new buffer
        // FLAGGED: require_list_preallocate
        mergedResult.add(currentBuffer);
        currentBuffer = nextPart;
      }
    }
    mergedResult.add(currentBuffer);
    parts = mergedResult;
  }
  // ...
}
```

### Why preallocation is impossible

The `mergedResult` list receives items **conditionally**: only when
`currentBuffer.length >= minLength && nextPart.length >= minLength`. The
number of items that will be added depends on the lengths of adjacent
segments, which are only known as the loop iterates.

Consider input `"ABcDEfGH"` split into `["A", "Bc", "D", "Ef", "G", "H"]`
with `minLength = 2`:

```
Iteration 1: "A" (len 1 < 2) → merge → buffer = "ABc"
Iteration 2: "D" (len 1 < 2) → merge → buffer = "ABcD"
Iteration 3: "Ef" (len 2 >= 2), buffer "ABcD" (len 4 >= 2) → EMIT, buffer = "Ef"
Iteration 4: "G" (len 1 < 2) → merge → buffer = "EfG"
Iteration 5: "H" (len 1 < 2) → merge → buffer = "EfGH"
Final: emit buffer
Result: ["ABcD", "EfGH"] — 2 items from 6 inputs
```

The final size (2) was unknowable before the loop. It could be anywhere from
1 (everything merged) to N (nothing merged).

### Lint output

```
line 450 col 11 • [require_list_preallocate] Using List.add() inside a loop
without preallocating the list causes repeated memory reallocations (O(n^2)
time), which slows down your app and wastes resources. This is especially
problematic for large lists or performance-critical code. {v1}
```

### All affected locations (1 instance)

| File | Line | List variable | Why size is unknowable |
|------|------|---------------|----------------------|
| `lib/string/string_extensions.dart` | 450 | `mergedResult` | Items added conditionally based on runtime segment lengths |

## Root cause

The rule detects `List.add()` (or `List.addAll()`) inside any loop construct
and flags it unconditionally. It does not analyze whether:

1. The number of additions is **knowable** before the loop starts
2. The `add()` call is inside a **conditional branch** within the loop body
3. The list size depends on **runtime data** that varies per iteration

### Performance reality

Dart's `List` uses a **doubling growth strategy** (amortized O(1) per add).
The rule's claim of "O(n^2) time" from repeated reallocations is incorrect
for Dart's standard growable list implementation. The actual cost is O(n)
amortized, which is asymptotically optimal for an unknown-size collection.

Preallocation helps when the size IS known (avoids the constant factor of
reallocation), but when the size is unknowable, growable lists are the
correct choice.

## Suggested fix

### Option A: Skip when add() is inside a conditional

If `List.add()` appears inside an `if` statement within the loop body,
the number of additions is data-dependent and preallocation is not possible:

```dart
void checkAddInLoop(MethodInvocation addCall, AstNode loopBody) {
  // Check if the add() call is inside a conditional within the loop
  AstNode? current = addCall.parent;
  while (current != null && current != loopBody) {
    if (current is IfStatement || current is ConditionalExpression ||
        current is SwitchStatement) {
      return; // add() is conditional — size is unknowable, do not flag
    }
    current = current.parent;
  }
  // ... proceed with existing logic for unconditional adds
}
```

### Option B: Check if input size equals output size

If the loop iterates over a collection and adds to a new list, but the add
is conditional, the output list could be smaller than the input. Only flag
when the number of adds per iteration is exactly 1 (unconditional):

```dart
// Unconditional add — size IS knowable (same as loop count):
for (final item in items) {
  result.add(transform(item));  // FLAG: use List.generate() or .map()
}

// Conditional add — size is unknowable:
for (final item in items) {
  if (item.isValid) {
    result.add(item);  // SKIP: can't preallocate
  }
}
```

### Option C: Correct the O(n^2) claim

At minimum, update the lint message to acknowledge that Dart's growable list
uses amortized O(1) insertion. The current message ("causes repeated memory
reallocations (O(n^2) time)") is technically incorrect for Dart's
implementation and may mislead developers into unnecessary micro-optimizations.

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Conditional add inside loop
void filterAndCollect(List<int> items) {
  final List<int> result = <int>[];
  for (final int item in items) {
    if (item > 0) {
      result.add(item);  // Size unknowable
    }
  }
}

// Merge loop with conditional emit
void mergeSmallParts(List<String> parts) {
  final List<String> merged = <String>[];
  String buffer = parts[0];
  for (int i = 1; i < parts.length; i++) {
    if (parts[i].length >= 3) {
      merged.add(buffer);  // Size unknowable
      buffer = parts[i];
    } else {
      buffer += parts[i];
    }
  }
  merged.add(buffer);
}

// Should STILL flag (true positives, no change):

// Unconditional add — size equals loop count
void transformAll(List<int> items) {
  final List<String> result = <String>[];
  for (final int item in items) {
    result.add(item.toString());  // FLAGGED: use .map().toList()
  }
}

// Known size from range
void generateSequence(int count) {
  final List<int> result = <int>[];
  for (int i = 0; i < count; i++) {
    result.add(i * 2);  // FLAGGED: use List.generate(count, (i) => i * 2)
  }
}
```

## Impact

Any list-building loop with conditional logic will be falsely flagged. Common
patterns include:
- Filtering loops (add if condition met)
- Merge/coalesce loops (add when accumulator is flushed)
- Parser loops (add token when delimiter found)
- Grouping loops (add group when group boundary detected)

These are standard algorithms where the output size depends on the data.
