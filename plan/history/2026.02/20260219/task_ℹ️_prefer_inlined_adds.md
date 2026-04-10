# Task: `prefer_inlined_adds`

## Summary

- **Rule Name**: `prefer_inlined_adds`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Style

## Problem Statement

A common Dart pattern seen in codebases migrated from Java or C# is to create an empty collection literal and then immediately add elements to it in subsequent statements:

```dart
final items = <String>[];
items.add('alpha');
items.add('beta');
items.add('gamma');
```

This pattern is unnecessarily verbose. Dart's collection literals support inline element specification, making the equivalent code both shorter and immutably initialized:

```dart
final items = <String>['alpha', 'beta', 'gamma'];
```

The inline form has several advantages:

1. It is shorter and easier to read.
2. The final variable is initialized completely at the declaration site — the reader does not need to scan forward to understand what `items` contains.
3. It communicates intent more clearly: the list is a fixed set of known values, not a dynamically built collection.
4. For `addAll` with a spread-compatible iterable, the spread operator `...` achieves the same effect: `final items = [...otherList, 'extra']`.

This rule targets the specific, high-confidence case where the collection is declared empty and immediately populated before any other use, which is always safe to inline.

## Description (from ROADMAP)

Flag sequential statement groups where a local variable is initialized with an empty list or set literal (`[]`, `<T>[]`, `{}`, `<T>{}`) and is immediately followed by one or more `.add()` or `.addAll()` calls before any other use of the variable, suggesting replacement with an inline collection literal.

## Trigger Conditions

The rule triggers when ALL of the following are true:

1. A local variable declaration initializes the variable with an empty list or set literal (`[]` or `{}`).
2. The variable is declared as `final` or `var` (not `const` — adding to a `const` is a compile error and cannot occur).
3. The immediately following statements in the same block are method invocations of `.add(element)` or `.addAll(iterable)` on the same variable.
4. No other use of the variable appears between the declaration and the add calls.

It does NOT trigger when:

- Elements are added inside conditionals (`if (...) items.add(...)`) — cannot be safely inlined.
- Elements are added inside loops — cannot be safely inlined.
- The add call is conditional (`.addAll` with a conditional expression).
- The variable is a `Map` (`.add()` is not a Map method; this rule targets `List` and `Set`).
- The variable is assigned to something before the adds complete.
- The list is later mutated further (adding more elements after some use).

## Implementation Approach

### AST Visitor

The detection requires flow analysis across adjacent statements, which is more complex than single-node analysis. Two strategies:

**Strategy A — Block-level analysis (recommended):**

```dart
context.registry.addBlock((block) {
  _analyzeBlock(block, reporter);
});
```

Walk statement pairs: find a `VariableDeclarationStatement` with an empty collection initializer, then check subsequent `ExpressionStatement` nodes for `.add()` / `.addAll()` calls on that variable.

**Strategy B — Variable declaration + lookahead:**

```dart
context.registry.addVariableDeclarationStatement((node) {
  _checkForAddPattern(node, reporter);
});
```

In `_checkForAddPattern`, look ahead in the parent block to find consecutive add statements.

Strategy A is cleaner and more robust. Use it.

### Detection Logic

```dart
void _analyzeBlock(Block block, ErrorReporter reporter) {
  final statements = block.statements;

  for (int i = 0; i < statements.length - 1; i++) {
    final stmt = statements[i];
    if (stmt is! VariableDeclarationStatement) continue;

    final decl = stmt.variables;
    if (decl.variables.length != 1) continue; // only single declarations

    final variable = decl.variables.first;
    final init = variable.initializer;

    // Must be an empty list literal [] or <T>[]
    if (!_isEmptyCollectionLiteral(init)) continue;

    final varName = variable.name.lexeme;

    // Collect consecutive add/addAll calls
    final addStatements = <ExpressionStatement>[];
    for (int j = i + 1; j < statements.length; j++) {
      final next = statements[j];
      if (!_isAddCall(next, varName)) break;
      addStatements.add(next as ExpressionStatement);
    }

    if (addStatements.isEmpty) continue;

    // Report on the variable declaration
    reporter.atNode(variable, code);
  }
}

bool _isEmptyCollectionLiteral(Expression? expr) {
  if (expr is ListLiteral) return expr.elements.isEmpty;
  if (expr is SetOrMapLiteral) {
    // Must be a Set (no colon-separated entries)
    return expr.elements.isEmpty && _isSetLiteral(expr);
  }

  return false;
}

bool _isAddCall(Statement stmt, String varName) {
  if (stmt is! ExpressionStatement) return false;
  final expr = stmt.expression;
  if (expr is! MethodInvocation) return false;
  final target = expr.target;
  if (target is! SimpleIdentifier) return false;
  if (target.name != varName) return false;
  final methodName = expr.methodName.name;
  return methodName == 'add' || methodName == 'addAll';
}
```

## Code Examples

### Bad (triggers rule)

