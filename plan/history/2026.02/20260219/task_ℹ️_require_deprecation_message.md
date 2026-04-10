# Task: `require_deprecation_message`

## Summary
- **Rule Name**: `require_deprecation_message`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Documentation & Maintenance

## Problem Statement
Dart provides two ways to mark code as deprecated:
1. `@deprecated` — a top-level constant annotation with no message. Tells users "this is deprecated" but nothing else.
2. `@Deprecated('reason and migration path')` — a class constructor that accepts a string message explaining what is deprecated, why, and what to use instead.

The bare `@deprecated` form is almost always the wrong choice in non-trivial codebases. When a developer encounters a deprecation warning, their first question is "what do I use instead?" Without a message, they must hunt through commit history, issue trackers, or documentation to find the answer. This wastes time and discourages migration.

The `@Deprecated('...')` form with a meaningful message (including the planned removal version and migration instructions) is far more helpful and costs almost nothing to write. This rule encourages the informative form.

This problem is especially acute in packages published to pub.dev, where library consumers may have no access to the internal context of why something was deprecated. A clear deprecation message is a basic courtesy to API consumers.

## Description (from ROADMAP)
Flag uses of the bare `@deprecated` annotation constant and require the `@Deprecated('message')` constructor form instead. The message should ideally include migration instructions and a planned removal version.

## Trigger Conditions
The rule triggers when:
1. An `Annotation` node is found whose name resolves to `deprecated` (the lowercase built-in constant).
2. The annotation has no arguments (confirming it is the constant form, not the class form).

It does NOT trigger when:
- The annotation is `@Deprecated(...)` (uppercase D, with arguments).
- The annotation is not related to deprecation at all.
- The code is in a generated file.

## Implementation Approach

### AST Visitor
```dart
context.registry.addAnnotation((node) {
  _checkDeprecationAnnotation(node, reporter);
});
```

### Detection Logic

**Step 1 — Identify the annotation:**

```dart
void _checkDeprecationAnnotation(
  Annotation node,
  ErrorReporter reporter,
) {
  final name = node.name.name;

  // Only interested in 'deprecated' (lowercase) — the constant form
  if (name != 'deprecated') return;

  // Confirm it has no arguments (constant form, not class instantiation)
  if (node.arguments != null) return;

  reporter.atNode(node, code);
}
```

**Step 2 — Verify it resolves to dart:core's deprecated:**

To avoid false positives where a user-defined `deprecated` annotation coincidentally has the same name:

```dart
final element = node.element;
if (element == null) return;

// Check the element's library URI
final library = element.library;
if (library?.isDartCore != true) return;
```

This confirms the `deprecated` being used is `dart:core`'s built-in constant.

**Step 3 — Report:**

```dart
reporter.atNode(node, code);
```

Report on the entire annotation node (from `@` to the name) for visibility.

## Code Examples

### Bad (triggers rule)
```dart
// Bare @deprecated with no message
@deprecated
void fetchUserData(int id) {
  // old implementation
}

class UserRepository {
  @deprecated
  static UserRepository? instance;

  @deprecated
  Future<void> refresh() async { }
}

// In a mixin
mixin LegacyCache {
  @deprecated
  void clearAll() { }
}
```

### Good (compliant)
```dart
// @Deprecated with a clear migration message
@Deprecated(
  'Use fetchUser(userId) instead. '
  'This method will be removed in v3.0.0.',
)
void fetchUserData(int id) {
  // old implementation
}

class UserRepository {
  @Deprecated(
    'Use UserRepository.create() factory instead. '
    'Direct singleton access will be removed in v4.0.0.',
  )
  static UserRepository? instance;

  @Deprecated(
    'Use reload() instead, which handles error cases correctly. '
    'Will be removed in v3.0.0.',
  )
  Future<void> refresh() async { }
}
```

## Edge Cases & False Positives
- **User-defined `deprecated` annotation**: A developer might define their own `@deprecated` annotation in a custom annotations package. The rule should verify the element resolves to `dart:core` before reporting. Without this check, custom annotations with the same name would be incorrectly flagged.
- **Generated code**: Code generators sometimes emit `@deprecated` without a message when mirroring deprecated status from an external source. Suppress for generated files (`.g.dart`, `.freezed.dart`, `.pb.dart` for protobuf, etc.).
- **Test files**: Test helper methods marked `@deprecated` (often as a reminder not to use them in new tests) may not need a full migration message. Consider whether test files should be excluded or treated differently.
- **The annotation itself is already reported by the analyzer**: The Dart analyzer does not flag bare `@deprecated` without a message — it only issues a warning when the deprecated item is _used_. This rule fills a different gap: it flags the _declaration_ of the deprecated item, not its usage.
- **Meta package**: The `package:meta` package provides `@alwaysThrows`, `@required`, etc. Ensure those are not confused with `@deprecated`. The name check for `deprecated` (lowercase) and the `dart:core` library check should be sufficient.
- **Old code in legacy libraries**: Very old Dart code uses `@deprecated` extensively. The rule would flag every such declaration in a legacy codebase. Teams adopting this rule in existing codebases should plan for a migration phase.

## Unit Tests

### Should Trigger (violations)
```dart
// Bare @deprecated without message
@deprecated
void oldMethod() { } // LINT

class OldClass {
  @deprecated
  String get oldValue => ''; // LINT

  @deprecated
  void oldAction() { } // LINT
}

@deprecated
typedef OldCallback = void Function(String); // LINT
```

### Should NOT Trigger (compliant)
```dart
// @Deprecated with message — correct form
@Deprecated('Use newMethod() instead. Removed in v3.0.0.')
void oldMethod() { }

@Deprecated(
  'Use NewClass instead. '
  'OldClass will be removed in the next major release.',
)
class OldClass { }

// Not a deprecation annotation at all
@override
void build() { }

@immutable
class Config { }
```

## Quick Fix
Provide a quick fix that replaces `@deprecated` with `@Deprecated('TODO: add migration instructions')`:

```dart
class _RequireDeprecationMessageFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addAnnotation((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.name.name != 'deprecated') return;

      final changeBuilder = reporter.createChangeBuilder(
        message: "Replace '@deprecated' with '@Deprecated' and add a message",
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          "@Deprecated('TODO: Use <alternative> instead. Will be removed in <version>.')",
        );
      });
    });
  }
}
```

This quick fix gives the developer a starting point with clear placeholders to fill in.

## Notes & Issues
- This rule complements `require_public_api_documentation` (file 6) — both rules encourage better documentation hygiene for public APIs.
- The `@Deprecated` message quality cannot be validated automatically (a message of `'deprecated'` would satisfy this rule technically but is unhelpful). Consider a secondary check: if the message is shorter than some minimum length (e.g., 20 characters), emit a lower-severity note. This is optional and may be too opinionated.
- The Dart team's own style guide says: "AVOID using @deprecated unless you're certain the feature won't be needed." When it is used, a message is effectively mandatory for good citizenship.
- Track whether the existing `deprecated_member_use` warning in the Dart analyzer already covers the usage site. This rule covers the declaration site — they are complementary.
- The quick fix message placeholder `TODO: Use <alternative> instead` uses angle brackets as template markers, not Dart generics. Ensure the replacement string is valid in a Dart string literal.
