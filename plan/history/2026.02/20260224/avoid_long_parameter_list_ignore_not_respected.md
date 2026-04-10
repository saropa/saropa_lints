# Bug: `// ignore: avoid_long_parameter_list` Not Respected

**Rule:** `avoid_long_parameter_list`
**Severity:** Medium — prevents users from suppressing known false positives
**Reported:** 2026-02-24
**Status:** Fixed

---

## Summary

The `// ignore: avoid_long_parameter_list` comment placed immediately before a method declaration does not suppress the diagnostic. The lint fires despite the ignore directive, producing a false positive that cannot be silenced.

## Reproduction

### Source file: `saropa_dart_utils/lib/datetime/date_time_utils.dart`

```dart
  /// Returns `true` if all provided date/time components are within valid
  /// ranges.
  ///
  /// Valid ranges for each component:
  /// - [year]: 0-9999
  /// - [month]: 1-12
  /// - [day]: 1 to max days in [month] (requires [month] to be set)
  /// - [hour]: 0-23
  /// - [minute]: 0-59
  /// - [second]: 0-59
  /// - [millisecond]: 0-999
  /// - [microsecond]: 0-999
  ///
  /// Components that are `null` are not validated.
  @useResult
  // All 8 named params are needed to validate each DateTime component
  // ignore: avoid_long_parameter_list
  static bool isValidDateParts({
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
    int? millisecond,
    int? microsecond,
  }) {
    // ...
  }
```

### IDE diagnostic output

```json
{
  "code": "avoid_long_parameter_list",
  "severity": 2,
  "message": "[avoid_long_parameter_list] Function has too many parameters (max 5)...",
  "source": "dart",
  "startLineNumber": 361,
  "startColumn": 3,
  "endLineNumber": 417,
  "endColumn": 4
}
```

### Expected behavior

The `// ignore: avoid_long_parameter_list` comment on the line immediately before `static bool isValidDateParts(...)` should suppress the diagnostic.

### Actual behavior

The diagnostic fires and spans lines 361-417 (from the `///` doc comment through the closing brace). The `// ignore:` comment on line 377 is completely ignored.

## Root Cause Analysis

The problem is in `AvoidLongParameterListRule.runWithReporter()` in `lib/src/rules/structure_rules.dart` (lines 1097-1111):

```dart
context.addMethodDeclaration((MethodDeclaration node) {
  final FormalParameterList? params = node.parameters;
  if (params != null && params.parameters.length > _maxParameters) {
    reporter.atNode(node);  // <-- BUG: reports at entire MethodDeclaration node
  }
});
```

`reporter.atNode(node)` reports the diagnostic at the **entire `MethodDeclaration` node**, which includes:
1. The documentation comment (`///` starting at line 361)
2. Annotations (`@useResult` at line 375)
3. The method signature and body (lines 378-417)

The Dart analysis server's `// ignore:` mechanism works by checking if there is an ignore comment on the **same line or the line immediately before** the diagnostic's start position. Since `node.offset` points to the beginning of the doc comment (line 361), the analysis server looks for `// ignore:` on line 360 or 361 — **not** line 377 where the user placed it.

### Why line 361?

`MethodDeclaration.offset` in the Dart AST returns the offset of the **first token**, which includes the documentation comment. The node span is:
- **Start:** Line 361 (doc comment `/// Returns...`)
- **End:** Line 417 (closing `}`)

The `// ignore:` comment on line 377 is **16 lines below** the diagnostic start, so the analysis server never sees it as a suppression directive for this diagnostic.

### Same issue affects `addFunctionDeclaration` path

The `FunctionDeclaration` handler (lines 1097-1103) has the same bug:

```dart
context.addFunctionDeclaration((FunctionDeclaration node) {
  final FunctionExpression function = node.functionExpression;
  final FormalParameterList? params = function.parameters;
  if (params != null && params.parameters.length > _maxParameters) {
    reporter.atNode(node);  // Same issue: reports at full node including docs
  }
});
```

## Proposed Fix

Report the diagnostic at the **parameter list** or the **method/function name** instead of the entire declaration node. This makes the diagnostic position match where the user would logically place an `// ignore:` comment:

### Option A: Report at the parameter list (recommended)

```dart
context.addMethodDeclaration((MethodDeclaration node) {
  final FormalParameterList? params = node.parameters;
  if (params != null && params.parameters.length > _maxParameters) {
    reporter.atNode(params);  // Report at parameter list, not entire method
  }
});

context.addFunctionDeclaration((FunctionDeclaration node) {
  final FunctionExpression function = node.functionExpression;
  final FormalParameterList? params = function.parameters;
  if (params != null && params.parameters.length > _maxParameters) {
    reporter.atNode(params);  // Report at parameter list, not entire function
  }
});
```

**Benefits:**
- `// ignore:` on the line before the parameter list works naturally
- IDE highlights the parameter list specifically (more precise, more actionable)
- The ignore comment can go right before the signature where it makes sense

### Option B: Report at the method name token

```dart
reporter.atToken(node.name);
```

This would also work for `// ignore:` placement but highlights only the name rather than the problematic parameter list.

## Scope of Impact

This bug likely affects **any rule** that reports `reporter.atNode()` on a declaration node with documentation comments. Users cannot suppress these diagnostics with `// ignore:` comments unless they place the comment above the doc comment, which is unintuitive and breaks dartdoc conventions.

### Other potentially affected rules

Any rule calling `reporter.atNode(node)` where `node` is a `MethodDeclaration`, `FunctionDeclaration`, or `ClassDeclaration` with documentation comments may have the same issue. Consider auditing:

- `AvoidGodClassRule` (reports at `ClassDeclaration`)
- `PreferStaticClassRule` (reports at `ClassDeclaration`)
- `PreferStaticMethodRule` (reports at `MethodDeclaration`)
- Any other rules reporting at declaration-level nodes

## Workaround

Until fixed, users can work around this by using the file-level ignore:

```dart
// ignore_for_file: avoid_long_parameter_list
```

However, this suppresses **all** occurrences in the file, which is undesirable.

Alternatively, placing the `// ignore:` comment above the doc comment would work, but is unintuitive:

```dart
  // ignore: avoid_long_parameter_list
  /// Returns `true` if all provided date/time components are within valid
  /// ranges.
  @useResult
  static bool isValidDateParts({
```

## Resolution

**Fixed** on 2026-02-24 with two complementary changes:

### 1. Framework fix (`lib/src/saropa_lint_rule.dart`)

`SaropaDiagnosticReporter.atNode()` now detects `AnnotatedNode` (the base class for all declaration nodes) and adjusts the diagnostic start to `firstTokenAfterCommentAndMetadata.offset`. This skips past doc comments and metadata annotations, so `// ignore:` placed before the signature works correctly. Fixes all 47 affected rules at once.

### 2. Rule-specific fix (`lib/src/rules/structure_rules.dart`)

`AvoidLongParameterListRule` now reports at the `FormalParameterList` node instead of the full `MethodDeclaration`/`FunctionDeclaration`. This provides more precise IDE highlighting (just the parameter list, not the entire method body).
