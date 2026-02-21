# Task: `avoid_deprecated_usage`

## Summary
- **Rule Name**: `avoid_deprecated_usage`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.61 Code Quality Rules
- **Priority**: ⭐ Next in line for implementation

## Problem Statement

Dart's built-in `deprecated_member_use` lint already flags deprecated usage, but it fires at INFO severity and is often suppressed. This rule provides a WARNING-level signal for deprecated usage, with additional context: it can include the migration guidance from the `@Deprecated` message, and it can be configured to escalate to ERROR for APIs that have been deprecated for more than a certain number of releases.

The key value-add over the built-in rule is:
1. Higher severity (WARNING vs INFO) — visible in CI output
2. Configurable escalation for long-standing deprecations
3. Better correction message showing the migration path from the deprecation message

## Description (from ROADMAP)

> Warn when using deprecated APIs, classes, or methods.

## Trigger Conditions

Trigger when:
1. A `MethodInvocation`, `PropertyAccess`, `InstanceCreationExpression`, or any element access resolves to an element annotated `@Deprecated(...)` or `@deprecated`
2. The deprecation annotation does not belong to the same package (i.e., avoid false positives where you're using your own deprecated APIs during a migration)

## Implementation Approach

### Overlap with Built-in Rule
**IMPORTANT**: The Dart SDK's `deprecated_member_use` already does exactly this. Before implementing, determine what differentiated value this rule adds. Options:
1. Higher severity (WARNING instead of INFO/hint) — this is the primary value
2. Configurable ignore-own-package behavior
3. Cross-package deprecation escalation

### AST Visitor Pattern

```dart
context.registry.addSimpleIdentifier((node) {
  final element = node.staticElement;
  if (element == null) return;
  final deprecation = _getDeprecationAnnotation(element);
  if (deprecation == null) return;
  if (_isSamePackage(element, resolver)) return;
  reporter.atNode(node, code);
});
```

`_getDeprecationAnnotation`: walks `element.metadata` looking for `@Deprecated` or `@deprecated` annotation.
`_isSamePackage`: compares the element's library URI prefix (`package:saropa_lints/...`) to the current file's package.

### Problem Message
Extract the deprecation message from the annotation:
```dart
final message = deprecationAnnotation.constantValue?.getField('message')?.toStringValue();
```
Include it in `problemMessage`: `"[avoid_deprecated_usage] Using deprecated ${element.displayName}. ${message ?? 'No migration guidance provided.'}"`.

### Configurability (Phase 2)
Allow `analysis_options.yaml`:
```yaml
custom_lint:
  rules:
    avoid_deprecated_usage:
      ignore_own_package: true  # default: true
      escalate_severity: ERROR  # for very old deprecations
```

## Code Examples

### Bad (Should trigger)
```dart
// Using a deprecated method from an external package
final text = someWidget.textTheme.headline1;  // deprecated in Material3

// Using a deprecated class
final client = HttpClient();  // if deprecated

// Using @deprecated annotation (not @Deprecated)
@deprecated
void oldMethod() {}

void caller() {
  oldMethod();  // ← trigger
}
```

### Good (Should NOT trigger)
```dart
// Using the replacement API
final text = someWidget.textTheme.displayLarge;  // new name

// Deprecating your own API while migrating (own package)
@Deprecated('Use newMethod instead')
void oldMethod() {}

// Calling your own deprecated method during migration transition
// (if ignore_own_package: true is configured)
oldMethod();  // in same package

// Test file testing deprecated behavior
test('deprecated method still works', () {
  // ignore: deprecated_member_use
  oldMethod();
});
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Using own package's deprecated API | **Suppress** by default (`ignore_own_package: true`) | This is normal during a migration |
| `// ignore: avoid_deprecated_usage` inline | **Suppress** | Standard ignore comment handling |
| `// ignore: deprecated_member_use` inline | **Also suppress** — developer already acknowledged deprecation | Check for either ignore comment |
| Overriding a deprecated method | **Suppress** — must override to maintain compatibility | Check if node is a method declaration with `@override` |
| Implementing a deprecated interface | **Trigger** at class declaration level, not each member | Or suppress — TBD |
| Import of a deprecated library | **Trigger** on the import statement | |
| Deprecated constant used in annotation | **Trigger** — annotations are still usage | |
| Generated code (`.g.dart`, `.freezed.dart`) | **Suppress** — generator may use deprecated APIs temporarily | Check generated file status |
| Test files | **Keep triggering** — tests should be updated too | Unless configured otherwise |
| `@Deprecated('')` with empty string message | **Trigger** but note "No migration guidance" | |
| Flutter internal deprecations (using `@Deprecated` from flutter itself) | **Trigger** — these are the most important ones to catch | |

## Unit Tests

### Violations
1. Call to method annotated `@Deprecated('Use X instead')` from different package → 1 lint with migration message
2. Access to property annotated `@deprecated` → 1 lint
3. Construction of class annotated `@Deprecated(...)` → 1 lint
4. Call to own package deprecated method with `ignore_own_package: false` → 1 lint

### Non-Violations
1. Call to non-deprecated method → no lint
2. Call to own deprecated method (default `ignore_own_package: true`) → no lint
3. Generated file (`.g.dart`) → no lint
4. Method declaration that IS deprecated (not calling it) → no lint
5. `// ignore: deprecated_member_use` present → no lint
6. Override of deprecated method → no lint

## Quick Fix

Offer a quick fix when the `@Deprecated` message contains a clear replacement pattern like "Use `newMethod` instead":

```dart
// Parse message for "Use X instead" / "Replace with X" patterns
// Offer: "Replace with X" code action
```

This is Phase 2 — string parsing of deprecation messages is fragile.

## Notes & Issues

1. **CRITICAL**: Dart SDK already has `deprecated_member_use` at INFO/hint severity. The primary value of this rule is WARNING severity. Before implementing, verify that the built-in rule cannot simply be configured to WARNING — if it can be escalated via `analysis_options.yaml`, this rule is redundant.
2. **Check for `deprecated_member_use_from_same_package`** — the SDK has a separate lint for same-package usage. This means we need to handle both cases.
3. **The `@deprecated` (lowercase)** is a legacy annotation. Both `@Deprecated('message')` and `@deprecated` must be detected.
4. **Performance**: `addSimpleIdentifier` fires on EVERY identifier in every file. This is potentially very expensive. Consider using more specific visitors (`addMethodInvocation`, `addPropertyAccess`, etc.) and combining them, or using `addMemberDeclaration` to build a set of deprecated members once per class.
5. **Check CHANGELOG** — this rule may already be partially implemented or a similar rule exists.
