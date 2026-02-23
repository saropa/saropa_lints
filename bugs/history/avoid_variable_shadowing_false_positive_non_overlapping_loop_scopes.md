# Bug: `avoid_variable_shadowing` false positive on variables in non-overlapping for-loop scopes

## Resolution

**Fixed.** `_ShadowingChecker` now saves/restores `outerNames` around for/while/do loops and scoped blocks (if/switch/try), so sequential loops and sibling branches no longer leak variable names.


## Summary

The `avoid_variable_shadowing` rule incorrectly flags a loop variable in a
`for` loop when a previous, already-completed `for` loop used the same variable
name. In Dart, `for` loop variables are scoped to their loop body — once the
loop exits, the variable no longer exists. Two sequential loops using the same
variable name do not shadow each other because their scopes never overlap.

## Severity

**False positive** -- the rule reports shadowing where no shadowing exists.
The two variables are in non-overlapping scopes and cannot possibly be confused
with each other. Following the lint's advice to rename one of them adds
unnecessary naming complexity for no safety benefit.

## Reproduction

### Minimal example

```dart
String grammarArticle() {
  if (isEmpty) return '';
  final String lower = toLowerCase();

  const List<String> silentH = <String>['hour', 'honest', 'honor', 'heir'];
  for (final String ex in silentH) {    // scope A: `ex` exists here
    if (lower.startsWith(ex)) return 'an';
  }                                      // scope A ends: `ex` no longer exists

  const List<String> youSound = <String>['uni', 'use', 'user', 'union'];
  // FLAGGED: avoid_variable_shadowing
  //          "Declaration shadows a declaration from an outer scope"
  for (final String ex in youSound) {   // scope B: `ex` exists here
    if (lower.startsWith(ex)) return 'a';
  }                                      // scope B ends

  // ...
}
```

### Why this is NOT shadowing

Dart's scoping rules for `for` loops:

```dart
for (final String ex in silentH) {
  // `ex` is scoped to THIS loop body only
}
// `ex` does NOT exist here — it went out of scope

for (final String ex in youSound) {
  // This is a NEW `ex` — the previous one is gone
  // There is no "outer scope" variable named `ex` to shadow
}
```

The [Dart Language Specification](https://dart.dev/guides/language/spec) defines
`for` loop variables as local to the loop body. After the loop exits, the
variable is no longer in scope. The second `for` loop creates a fresh binding
with the same name — this is identical to reusing any local variable name in
a sequential block.

### Contrast with actual shadowing

```dart
final String ex = 'outer';          // scope: entire method body
for (final String ex in items) {    // shadows outer `ex` — TRUE POSITIVE
  print(ex);                        // which `ex`? inner (shadows outer)
}
print(ex);                          // outer `ex` — confusing
```

In this case, both `ex` variables exist simultaneously and the inner one
shadows the outer one. THIS should be flagged. The original example should NOT.

### Lint output

```
line 1000 col 10 • [avoid_variable_shadowing] Declaration shadows a
declaration from an outer scope. Shadowing occurs when a nested scope
declares a variable with the same name as one in an enclosing scope.
This can lead to confusion about which variable is being referenced
and is a common source of subtle bugs. {v3}
```

### Affected location (1 instance)

| File | Line | Variable | Previous declaration |
|------|------|----------|---------------------|
| `lib/string/string_extensions.dart` | 1000 | `ex` (in `for` loop) | Line 995 `ex` (in separate, completed `for` loop) |

## Root cause

The rule collects all variable declarations in the function body and checks if
any later declaration has the same name as an earlier one. It treats earlier
`for` loop variables as "outer scope" declarations that persist beyond the loop,
when in fact they are scoped strictly to the loop body.

### Likely detection gap

The rule probably builds a flat list or set of variable names encountered in
the function body. When it encounters a second `for (final String ex in ...)`,
it finds `ex` already in the set and reports shadowing. It does not check
whether the earlier `ex` is still in scope (i.e., whether the current position
is inside the earlier variable's scope).

### Correct scope analysis

For two variables to constitute shadowing, they must have **overlapping scopes**:

```
Variable A scope: [declaration_A ... end_of_scope_A]
Variable B scope: [declaration_B ... end_of_scope_B]

Shadowing: declaration_B is INSIDE scope A (B is nested within A)
Not shadowing: scope A ends BEFORE declaration_B (sequential, non-overlapping)
```

For sequential `for` loops, scope A ends at the closing `}` of the first loop,
and declaration B occurs after that point. The scopes do not overlap.

## Suggested fix

When checking for shadowing, verify that the earlier declaration is **still in
scope** at the point of the later declaration. A variable declared in a `for`
loop is only in scope within that loop's body:

```dart
void checkVariableDeclaration(SimpleIdentifier node) {
  final String name = node.name;

  // Find all previous declarations with the same name
  for (final previousDecl in previousDeclarationsNamed(name)) {
    // Check if the previous declaration's scope contains the current node
    if (isInScopeAt(previousDecl, node.offset)) {
      // TRUE shadowing: previous variable is still in scope
      reportLint(node);
      return;
    }
    // Previous variable went out of scope — not shadowing
  }
}

bool isInScopeAt(VariableDeclaration decl, int offset) {
  // Find the enclosing scope block for the declaration
  final scopeBlock = decl.thisOrAncestorOfType<Block>();
  if (scopeBlock == null) return false;

  // For for-loop variables, scope is the loop body
  final forStatement = decl.thisOrAncestorOfType<ForStatement>();
  if (forStatement != null) {
    return forStatement.body.offset <= offset &&
           offset <= forStatement.body.end;
  }

  // For regular block variables, scope is from declaration to end of block
  return decl.offset <= offset && offset <= scopeBlock.end;
}
```

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Sequential for loops with same variable name
void sequentialLoops() {
  for (final x in [1, 2, 3]) { print(x); }
  for (final x in [4, 5, 6]) { print(x); }  // NOT shadowing
}

// Sequential for-in loops with same name
void sequentialForIn(List<String> a, List<String> b) {
  for (final item in a) { print(item); }
  for (final item in b) { print(item); }  // NOT shadowing
}

// Sequential C-style for loops
void sequentialCStyle() {
  for (int i = 0; i < 5; i++) { print(i); }
  for (int i = 10; i < 15; i++) { print(i); }  // NOT shadowing
}

// Sequential blocks with same variable name
void sequentialBlocks() {
  { final String name = 'a'; print(name); }
  { final String name = 'b'; print(name); }  // NOT shadowing
}

// Should STILL flag (true positives, no change):

// Outer variable shadowed by inner loop variable
void nestedShadow() {
  final String item = 'outer';
  for (final item in ['inner']) {  // FLAGGED: shadows outer `item`
    print(item);
  }
}

// Outer loop variable shadowed by inner loop variable
void nestedLoopShadow() {
  for (final x in [1, 2]) {
    for (final x in [3, 4]) {  // FLAGGED: shadows outer loop `x`
      print(x);
    }
  }
}

// Method parameter shadowed by loop variable
void paramShadow(String name) {
  for (final name in ['a', 'b']) {  // FLAGGED: shadows parameter
    print(name);
  }
}
```

## Impact

Reusing a loop variable name in sequential (non-nested) loops is standard Dart
practice. Variables like `i`, `item`, `element`, `entry`, `e`, and `ex` are
conventionally reused across sequential loops because:

1. The semantics are the same (iterating over a collection)
2. The scopes never overlap (no confusion possible)
3. Inventing unique names (`ex1`, `ex2`) reduces clarity rather than improving it

This false positive will fire on any function with multiple sequential loops
that use the same idiomatic loop variable name.
