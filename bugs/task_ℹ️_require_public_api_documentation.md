# Task: `require_public_api_documentation`

## Summary
- **Rule Name**: `require_public_api_documentation`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Documentation & Maintenance

## Problem Statement
Public API members — classes, methods, fields, typedefs, and extensions that are not prefixed with `_` — form the contract between a library and its consumers. When these members lack doc comments (`///`), the library is effectively undocumented. Developers consuming the library must read the source code to understand what each member does, what parameters it expects, and what it returns.

Beyond usability, documentation quality directly affects a package's score on pub.dev. The pub.dev scoring system deducts points for undocumented public API members, reducing the package's visibility and perceived quality.

The Dart style guide states: "DO document all public APIs." While this is an important guideline, it is not enforced by the default Dart linter. This rule fills that gap for codebases that use saropa_lints.

This rule targets Professional tier because it requires more discipline to satisfy than Recommended rules, and because large existing codebases may need significant work to become compliant. The INFO severity ensures teams can adopt it gradually.

## Description (from ROADMAP)
Flag any public declaration (classes, methods, getters, setters, fields, typedefs, extensions, enums, and enum values) that lacks a preceding doc comment (`///`), is not an override, and is not in a test or generated file.

## Trigger Conditions
The rule triggers when ANY of the following public declarations lacks a `///` doc comment:
1. `ClassDeclaration` — public class.
2. `MixinDeclaration` — public mixin.
3. `ExtensionDeclaration` — public extension.
4. `EnumDeclaration` — public enum.
5. `FunctionDeclaration` — public top-level function.
6. `MethodDeclaration` — public method, getter, or setter in a class.
7. `FieldDeclaration` — public field in a class.
8. `TopLevelVariableDeclaration` — public top-level variable.
9. `FunctionTypeAlias` / `GenericTypeAlias` — public typedef.
10. `EnumConstantDeclaration` — public enum value (optional, can be noisy).

It does NOT trigger for:
- Private members (name starts with `_`).
- Members with `@override` annotation (they inherit docs from the supertype).
- Files matching `**/*_test.dart` or `**/test/**`.
- Generated files (`.g.dart`, `.freezed.dart`, `.gr.dart`, `.pb.dart`, etc.).
- `part` files (their docs belong to the main file).
- Members with an inherited doc comment through `{@macro ...}` references.

## Implementation Approach

### AST Visitor
Use multiple registry hooks, one per declaration type:

```dart
context.registry.addClassDeclaration((node) {
  _checkDocComment(node.name, node.documentationComment, reporter);
});

context.registry.addMethodDeclaration((node) {
  if (_isOverride(node)) return;
  _checkDocComment(node.name, node.documentationComment, reporter);
});

context.registry.addFieldDeclaration((node) {
  if (node.isStatic && node.fields.variables.isEmpty) return;
  for (final variable in node.fields.variables) {
    _checkDocComment(variable.name, node.documentationComment, reporter);
  }
});

context.registry.addFunctionDeclaration((node) {
  _checkDocComment(node.name, node.documentationComment, reporter);
});

// ... etc for each declaration type
```

### Detection Logic

**Step 1 — Check if the member is public:**

```dart
bool _isPublic(String name) => !name.startsWith('_');
```

**Step 2 — Check for presence of a doc comment:**

```dart
void _checkDocComment(
  Token nameToken,
  Comment? docComment,
  ErrorReporter reporter,
) {
  if (!_isPublic(nameToken.lexeme)) return;
  if (docComment == null || docComment.tokens.isEmpty) {
    reporter.atToken(nameToken, code);
  }
}
```

**Step 3 — Detect overrides:**

```dart
bool _isOverride(MethodDeclaration node) {
  return node.metadata.any((annotation) {
    return annotation.name.name == 'override';
  });
}
```

**Step 4 — Skip generated and test files:**

Access the file path via `resolver.source.fullName` and apply path-based exclusion:

```dart
bool _shouldSkipFile(String path) {
  return path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.endsWith('.gr.dart') ||
      path.endsWith('.pb.dart') ||
      path.contains('/test/') ||
      path.contains('_test.dart');
}
```

**Step 5 — Minimum doc comment length (optional):**

A doc comment containing only `/// ` or `/// TODO` is technically present but useless. Optionally require the comment to have at least a minimum length (e.g., 20 non-whitespace characters). This prevents developers from satisfying the rule with empty or placeholder comments.

```dart
bool _hasSubstantiveDoc(Comment docComment) {
  final text = docComment.tokens.map((t) => t.lexeme).join(' ');
  final stripped = text.replaceAll(RegExp(r'///\s*'), '').trim();
  return stripped.length >= 20;
}
```

## Code Examples

### Bad (triggers rule)
```dart
// Public class with no doc comment
class UserRepository {
  // Public field with no doc comment
  final String baseUrl;

  // Constructor — technically not a MethodDeclaration but can be checked
  UserRepository(this.baseUrl);

  // Public method with no doc comment
  Future<User> findById(String id) async {
    // implementation
  }

  // Public getter with no doc comment
  bool get isConnected => _client.isConnected;
}

// Public typedef with no doc comment
typedef UserCallback = void Function(User user);
```

