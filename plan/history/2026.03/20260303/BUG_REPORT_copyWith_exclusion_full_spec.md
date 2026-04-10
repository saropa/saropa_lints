# Bug Report (Full Spec): Exclude `copyWith` and Similar Patterns from Parameter-List and Cyclomatic-Complexity Rules

**Rules affected:** `avoid_long_parameter_list`, `avoid_high_cyclomatic_complexity`  
**Date:** 2026-03-03  
**Status:** Resolved (both rules implement copyWith exclusion)

---

## Executive Summary

Methods named `copyWith` (and equivalent immutable-update patterns) are a **standard, idiomatic Dart/Flutter pattern**. They necessarily have (1) many optional named parameters—one per field that can be overridden—and (2) a body that is a single `return` expression with one null-coalescing branch per parameter (`param ?? this.param`). As a result:

- **`avoid_long_parameter_list`** reports them as “too many parameters” even though the API is self-documenting and call sites are simple (e.g. `options.copyWith(width: 100)`).
- **`avoid_high_cyclomatic_complexity`** reports them because each `??` and ternary in the return expression counts as a branch, so mechanical boilerplate is treated as “high complexity.”

Both reports are **false positives** relative to the rules’ intent: the former targets hard-to-call, combinatorial APIs; the latter targets genuinely complex control flow. This document specifies why `copyWith` (and equivalent patterns) should be **excluded** from both rules and how to implement that exclusion.

---

## 1. Rule: `avoid_long_parameter_list`

### 1.1 Current Status: **RESOLVED**

Exclusion is already implemented in `AvoidLongParameterListRule` (`lib/src/rules/structure_rules.dart`) via `_shouldSkipLongParameterList`:

- Skip when the method or function **name is `copyWith`**.
- Skip when **every parameter is optional** (no `isRequiredPositional` or `isRequiredNamed`).

See DartDoc on the rule class and the helper (lines 1083–1090, 1128–1136). Fixture: `example_core/lib/structure/avoid_long_parameter_list_fixture.dart`.

### 1.2 Why Exclusion Is Correct (Rationale for This Rule)

- **Intent of the rule:** “Functions with many parameters are difficult to call correctly, hard to test with all combinations, and indicate the function may be doing too much work.” The rule suggests grouping parameters into a configuration object or using named parameters for self-documenting call sites.
- **Reality of `copyWith`:**
  - Call sites are **self-documenting:** `obj.copyWith(width: 100, height: 200)` — no combinatorial burden; callers pass only the fields they want to change.
  - The “many parameters” are **one optional named parameter per copyable field** — a direct mapping from the data type. There is no sensible way to “group” them without inventing a parallel parameter object (e.g. `copyWith(overrides: CardOptionsOverrides(width: v))`), which **worsens** call-site clarity and maintainability.
  - Enforcing “max 5 parameters” on `copyWith` would either force that worse API or force disabling the rule; both are bad outcomes. Excluding `copyWith` (and all-optional param lists) aligns the rule with its intent and preserves idiomatic Dart.

### 1.3 Recommended Exclusion Criteria (Already Implemented)

1. **ByName:** Do not report when the function/method name is exactly `copyWith`.
2. **By signature:** Do not report when every parameter is optional (no required positional, no required named). Such declarations are already self-documenting and do not represent “hard-to-call” APIs.

---

## 2. Rule: `avoid_high_cyclomatic_complexity`

### 2.1 Current Status: **RESOLVED**

The rule (`AvoidHighCyclomaticComplexityRule` in `lib/src/rules/complexity_rules.dart`) excludes methods and top-level functions named `copyWith` (Option A implemented). It reports any method or top-level function whose body has cyclomatic complexity greater than the threshold (15). A typical `copyWith` body consists of a single `return Constructor(...)` with many arguments of the form `param ?? this.param` (and occasionally ternaries for “clear override” flags). Each `??` and `? :` is counted as a branch, so a `copyWith` with 40+ optional parameters easily exceeds the threshold and is reported.

### 2.2 Why This Is a False Positive