```dart
void buildMenu() {
  // Empty list immediately populated — inline instead
  final items = <String>[];
  items.add('Home');
  items.add('Settings');
  items.add('Help');

  // Empty set immediately populated
  final tags = <String>{};
  tags.add('flutter');
  tags.add('dart');

  // addAll on an empty list
  final extras = <Widget>[];
  extras.addAll([Text('a'), Text('b')]);
}
```

### Good (compliant)

```dart
void buildMenu() {
  // Inline list literal — shorter, clearer
  final items = <String>['Home', 'Settings', 'Help'];

  // Inline set literal
  final tags = <String>{'flutter', 'dart'};

  // Spread for addAll equivalent
  final extras = <Widget>[Text('a'), Text('b')];
}
```

### Not triggering (conditional adds — cannot inline)

```dart
void buildMenuConditional(bool showAdmin) {
  // Conditional add — cannot be inlined, no lint
  final items = <String>[];
  items.add('Home');
  if (showAdmin) {
    items.add('Admin');
  }
  items.add('Help');
}

void buildMenuLoop(List<String> sources) {
  // Loop-based add — cannot be inlined, no lint
  final items = <String>[];
  for (final source in sources) {
    items.add(source);
  }
}
```

## Edge Cases & False Positives

- **Conditional adds**: Any `if` statement between the declaration and a later add call breaks the pattern. Stop collecting add statements as soon as a non-add statement is encountered.
- **Interleaved use**: If the variable is read (e.g., passed to a function or accessed for `.length`) between the adds, the inline pattern may change semantics. Stop collecting if any non-add use is found.
- **Map literals**: `final map = {};` followed by `map['key'] = value;` is a different pattern (subscript assignment, not `.add()`). This rule does not cover Maps.
- **`addAll` with a non-literal iterable**: `items.addAll(computeSomething())` — the result is `final items = [...computeSomething()]`. This is still an improvement, but confirm the expression has no side effects order dependency.
- **`const` lists**: You cannot call `.add()` on a `const` list — this is a compile error. The rule must never apply to `const` declarations. Check the keyword in the variable declaration list.
- **Growing lists**: If the variable has further add calls later in the block (after some intermediate use), only the initial consecutive sequence should be inlined, not the later ones.
- **`LinkedList`, `Queue`, and other collection types**: This rule targets `List` and `Set` only. If the declared type is a different collection, skip it.
- **Null-safety late declarations**: `late final items = <String>[];` — the `late` modifier means the variable might be set in a different context. Be careful about late declarations.
- **Negated empty check**: `if (items.isEmpty) items.add(...)` — this is an add inside a conditional and should not be flagged.

## Unit Tests

### Should Trigger (violations)

```dart
void example() {
  final list = <int>[];
  list.add(1); // LINT (on the declaration of 'list')
  list.add(2);
  list.add(3);

  final set = <String>{};
  set.add('a'); // LINT

  final mixed = <Object>[];
  mixed.addAll([1, 2, 3]); // LINT
}
```

### Should NOT Trigger (compliant)

```dart
void example(bool flag, List<String> source) {
  // Already inlined — no lint
  final list = <int>[1, 2, 3];

  // Conditional add — no lint
  final cond = <int>[];
  cond.add(1);
  if (flag) cond.add(2);

  // Loop-based add — no lint
  final loop = <String>[];
  for (final s in source) loop.add(s);

  // Variable used between adds — no lint
  final used = <int>[];
  used.add(1);
  print(used.length); // intermediate use
  used.add(2);
}
```

## Quick Fix

Replace the variable declaration and consecutive add statements with an inline literal:

```dart
class _PreferInlinedAddsFix extends DartFix {
  @override
  void run(...) {
    context.registry.addBlock((block) {
      // Find the declaration + add statements group
      // Build the inline literal from extracted add arguments
      // Replace declaration initializer with [arg1, arg2, ...]
      // Delete the add statements
    });
  }
}
```

The fix:

1. Collects all arguments from `.add(arg)` calls and elements from `.addAll([...])` calls.
2. Builds a new list/set literal string with those elements.
3. Replaces the initializer `[]` / `{}` with the new literal.
4. Deletes the consecutive add statements from the block.

This is a multi-edit fix — use `addDartFileEdit` with multiple `addDeletion` and `addSimpleReplacement` calls.

## Notes & Issues

- This rule is block-level analysis, which is more expensive than single-node analysis. Ensure the block-walking is efficient and exits early as soon as the consecutive add pattern breaks.
- The rule should NOT be applied to top-level variables or class fields — those are initialized once and adding to them implies module-level state management, which is different from the local-scope pattern this rule targets.
- Consider a `maxAdds` configuration threshold: if a list has more than N adds (e.g., 10), the inline form may actually be less readable than the verbose multi-line form, and the rule should not fire.
- This rule pairs well with `prefer_collection_literals` from `package:lints`, which discourages `List()` constructor calls. Ensure the two rules complement each other.
