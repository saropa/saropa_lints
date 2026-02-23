# `require_dispose_pattern` false positive: `const` options class with borrowed `FocusNode?` reference

## Status: RESOLVED

## Summary

The `require_dispose_pattern` rule (v4) fires on `CommonTextFieldOptions`, a `const`-constructible immutable configuration class that holds a `FocusNode?` field received from outside. The class does not **own** or **create** the `FocusNode` — it merely holds a borrowed reference so a sibling widget can request focus on submit. The actual owner (a parent `State`) is responsible for disposing it.

The rule cannot distinguish between a class that **owns** a disposable resource (and must dispose it) versus a class that **borrows** a reference (and must NOT dispose it — doing so would be a bug).

## Diagnostic Output

```
resource: /D:/src/contacts/lib/components/primitive/text/common_text_field.dart
owner:    _generated_diagnostic_collection_name_#2
code:     require_dispose_pattern
severity: 4 (warning)
message:  [require_dispose_pattern] Class has StreamController, AnimationController,
          or other disposable fields but no cleanup method. These controllers leak
          memory and can crash when accessed after disposal. {v4}
          Add dispose() or close() method to clean up resources. Profile the affected
          code path to confirm the improvement under realistic workloads.
lines:    15–135 (entire CommonTextFieldOptions class)
```

## Affected Source

File: `lib/components/primitive/text/common_text_field.dart` lines 15–135

```dart
/// A configuration class for [CommonTextField] to customize its appearance and behavior.
class CommonTextFieldOptions {
  const CommonTextFieldOptions({
    // ... 20+ fields: decoration, style, labelText, hintText, maxLines, etc.
    this.nextFieldFocusNode,       // ← triggers the rule
  });

  /// The `FocusNode` of the next field to focus on when this field is submitted.
  final FocusNode? nextFieldFocusNode;  // ← borrowed, not owned

  // ... style helper methods (buildStyle, textStyle, labelStyle, etc.)
}
```

Key characteristics of this class:

| Property | Value | Implication |
|----------|-------|-------------|
| Constructor | `const` | Immutable data, no lifecycle |
| All fields | `final` | No mutation, no resource creation |
| `FocusNode?` | Nullable, passed in | Borrowed reference, not owned |
| Superclass | `Object` (none) | Not a `State`, `Widget`, or lifecycle-managing class |
| Methods | Pure style builders | No side effects, no resource allocation |

The `FocusNode` is consumed in the sibling `_CommonTextFieldState.build()` at line 327–328:

```dart
if (widget.options.nextFieldFocusNode != null) {
  FocusScope.of(context).requestFocus(widget.options.nextFieldFocusNode);
}
```

It is a read-only reference used to shift keyboard focus. The options class never creates, mutates, or disposes it.

## Root Cause

The rule at `performance_rules.dart` lines 2582–2639 uses a simple type-name check against field declarations:

```dart
static const Set<String> _disposableTypes = <String>{
  'StreamController',
  'AnimationController',
  'TextEditingController',
  'ScrollController',
  'TabController',
  'FocusNode',         // ← matches the field type
  'Timer',
};

// ...
for (final ClassMember member in node.members) {
  if (member is FieldDeclaration) {
    final String? typeName = member.fields.type?.toSource();
    if (typeName != null) {
      for (final String disposable in _disposableTypes) {
        if (typeName.contains(disposable)) {
          hasDisposable = true;      // ← triggered by FocusNode? field
          break;
        }
      }
    }
  }
}
```

The rule already skips `State`, `StatefulWidget`, and `StatelessWidget` subclasses (lines 2603–2611), but it has **no exclusion for immutable configuration / options / data classes** that receive disposable references as constructor parameters without owning them.

## Why This Is a False Positive

The rule's premise is: "If you hold a disposable, you must dispose it." But this is only true when the class **creates** or **takes ownership** of the resource. In the "options pattern" (widespread in Flutter and this codebase), the class is a passive data bag:

1. **`const` constructor** — The class cannot allocate resources. It is instantiated inline at call sites:
   ```dart
   CommonTextField(
     textController: _controller,
     options: CommonTextFieldOptions(
       nextFieldFocusNode: _nextFocusNode,  // owned by the State, not by options
     ),
   )
   ```

2. **No lifecycle** — The class has no `initState`, `dispose`, `close`, or any lifecycle callback. It is created and discarded with the widget tree.

3. **Disposing would be a bug** — If `CommonTextFieldOptions` disposed the `FocusNode`, it would destroy a resource owned by the parent `State`, causing a crash when the `State` later tries to use or dispose it.

## Scope of Impact

This pattern is common in Flutter codebases. Any "options" or "configuration" class that accepts a `FocusNode`, `ScrollController`, `TextEditingController`, or `AnimationController` as a parameter (for reference, not ownership) will trigger this false positive. Examples:

- Options classes that accept a `FocusNode?` for focus-chaining
- Configuration objects that accept a `ScrollController?` for scroll coordination
- Builder parameter classes that accept a `TextEditingController?` to read text