- **Intent of the rule:** Reduce **logical** complexity—many branching paths that make the function hard to understand, test exhaustively, and maintain. The rule suggests extracting helper methods or using polymorphism instead of conditionals.
- **Reality of `copyWith` bodies:**
  - **Single path:** There is effectively one control path: “build and return a new instance.” There are no meaningful branches (no if/else logic, no loops, no switch).
  - **Mechanical branches:** The only “branches” are null-coalescing (`a ?? b`) and occasional ternaries (e.g. `clearX ? null : (x ?? this.x)`). These are **boilerplate** for “use argument if provided, else keep current value.” They do not double “testing surface area” in any meaningful way; the behavior is uniform and trivial.
  - **Refactoring suggested by the rule** (extract helpers, polymorphism) does not apply meaningfully. Extracting a tiny helper like `T _opt<T>(T? a, T b) => a ?? b` and calling it from every argument **does** reduce the reported complexity of the `copyWith` method (by moving branches into the helper), but that is a **cosmetic** refactor that does not improve readability or testability; it just satisfies the metric. The alternative—splitting the method “by domain”—would break the standard one-method `copyWith` API and harm maintainability.

So the **metric** correctly counts branches, but the **semantic meaning** of those branches (immutable-update boilerplate) does not match the rule’s intent. Treating `copyWith` as “high complexity” is therefore a false positive.

### 2.3 Reproduction

**File:** e.g. `lib/widgets/card_options.dart` (or any immutable options/state class with a hand-written `copyWith`).

**Method (conceptually):**

```dart
CardOptions copyWith({
  double? width,
  double? height,
  double? edgeThickness,
  // ... 40+ optional named parameters ...
  bool clearBaseColorOverride = false,
  bool clearAccentColorOverride = false,
}) {
  return CardOptions(
    width: width ?? this.width,
    height: height ?? this.height,
    edgeThickness: edgeThickness ?? this.edgeThickness,
    // ... one ?? per parameter, plus 2 ternaries for clear* ...
  );
}
```

**Observed diagnostic:**

```
code:     avoid_high_cyclomatic_complexity
severity: 4 (warning)
message:  [avoid_high_cyclomatic_complexity] Functions with cyclomatic complexity
          exceeding 15 have too many branching paths ...
startLineNumber: 152  (the copyWith method)
```

**Expected:** No report for this method, because it is a standard `copyWith` implementation with no meaningful control flow.

### 2.4 Recommended Fix for `avoid_high_cyclomatic_complexity`

**Option A (recommended): Skip by method/function name**

- Before reporting, check the name of the method or function. If it is `copyWith`, do **not** report.
- **Pros:** Simple, consistent with `avoid_long_parameter_list`, covers the vast majority of cases (hand-written and generated `copyWith`).
- **Cons:** Theoretically, a method could be named `copyWith` but contain genuinely complex logic; such cases are rare and can be refactored or suppressed if needed.

**Option B: Skip when body is “single return with only null-coalescing/ternary”**

- Heuristic: If the function body is a single return statement whose expression tree contains only constructor invocations, `??`, and `? :` (no `if`, `for`, `while`, `switch`, `catch`), treat as boilerplate and do not report.
- **Pros:** Could in theory cover other “builder-like” methods that are not named `copyWith`.
- **Cons:** More complex to implement and to define precisely; risk of false negatives (missing real complexity) or false positives (misclassifying). Name-based skip is simpler and sufficient.

**Implementation sketch (Option A):**

In `AvoidHighCyclomaticComplexityRule.runWithReporter`, when visiting a `MethodDeclaration` or `FunctionDeclaration`:

- Resolve the name (e.g. `node.name.lexeme` for methods, or the function name for top-level functions).
- If the name is `copyWith`, return without reporting.
- Otherwise, compute complexity and report as today.

Example (conceptual):

```dart
context.addMethodDeclaration((MethodDeclaration node) {
  if (node.name.lexeme == 'copyWith') return;  // exclude copyWith
  if (node.body is EmptyFunctionBody) return;
  final int complexity = _computeComplexity(node.body);
  if (complexity > _threshold) {
    reporter.atToken(node.name);
  }
});

context.addFunctionDeclaration((FunctionDeclaration node) {
  if (node.name?.lexeme == 'copyWith') return;  // exclude top-level copyWith if any
  final int complexity = _computeComplexity(node.functionExpression.body);
  if (complexity > _threshold) {
    reporter.atToken(node.name ?? node.functionExpression);
  }
});
```

