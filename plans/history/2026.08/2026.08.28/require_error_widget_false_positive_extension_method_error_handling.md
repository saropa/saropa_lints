# BUG: `require_error_widget` — False positive when error handling is delegated to extension method

**Status: Fixed**

Created: 2026-08-28
Rule: `require_error_widget`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (line ~1105)
Severity: False positive
Rule version: current
Suppression count in downstream project: **56** (100% FP rate in sample of 10)

---

## Summary

The rule requires `FutureBuilder` / `StreamBuilder` closures to contain error
handling, but it detects this by checking for literal `.hasError` / `.error`
accesses on the snapshot parameter inside the builder body. When error handling
is delegated to an extension method (e.g., `snapshot.snapLoadingProgress()` which
internally calls `reportErrorIfAny()`), the rule cannot see through the
indirection and flags the builder as missing error handling.

**40+ existing ignore comments in the downstream project reference this exact
filename** (`saropa_lints/bugs/require_error_widget_false_positive_extension_method_error_handling.md`)
**but the file was never created.** This report fills that gap.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_error_widget'" lib/src/rules/
# lib/src/rules/widget/widget_patterns_require_rules.dart:1105:    'require_error_widget',
```

**Emitter registration:** `lib/src/rules/widget/widget_patterns_require_rules.dart:1105`

---

## Reproducer

```dart
// Extension that handles errors (defined in snapshot_utils.dart)
extension SnapExtension on AsyncSnapshot {
  Widget? snapLoadingProgress() {
    // Internally checks hasError, connectionState, etc.
    if (hasError) {
      reportErrorIfAny();
      return const ErrorPlaceholder();
    }
    if (connectionState == ConnectionState.waiting) {
      return const LoadingIndicator();
    }
    return null;
  }
}

// Builder that delegates error handling — SHOULD NOT lint
class UserProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint (false positive)
    return FutureBuilder<UserProfileData>(
      future: _userProfileFuture,
      builder: (BuildContext context, AsyncSnapshot<UserProfileData> snapshot) {
        // Error handling is inside snapLoadingProgress()
        final Widget? snapWaiting = snapshot.snapLoadingProgress();
        if (snapWaiting != null) {
          return snapWaiting; // returns error widget OR loading widget
        }
        // Only reached when data is ready
        return UserProfileContent(data: snapshot.data!);
      },
    );
  }
}

// Builder with inline error handling — SHOULD NOT lint (already works)
class InlineExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Data>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<Data> snapshot) {
        if (snapshot.hasError) { // OK — rule sees this
          return ErrorWidget(snapshot.error!);
        }
        return DataWidget(data: snapshot.data!);
      },
    );
  }
}
```

**Frequency:** Always — fires whenever error handling is not literally present
in the builder closure body, regardless of extension method delegation.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — error handling exists via `snapLoadingProgress()` extension |
| **Actual** | `[require_error_widget] FutureBuilder/StreamBuilder should handle error state` reported on the builder |

---

## AST Context

```
InstanceCreationExpression (FutureBuilder)
  └─ ArgumentList
      └─ NamedExpression (builder:)
          └─ FunctionExpression
              └─ Block
                  └─ VariableDeclarationStatement
                      └─ MethodInvocation (snapshot.snapLoadingProgress())
                          ↑ rule does not recognize this as error handling
                  └─ IfStatement (snapWaiting != null)
                  └─ ReturnStatement
```

---

## Root Cause

### Hypothesis A: Text-only detection of `.hasError` / `.error`

The rule walks the builder's `Block` looking for `PrefixedIdentifier` or
`PropertyAccess` nodes matching `snapshot.hasError` or `snapshot.error`. An
extension method call like `snapshot.snapLoadingProgress()` is a
`MethodInvocation` — a different AST node type that the rule does not inspect.
The rule cannot (and probably should not) resolve the extension method body to
check for error handling inside it.

### Hypothesis B: Allowlist approach

Rather than resolving extension method bodies (expensive and fragile), the rule
could accept a configurable allowlist of method names that are known to handle
errors (e.g., `snapLoadingProgress`, `snapOrNull`). Or it could check whether
ANY method is called on the snapshot parameter and assume the caller is handling
it, since the snapshot is being consumed.

---

## Suggested Fix

Option A (conservative): Add an allowlist of known extension method names that
constitute error handling. Default to common patterns like
`snapLoadingProgress`.

Option B (broader): If the snapshot parameter is passed to or has a method called
on it whose return value is checked (e.g., `final x = snapshot.someMethod(); if (x != null) return x;`),
treat that as delegated error handling and suppress the diagnostic.

---

## Fixture Gap

The fixture should include:

1. **Error handling via extension method on snapshot** — expect NO lint
2. **Error handling via inline `.hasError` check** — expect NO lint (existing)
3. **No error handling at all** — expect LINT (existing)
4. **Snapshot passed to a helper function** — expect NO lint
5. **Extension method called but return value ignored** — expect LINT

---

## Environment

- saropa_lints version: 15.2.4
- Dart SDK version: 3.13.1
- Triggering project: `contacts` (d:\src\contacts)
- Downstream suppression count: 56 sites
- Error-handling extension: `lib/utils/primitive/snapshot_utils.dart` (SnapExtension)
