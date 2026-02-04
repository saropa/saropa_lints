# Bug: `avoid_nested_assignments` false positive on arrow function body assignments

## Rule

`avoid_nested_assignments` in `lib/src/rules/control_flow_rules.dart` (line 934)

## Severity

**Medium** — This is a systematic false positive that flags every arrow function (`=>`) whose body is a simple assignment, including the extremely common `setState(() => field = value)` Flutter pattern. Additionally, the rule's `errorSeverity` is `DiagnosticSeverity.WARNING` when it should be `DiagnosticSeverity.INFO` for the cases it legitimately catches.

## Summary

The rule incorrectly flags assignment expressions used as the body of arrow functions (`=>`). In `setState(() => _field = value)`, the AST parent of the `AssignmentExpression` is an `ExpressionFunctionBody`, which is not in the rule's skip list. The assignment is not truly "nested" — it is the sole statement and entire purpose of the arrow function. There is no ambiguity about data flow, no risk of confusing assignment with comparison, and no logic error risk.

## Triggering Code (false positive)

```dart
// Flutter setState with arrow function — extremely common pattern
void _refreshRandomFact() {
  if (!mounted) return;
  setState(() => _randomType = DidYouKnowTypes.values.randomItem());
  //            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  //            Flagged: "Assignment expression embedded inside another expression"
}
```

The lint reports at the `AssignmentExpression` node, highlighting `_randomType = DidYouKnowTypes.values.randomItem()`.

## Other examples that would false-positive

```dart
// setState — the most common case
setState(() => _isLoading = true);
setState(() => _selectedIndex = index);
setState(() => _errorMessage = null);

// Callback assignments
widget.onChanged?.call(() => _value = newValue);

// Void arrow functions in general
void Function() resetCallback = () => _counter = 0;

// Sort/forEach with side-effect assignment
items.forEach((item) => _total = _total + item.price);
```

All of these use assignment as the sole body of an arrow function. The intent is unambiguous.

## Correct positives (should still be flagged)

These are the genuinely dangerous patterns the rule should catch:

```dart
// Assignment inside condition — real bug risk
if (x = getValue()) { ... }

// Assignment as argument — obscured data flow
doSomething(x = getValue());

// Assignment inside return — unclear intent
return x = computeValue();

// Chained assignments inside expressions
print(a = b = c);
```

## Root Cause

`control_flow_rules.dart` lines 959–977:

```dart
context.registry.addAssignmentExpression((AssignmentExpression node) {
  final AstNode? parent = node.parent;

  // Skip if parent is ExpressionStatement (standalone assignment)
  if (parent is ExpressionStatement) return;

  // Skip if parent is ForEachParts (for-in loop variable)
  if (parent is ForEachParts) return;

  // Skip if parent is VariableDeclaration
  if (parent is VariableDeclaration) return;

  // Skip if parent is CascadeExpression (e.g. obj..field = value)
  if (parent is CascadeExpression) return;

  // Report nested assignment            ← ⚠ No ExpressionFunctionBody check
  reporter.atNode(node, code);
});
```

**Step-by-step for `setState(() => _randomType = value)`:**

1. The AST for `() => _randomType = DidYouKnowTypes.values.randomItem()` is:
   - `FunctionExpression`
     - `ExpressionFunctionBody` (the `=>` body)
       - `AssignmentExpression` (`_randomType = ...`)
2. The rule visits the `AssignmentExpression` and checks its parent.
3. Parent is `ExpressionFunctionBody`, not any of the four skip types.
4. The rule reports it as a nested assignment.

But an `ExpressionFunctionBody` is semantically equivalent to a `BlockFunctionBody` containing a single `ExpressionStatement`. The arrow syntax `() => x = value` is just shorthand for `() { x = value; }`, which would NOT be flagged (because the parent would be `ExpressionStatement`).

## Suggested Fix

Add `ExpressionFunctionBody` to the skip list, since an assignment as the sole body of an arrow function is a standalone statement, not a nested expression:

```dart
context.registry.addAssignmentExpression((AssignmentExpression node) {
  final AstNode? parent = node.parent;

  // Skip if parent is ExpressionStatement (standalone assignment)
  if (parent is ExpressionStatement) return;

  // Skip if parent is ForEachParts (for-in loop variable)
  if (parent is ForEachParts) return;

  // Skip if parent is VariableDeclaration
  if (parent is VariableDeclaration) return;

  // Skip if parent is CascadeExpression (e.g. obj..field = value)
  if (parent is CascadeExpression) return;

  // Skip if parent is ExpressionFunctionBody (arrow function body).
  // () => x = value is shorthand for () { x = value; } — the assignment
  // is the sole statement, not embedded inside another expression.
  if (parent is ExpressionFunctionBody) return;

  // Report nested assignment
  reporter.atNode(node, code);
});
```

This is consistent with the existing `CascadeExpression` exclusion added in a prior fix — both are cases where the AST parent type differs from what a developer would consider a "standalone assignment."

## Severity Should Be Downgraded

Independent of the false positive, the `errorSeverity` should be `DiagnosticSeverity.INFO`, not `DiagnosticSeverity.WARNING`:

```dart
static const LintCode _code = LintCode(
  name: 'avoid_nested_assignments',
  // ...
  errorSeverity: DiagnosticSeverity.WARNING,  // ← Should be INFO
);
```

**Rationale:** The legitimate cases this rule catches (e.g., `if (x = y)`) are style/readability concerns in Dart. Unlike C/C++ where `if (x = y)` silently compiles and causes bugs, Dart's type system prevents accidental assignment-in-condition for non-bool types. The remaining risk is low enough for INFO severity. WARNING should be reserved for patterns with high bug probability.

## Precedent

The `CascadeExpression` exclusion (changelog entry, version prior) established the pattern of adding AST parent types to the skip list when idiomatic Dart syntax creates `AssignmentExpression` nodes that aren't truly "nested." Arrow function bodies are the same class of issue — the Dart syntax produces an AST structure that looks nested but isn't semantically nested.

## Discovered In

- **File:** `lib/components/home/section/home_section_did_you_know.dart` (line 64)
- **Project:** contacts (Saropa)
- **Code:** `setState(() => _randomType = DidYouKnowTypes.values.randomItem())`
- **Context:** Standard Flutter `setState` call with arrow function — zero ambiguity about intent
