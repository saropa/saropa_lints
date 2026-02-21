# Task: `prefer_no_commented_code`

## Summary
- **Rule Name**: `prefer_no_commented_code`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §2 Comments & Documentation Rules

## Problem Statement

Commented-out code blocks clutter the codebase and create confusion:
1. **Is it dead?** Nobody knows if the commented code still works or is outdated
2. **Why is it there?** No context for why it was removed
3. **Git does this better** — removing code and using `git log` to find it is superior to keeping it commented out
4. **False positives** — developers sometimes run commented code by mistake when debugging

The rule should detect multi-line comments that look like Dart code.

## Description (from ROADMAP)

> Disallow commented-out code blocks.

## Trigger Conditions

1. A `//` line comment whose content looks like Dart code (starts with a Dart keyword, has method calls, assignment operators, etc.)
2. Multiple consecutive `//` comments that together form a code block
3. Block comments `/* ... */` containing what appears to be code

### What "looks like Dart code"
- Line starts with a Dart keyword: `var`, `final`, `const`, `if`, `else`, `for`, `while`, `return`, `class`, `void`, `int`, `String`, `bool`, `double`, `List`, `Map`, `Set`
- Line contains `=` (assignment) without explanation prose
- Line contains `(` and `)` (method call)
- Line ends with `;` (statement terminator)

## Implementation Approach

```dart
context.registry.addCompilationUnit((node) {
  for (final token in _getAllComments(node)) {
    if (_isCommentedCode(token.lexeme)) {
      reporter.atOffset(
        offset: token.offset,
        length: token.length,
        errorCode: code,
      );
    }
  }
});
```

`_isCommentedCode`: parse the comment text (stripping `//` or `/* */`) and check if it matches Dart code patterns.

## Code Examples

### Bad (Should trigger)
```dart
void processData() {
  // var result = compute();  ← trigger: commented code
  // if (result != null) {
  //   handleResult(result);
  // }
  doNewThing();
}
```

### Good (Should NOT trigger)
```dart
// This method computes the average of a list.
// Returns 0 if the list is empty.
double average(List<double> values) { ... }

// TODO: Implement caching here
void processData() { ... }

// Note: This is intentionally empty; the parent handles cleanup.
@override
void dispose() {
  super.dispose();
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Doc comment examples (`/// ```dart ...`) | **Suppress** — doc comment code examples are valid | Check if inside `///` triple-slash doc comment |
| `// TODO: var x = ...` | **Suppress** — TODO followed by code description is prose | Strip TODO/FIXME/NOTE prefixes |
| Comment explaining a formula: `// x = a + b * c` | **False positive** — math in comments looks like code | Hard to distinguish |
| Inline comment after code: `final x = foo(); // final y = bar();` | **Trigger** — inline commented code is still commented code | |
| `// ignore: some_rule` | **Suppress** — lint ignore comment | |
| Generated files | **Suppress** | |
| Single-line `// return early` prose | **Suppress** — this is natural language | |

## Unit Tests

1. Multiple consecutive `//` lines with Dart code → 1 lint
2. `// if (condition) {` inside method body → 1 lint
3. `// This is a description.` (prose) → no lint
4. `/// ```dart\n// code\n/// ````→ no lint (doc code example)

## Quick Fix

Offer "Remove commented code":
```dart
// Simply delete the commented lines
```

## Notes & Issues

1. **HIGH false positive risk** — many legitimate comments contain code-like syntax (mathematical formulas, pseudo-code explanations, examples in prose). The heuristic needs to be conservative.
2. **Doc comment code examples** inside `/// ``` ... ` ` `\`` blocks are a major false positive source and MUST be suppressed.
3. **Comment intent parsing** is inherently ambiguous. Consider requiring at least 3 consecutive lines of code-like comments before triggering.
4. **Team preference**: Some teams WANT commented code blocks as "historical notes". This might better be a stylistic (opt-in) rule rather than Recommended.