### Good (compliant)
```dart
/// Provides access to user data from the local and remote data sources.
///
/// Use [findById] to retrieve a user by their unique identifier.
/// Use [save] to persist changes to the data store.
class UserRepository {
  /// The base URL for the remote API endpoint.
  final String baseUrl;

  /// Creates a [UserRepository] that connects to the given [baseUrl].
  UserRepository(this.baseUrl);

  /// Retrieves the user with the given [id].
  ///
  /// Throws [NotFoundException] if no user exists with that [id].
  /// Throws [NetworkException] if the remote server is unreachable.
  Future<User> findById(String id) async {
    // implementation
  }

  /// Whether the repository currently has an active server connection.
  bool get isConnected => _client.isConnected;
}

/// Callback invoked when a [User] event occurs.
typedef UserCallback = void Function(User user);
```

## Edge Cases & False Positives
- **Override members**: Methods implementing interface contracts inherit their documentation from the abstract declaration. Flagging `@override` methods would be noisy and unhelpful. Always exclude members with `@override`.
- **Trivial getters and setters**: `bool get isLoading => _loading;` may be considered self-documenting. Whether to flag these is a policy decision. Consider a `minLength` threshold for the doc comment content.
- **Constructors**: Factory constructors are declaration sites but default/named constructors are less clearly "public API" in the documentation sense. The Dart `public_member_api_docs` rule from `flutter_lints` flags all public constructors. Follow the same approach for consistency.
- **Enum values**: Flagging every enum constant (`Status.active`, `Status.inactive`) for a doc comment would be very noisy. Consider making enum constant checking an opt-in via configuration.
- **`part` files**: Members in `part` files are semantically part of the main library. Their doc comments are valid in the part file. The rule should not double-report for members visible through both the main file and the part file.
- **Generated code exclusion**: Ensure all common generation suffixes are excluded. Protobuf generators produce `.pb.dart`, `.pbenum.dart`, `.pbjson.dart`. Riverpod code gen produces `.g.dart`. Freezed produces `.freezed.dart`. Route generators produce `.gr.dart`.
- **Overlap with flutter_lints**: Flutter projects using `flutter_lints` already have `public_member_api_docs` available. Document that this rule provides similar functionality and teams should not enable both simultaneously.
- **Test helper classes in non-test files**: Some projects place test utilities in `lib/test_helpers/`. These are technically public but not intended as public API. Consider whether to exclude paths containing `test_helpers` or `testing`.

## Unit Tests

### Should Trigger (violations)
```dart
// Missing doc comment on public class
class Cache { } // LINT

// Missing doc comment on public method
class Service {
  Future<void> refresh() async { } // LINT

  bool get ready => true; // LINT

  String name = ''; // LINT (public field)
}

// Missing doc comment on public top-level function
int computeHash(String input) => input.hashCode; // LINT

// Missing doc comment on public typedef
typedef Handler = void Function(String event); // LINT
```

### Should NOT Trigger (compliant)
```dart
/// A cache for frequently accessed values.
class Cache { }

class Service {
  // Private members — not flagged
  Future<void> _refresh() async { }
  bool _ready = false;

  // Override — not flagged (inherits docs)
  @override
  String toString() => 'Service';

  /// Checks whether the service is ready to handle requests.
  bool get isReady => _ready;
}

// Test file content — not flagged
void main() {
  test('cache stores values', () { });
}
```

## Quick Fix
Insert a `/// TODO: Add documentation.` placeholder above the declaration:

```dart
class _RequirePublicApiDocumentationFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add documentation comment',
        priority: 70,
      );

      changeBuilder.addDartFileEdit((builder) {
        final offset = node.offset;
        builder.addSimpleInsertion(
          offset,
          '/// TODO: Add documentation.\n',
        );
      });
    });
    // Repeat for other declaration types...
  }
}
```

The fix inserts a placeholder at the start of the declaration. It is intentionally minimal — the developer must fill in the actual content.

## Notes & Issues
- This rule is closely related to the existing `public_member_api_docs` rule in `package:lints` / `package:flutter_lints`. Ensure the documentation clearly states the overlap and recommends not enabling both.
- The rule will generate a very large number of warnings in undocumented codebases. Consider adding a `minPublicMemberCount` threshold or a `publicMembersOnly` flag to limit initial noise.
- Performance concern: This rule visits every declaration in every file. Ensure the implementation is fast — avoid any AST traversal beyond the immediate node. The `documentationComment` property on each declaration node is a direct access, not a traversal.
- Consider implementing `exclude` configuration allowing teams to exclude specific directories (e.g., `lib/src/internal/`) from the documentation requirement.
- The pub.dev scoring uses `dartdoc` to compute documentation coverage. Teams using this rule should also run `dart doc` and review the coverage report to understand how their score is affected.
