# Bug: `avoid_unused_assignment` false positive on variable reassignment inside loops

## Resolution

**Fixed.** `_isInsideLoop` conservatively skips all assignments inside loop bodies. Loop condition back-edges are no longer missed.


## Summary

The `avoid_unused_assignment` rule incorrectly flags variable assignments inside
`while` and `for` loop bodies when the assigned variable is subsequently read by
the loop's own condition expression on the next iteration. The rule fails to
account for the control flow edge from the end of the loop body back to the loop
condition, where the reassigned variable is evaluated.

## Severity

**False positive** -- the rule claims the assignment "is never read before being
overwritten or going out of scope," but the variable IS read by the loop
condition on the next iteration. This produces noise on standard loop-and-mutate
patterns and may lead developers to incorrectly remove assignments, breaking
loop termination logic.

## Reproduction

### Minimal example 1: while loop with body reassignment

```dart
String? removeLeadingAndTrailing(String? find, {bool trim = false}) {
  if (isEmpty || find == null || find.isEmpty) return this;
  String value = trim ? this.trim() : this;

  while (value.startsWith(find)) {
    // FLAGGED: avoid_unused_assignment
    value = value.substringSafe(find.length);   // line 808
    // FLAGGED: avoid_unused_assignment
    if (trim) value = value.trim();              // line 809
  }

  while (value.endsWith(find)) {
    // FLAGGED: avoid_unused_assignment
    value = value.substringSafe(0, value.length - find.length);  // line 812
    if (trim) value = value.trim();
  }

  return value.isEmpty ? null : value;
}
```

**Why the assignments are NOT unused:**

```
Iteration flow:
  while (value.startsWith(find))     ← reads `value`
    value = value.substringSafe(...)  ← assigns `value` (FLAGGED)
    if (trim) value = value.trim()   ← assigns `value` (FLAGGED)
  ↑_________________________________↗  loop back → reads `value` again!
```

After the body assignments, control returns to `value.startsWith(find)` which
reads the newly assigned value. The assignment is absolutely necessary for the
loop to make progress and eventually terminate.

### Minimal example 2: while loop with single reassignment

```dart
String collapseMultilineString({required int cropLength, bool appendEllipsis = true}) {
  if (isEmpty) return this;
  final String collapsed = replaceAll('\n', ' ').replaceAll('  ', ' ');
  if (collapsed.length <= cropLength) return collapsed.trim();

  String cropped = collapsed.substringSafe(0, cropLength + 1);
  while (cropped.isNotEmpty && !cropped.endsWithAny(commonWordEndings)) {
    // FLAGGED: avoid_unused_assignment
    cropped = cropped.substringSafe(0, cropped.length - 1);  // line 1107
  }
  // ... uses cropped below
}
```

**`cropped` is read** by the while condition `cropped.isNotEmpty && !cropped.endsWithAny(...)` on the next iteration.

### Minimal example 3: for loop with accumulator

```dart
List<String> splitCapitalizedUnicode({int minLength = 1}) {
  if (isEmpty) return <String>[];
  List<String> parts = split(pattern);

  if (minLength > 1 && parts.length > 1) {
    final List<String> merged = <String>[];
    String currentBuffer = parts[0];
    for (int i = 1; i < parts.length; i++) {
      final String nextPart = parts[i];
      if (currentBuffer.length < minLength || nextPart.length < minLength) {
        // FLAGGED: avoid_unused_assignment
        currentBuffer += nextPart;    // line 447
      } else {
        merged.add(currentBuffer);
        currentBuffer = nextPart;
      }
    }
    merged.add(currentBuffer);  // ← reads currentBuffer after loop
  }
}
```

**`currentBuffer` is read** both on the next iteration's condition check and
after the loop on the `merged.add(currentBuffer)` call.

### Lint output

```
line 808 col 7 • [avoid_unused_assignment] Variable is assigned a value
that is never read before being overwritten or going out of scope. The
assignment wastes computation, and the unused result often signals a logic
error where the value was meant to be used in a subsequent expression or
return statement. {v3}
```

### All affected locations (5 instances)

| File | Line | Variable | Loop type | Read location |
|------|------|----------|-----------|---------------|
| `lib/string/string_extensions.dart` | 447 | `currentBuffer` | `for` | Loop body (next iter) + line 455 after loop |
| `lib/string/string_extensions.dart` | 808 | `value` | `while` | While condition (next iter) |
| `lib/string/string_extensions.dart` | 809 | `value` | `while` | While condition (next iter) |
| `lib/string/string_extensions.dart` | 812 | `value` | `while` | While condition (next iter) |
| `lib/string/string_extensions.dart` | 1107 | `cropped` | `while` | While condition (next iter) |

