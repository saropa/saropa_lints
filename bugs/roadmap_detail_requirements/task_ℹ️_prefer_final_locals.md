# Task: `prefer_final_locals`

## Summary
- **Rule Name**: `prefer_final_locals`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
Local variables that are assigned exactly once (at declaration or in a single subsequent
statement) and never reassigned afterward should be declared `final`. Declaring them
`final` prevents accidental reassignment later in the same scope, communicates intent to
readers, and makes code easier to reason about because the value bound to the name cannot
silently change. It also enables certain compiler optimizations and aligns with the
general Dart style preference for immutability where possible.

## Description (from ROADMAP)
Flag local variable declarations that use `var` or a bare type annotation when the
variable is never reassigned within its scope.

## Trigger Conditions
1. A local variable is declared with `var`, or with a type annotation but no `final` or
   `const` modifier.
2. The variable is initialized at the declaration site (or assigned exactly once before
   first use).
3. No subsequent `AssignmentExpression`, `++`, or `--` targets that variable within the
   same function or block scope.

## Implementation Approach

### AST Visitor
```dart
context.registry.addVariableDeclarationList((node) { ... });
```
For each non-final, non-const variable declaration inside a function/method body, collect
all assignments within the enclosing function body and check if any targets the declared
variable name.

### Detection Logic
1. Visit every `VariableDeclarationList` that is a descendant of a `FunctionBody` (i.e.,
   it is a local variable, not a class field).
2. For each variable in the declaration list, record its name.
3. Skip variables already marked `final` or `const`.
4. Skip variables that have no initializer and are not definitely assigned — they must
   receive an assignment, which is their one and only assignment; that pattern is still
   `final`-compatible, so check if there is more than one assignment in scope.
5. Collect all `AssignmentExpression` nodes within the enclosing `FunctionBody` whose
   left-hand side resolves to the same local variable element.
6. Also collect `PostfixExpression` and `PrefixExpression` with `++`/`--` operators on
   the variable.
7. If the total number of write operations (excluding the declaration initializer) is
   zero, report the variable declaration as a violation.
8. Special handling: for-in loop variables (`for (var item in list)`) — these are
   effectively final per iteration and should ideally use `final`; flag them.

## Code Examples

### Bad (triggers rule)
```dart
void process(List<String> items) {
  var count = items.length;        // never reassigned
  String message = 'Processing';  // never reassigned
  print('$message: $count items');
}
```

```dart
String buildUrl(String base, String path) {
  var separator = base.endsWith('/') ? '' : '/';  // never changed
  return '$base$separator$path';
}
```

### Good (compliant)
```dart
void process(List<String> items) {
  final count = items.length;
  final String message = 'Processing';
  print('$message: $count items');
}
```

```dart
void counter() {
  var total = 0;          // reassigned below — compliant
  for (var i = 0; i < 10; i++) {
    total += i;
  }
  print(total);
}
```

```dart
void withConditional(bool flag) {
  String result;            // uninitialized — assigned in exactly one branch each
  if (flag) {
    result = 'yes';
  } else {
    result = 'no';
  }
  // result assigned in both branches — still only one "write" per path,
  // but two assignment expressions exist in the AST: flag, don't report.
  print(result);
}
```

## Edge Cases & False Positives
- **Definite assignment in branches**: `if/else` that each assign the variable once
  produces two `AssignmentExpression` nodes in the AST even though each execution path
  only assigns once. The rule should count distinct AST assignment nodes; if there is more
  than one such node, the rule should NOT fire (conservative approach) because determining
  mutual exclusivity of branches requires flow analysis beyond simple AST walking.
- **For-in loop variable**: `for (var item in list)` — each iteration binds `item` fresh;
  semantically final per iteration. Flagging is correct; the fix is `for (final item in list)`.
- **Catch clause variables**: `catch (e, s)` — should be treated as final (they cannot be
  reassigned in Dart); do not flag as violations, do not suggest `final` (syntax doesn't
  allow it).
- **Variables in closures**: If a variable is captured by a closure that might assign it,
  the rule must detect that assignment even though it occurs inside a nested function body.
  Conservative approach: if the variable is captured by any closure inside the enclosing
  function, skip it.
- **`late` variables**: A `late` variable without `final` that is assigned once is a
  candidate, but the semantics differ (deferred init). Flag separately or skip.
- **Pattern variable declarations** (Dart 3): `var (a, b) = pair;` — each sub-variable
  should be assessed individually.
- **Loop variable `i` in `for (var i = 0; ...)` with `i++`**: The `i++` is a reassignment;
  rule must not fire. (It won't if the increment/decrement scan is correct.)

## Unit Tests

### Should Trigger (violations)
```dart
void example() {
  var name = 'Alice';       // LINT: never reassigned
  String city = 'London';   // LINT: never reassigned
  print('$name, $city');
}

void forIn(List<int> nums) {
  for (var n in nums) {     // LINT: loop variable should be final
    print(n);
  }
}
```

### Should NOT Trigger (compliant)
```dart
void example() {
  final name = 'Alice';          // ok: already final
  const city = 'London';         // ok: already const
  var count = 0;
  count++;                       // ok: reassigned
  print('$name $city $count');
}

void branches(bool b) {
  String result;
  if (b) {
    result = 'yes';
  } else {
    result = 'no';               // two assignments — skip (conservative)
  }
  print(result);
}

void loop() {
  for (var i = 0; i < 5; i++) { // ok: i++ is reassignment
    print(i);
  }
}
```

## Quick Fix
**Add `final` modifier (replace `var` with `final`, or prepend `final` to bare type).**

```dart
// Before
var greeting = 'Hello';
String city = 'London';

// After
final greeting = 'Hello';
final String city = 'London';
```

When the declaration uses `var`, replace `var` with `final`.
When the declaration uses a bare type (e.g., `String name = ...`), insert `final ` before
the type keyword.

## Notes & Issues
- Like `prefer_final_fields`, a similarly named rule exists in the official Dart linter.
  Confirm first whether the SDK's `prefer_final_locals` is already configured. If so,
  expose it at the Recommended tier in `analysis_options.yaml` rather than reimplementing.
- The most fragile part is branch analysis. Ship a conservative version first (two AST
  assignment nodes = don't flag) and refine using flow analysis helpers from
  `package:analyzer` if available.
- Performance: the inner scan over assignments is O(n) in function body size; this is
  acceptable. Avoid `CompilationUnit`-wide traversal.