## Recommended Fix: Exclude Non-Owning Classes

### Approach A: Skip `const`-constructible classes (simplest)

If a class has a `const` constructor, it cannot allocate resources — it can only hold references passed in by the caller. These references are borrowed, not owned.

```dart
// In the addClassDeclaration callback, after the extends check:

// Skip const-constructible classes — they hold borrowed references,
// not owned resources, so adding dispose() would be incorrect.
final bool hasConstConstructor = node.members.any(
  (ClassMember m) => m is ConstructorDeclaration && m.constKeyword != null,
);
if (hasConstConstructor) return;
```

### Approach B: Skip classes with no resource-creating initializers (more precise)

Only flag a class when a disposable field is **created** inside the class (via initializer or constructor body), not merely declared as a parameter:

```dart
// Instead of checking just the type name, check how the field is initialized.
// A field that is only assigned via constructor parameter is borrowed.
// A field initialized with `= StreamController()` or `= AnimationController(...)` is owned.
bool isFieldOwned(FieldDeclaration field) {
  for (final VariableDeclaration variable in field.fields.variables) {
    final Expression? initializer = variable.initializer;
    if (initializer != null) {
      // Field is initialized inline — class owns it
      return true;
    }
  }
  // Field is set via constructor parameter — class borrows it
  return false;
}
```

Then only set `hasDisposable = true` when `isFieldOwned(member)` returns `true`.

### Approach C: Skip when the class name matches common non-owning patterns

A lighter heuristic as a supplement to A or B:

```dart
// Common suffixes for non-owning data classes
static const List<String> _nonOwningClassSuffixes = [
  'Options',
  'Config',
  'Configuration',
  'Settings',
  'Params',
  'Props',
  'Data',
  'Args',
  'Descriptor',
];

final String className = node.name.lexeme;
final bool isLikelyNonOwning = _nonOwningClassSuffixes.any(
  (String suffix) => className.endsWith(suffix),
);
if (isLikelyNonOwning) return;
```

**Recommendation:** Approach A is the most reliable and least likely to produce false negatives. A `const` constructor is a strong, machine-verifiable signal that the class cannot own resources. Approach B is more precise but more complex. Approach C is a heuristic and should only supplement, not replace, A or B.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Const options class with borrowed FocusNode — not an owner.
class _good804_TextFieldOptions {
  const _good804_TextFieldOptions({this.nextFieldFocusNode});
  final FocusNode? nextFieldFocusNode;
}

// GOOD: Const config class with borrowed ScrollController.
class _good805_ScrollConfig {
  const _good805_ScrollConfig({this.scrollController});
  final ScrollController? scrollController;
}

// GOOD: Const config class with borrowed TextEditingController.
class _good806_InputConfig {
  const _good806_InputConfig({required this.controller});
  final TextEditingController controller;
}

// GOOD: Non-const options class with no initializer (still borrowed).
class _good807_AnimationOptions {
  _good807_AnimationOptions({this.animationController});
  final AnimationController? animationController;
}

// GOOD: Immutable class with multiple borrowed disposable fields.
class _good808_MultiFieldOptions {
  const _good808_MultiFieldOptions({
    this.focusNode,
    this.scrollController,
    this.textController,
  });
  final FocusNode? focusNode;
  final ScrollController? scrollController;
  final TextEditingController? textController;
}
```

### Existing BAD case (should still trigger)

```dart
// BAD: Class creates and owns a StreamController — must dispose it.
// expect_lint: require_dispose_pattern
class _bad803_MyManager {
  final _controller = StreamController<int>();
  // Missing close!
}
```

### New BAD cases (should still trigger — ownership via initializer)

```dart
// BAD: Class owns a FocusNode via field initializer — must dispose it.
// expect_lint: require_dispose_pattern
class _bad804_FocusOwner {
  final FocusNode _focusNode = FocusNode();
  // Missing dispose!
}

// BAD: Class owns a TextEditingController via field initializer.
// expect_lint: require_dispose_pattern
class _bad805_ControllerOwner {
  final TextEditingController _controller = TextEditingController();
  // Missing dispose!
}
```

## Environment

- **saropa_lints version:** 4.14.5 (rule version v4)
- **Dart SDK:** 3.x
- **Trigger project:** `D:\src\contacts`
- **Trigger file:** `lib/components/primitive/text/common_text_field.dart:15–135`
- **Trigger class:** `CommonTextFieldOptions`
- **Trigger field:** `final FocusNode? nextFieldFocusNode` (line 99)
- **Matched type:** `FocusNode` in `_disposableTypes` set

## Severity

Medium — warning-level diagnostic. The false positive recommends adding a `dispose()` method to a `const` class, which would be architecturally wrong (disposing borrowed resources). If a developer follows the lint's advice, it could introduce a double-dispose crash. The pattern (options/config classes holding borrowed references) is pervasive in Flutter codebases.