Update the rule’s DartDoc to state that **methods or functions named `copyWith` are excluded**, because they implement the standard immutable-update pattern and their apparent complexity is mechanical (null-coalescing per parameter), not logical.

### 2.5 Test Fixture and CHANGELOG

- **Fixture:** Add a GOOD case in the cyclomatic-complexity fixture: a class with a `copyWith` method that has >15 `??` (and optionally ternaries) in a single return. This case must **not** produce a diagnostic.
- **CHANGELOG:** Note that `avoid_high_cyclomatic_complexity` now excludes methods/functions named `copyWith` to avoid false positives on the standard immutable-update pattern.

---

## 3. Scope: What Counts as “copyWith” for Exclusion

For both rules, the **minimal** and **recommended** criterion is:

- **Name-based:** The function or method name is exactly `copyWith`.

This matches:

- Hand-written `copyWith` on immutable data classes (e.g. `CardOptions`, BLoC state, Equatable models).
- Generated `copyWith` from code generation (e.g. Freezed, built_value) when the generated method is named `copyWith`.

Optional extensions (not required for the bug fix):

- **All-optional parameter list** (already used for `avoid_long_parameter_list`): For cyclomatic complexity, one could in theory also skip when the parameter list is all optional **and** the body is a single return with no `if`/`for`/`while`/`switch`/`catch`. That would require a bit more AST inspection; the name-based skip is sufficient and consistent.

---

## 4. References and Related Work

- **Existing bug report (avoid_long_parameter_list):** `bugs/history/avoid_long_parameter_list_copyWith_false_positive.md` — documents the fix for the long-parameter-list rule (exclusion by `copyWith` name and by all-optional params).
- **Rule implementations:**
  - `lib/src/rules/structure_rules.dart`: `AvoidLongParameterListRule`, `_shouldSkipLongParameterList`.
  - `lib/src/rules/complexity_rules.dart`: `AvoidHighCyclomaticComplexityRule`, `_computeComplexity`, `_ComplexityCounter`.
- **Consumer impact:** In projects with rich immutable options (e.g. Flutter `CardOptions` with 40+ fields), both rules fire on `copyWith`. Fixing the parameter list alone leaves the cyclomatic-complexity warning; fixing both requires either (a) excluding `copyWith` in the complexity rule as above, or (b) refactoring the body with helpers (e.g. `_opt`/`_clearable`) purely to satisfy the metric—which increases indirection without improving clarity. Option (a) is the correct product behavior.

---

## 5. Environment

- **saropa_lints:** current (e.g. 6.x)
- **Rule versions:** `avoid_long_parameter_list` v6, `avoid_high_cyclomatic_complexity` v2
- **Dart SDK:** 3.x
- **Example trigger project:** Any Flutter/Dart project with an immutable class and a hand-written `copyWith` (e.g. `CardOptions` in a game/widget library with many display parameters).

---

## 6. Summary Checklist for Implementers

| Item | Rule | Status |
|------|------|--------|
| Exclude when name is `copyWith` | `avoid_long_parameter_list` | Done (`_shouldSkipLongParameterList`) |
| Exclude when all params optional | `avoid_long_parameter_list` | Done (`_shouldSkipLongParameterList`) |
| Exclude when name is `copyWith` | `avoid_high_cyclomatic_complexity` | Done |
| DartDoc for exclusion | `avoid_high_cyclomatic_complexity` | Done |
| Fixture GOOD case (copyWith, high ?? count) | `avoid_high_cyclomatic_complexity` | Done |
| CHANGELOG entry | `avoid_high_cyclomatic_complexity` | Done (if released) |

This document serves as the full and detailed specification for excluding `copyWith` from both rules so that the standard Dart immutable-update pattern is not flagged as a maintenance or complexity problem.