## Root cause

The rule's data-flow analysis does not model the **back edge** of loops. In a
`while` or `for` loop, control flows from the end of the loop body back to the
loop condition. Any variable assigned in the body and read in the condition is
NOT unused -- it is read on the next iteration.

### Control Flow Graph (CFG) for while loop

```
                    ┌─────────────────────────┐
                    │                         │
                    ▼                         │
         ┌─── while (value.startsWith(find)) ─┘
         │              │ true
         │              ▼
         │    value = value.substringSafe(...)   ← assignment
         │              │
         │    if (trim) value = value.trim()     ← assignment
         │              │
         │              └───────────────────────── back to while condition
         │ false
         ▼
    return value   ← also reads value
```

The assignments at lines 808/809/812 flow back to the while condition, which
reads `value`. A correct "unused assignment" analysis must include this back
edge in its reaching-definitions computation.

### Likely detection gap

The rule probably performs a **forward-only** scan through the function body:
for each assignment, it checks whether the variable is read before the next
assignment or end of scope. This misses the loop back edge entirely, treating
the assignment at the end of the loop body as if control only flows forward
to the next statement (which may be another assignment or the end of scope).

A correct implementation needs to use a **fixed-point iteration** over the
CFG (standard reaching-definitions analysis) or at minimum recognize that
assignments inside loop bodies always have a successor edge to the loop
condition.

## Suggested fix

### Option A: CFG-based analysis (correct)

Build or use the Dart analyzer's control flow graph. For each assignment,
check if the variable is live (read before being overwritten) on ANY successor
path, including back edges.

### Option B: Heuristic exemption (simple)

If an assignment occurs inside a `WhileStatement`, `DoStatement`, or
`ForStatement` body, and the assigned variable appears in the loop's condition
expression, do not flag it:

```dart
void checkAssignment(AssignmentExpression node) {
  final variableName = node.leftHandSide.toString();

  // Walk up to find enclosing loop
  AstNode? parent = node.parent;
  while (parent != null) {
    if (parent is WhileStatement) {
      // Check if variable is read in the condition
      if (referencesVariable(parent.condition, variableName)) {
        return; // Do not flag -- loop condition reads this variable
      }
    }
    if (parent is ForStatement && parent.forLoopParts is ForParts) {
      final parts = parent.forLoopParts as ForParts;
      if (parts.condition != null &&
          referencesVariable(parts.condition!, variableName)) {
        return; // Do not flag
      }
    }
    parent = parent.parent;
  }

  // ... existing unused-assignment logic
}
```

### Option C: Conservative exemption (simplest)

Do not flag any assignment inside a loop body. This is overly conservative but
eliminates the false positive class entirely.

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// While loop: variable read in condition on next iteration
void whileReadInCondition() {
  String value = 'aaa_bbb_ccc';
  while (value.startsWith('a')) {
    value = value.substring(1);  // read by while condition
  }
  print(value);
}

// While loop: variable with conditional reassignment
void whileConditionalReassign() {
  String s = 'hello world';
  while (s.contains(' ')) {
    s = s.replaceFirst(' ', '');
    if (s.length > 5) s = s.trim();  // read by while condition
  }
  print(s);
}

// For loop: accumulator read after loop
void forLoopAccumulator() {
  String buffer = '';
  for (int i = 0; i < 10; i++) {
    buffer += i.toString();  // read after loop
  }
  print(buffer);
}

// For loop: variable read in condition and after loop
void forLoopCondition() {
  int sum = 0;
  for (int i = 0; sum < 100; i++) {
    sum += i;  // read by for condition
  }
  print(sum);
}

// Should STILL flag (true positives, no change):

// Assignment immediately overwritten (no loop)
void overwritten() {
  String value = 'first';   // FLAGGED: overwritten below without read
  value = 'second';
  print(value);
}

// Assignment never read at all
void neverRead() {
  String value = compute();  // FLAGGED: never read
}
```

## Impact

Any code that uses a `while` or `for` loop with a mutable variable in the
condition will produce false positives. This is an extremely common pattern:
- String processing loops (trim, strip, search)
- Iterative algorithms (binary search, GCD, convergence)
- Parser loops (consume tokens while condition holds)
- Accumulator patterns (build result in loop, read after)

The five instances in `string_extensions.dart` alone demonstrate how pervasive
this is in a single utility file. A typical codebase would have dozens of
false positives from this pattern.
