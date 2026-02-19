# Task: `prefer_sealed_for_state`

## Summary
- **Rule Name**: `prefer_sealed_for_state`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Design Patterns / §BLoC & Cubit

## Problem Statement
In BLoC, Cubit, and similar state management architectures, the state hierarchy follows a well-known pattern: an abstract base class (e.g., `AuthState`) with a fixed set of concrete subclasses (e.g., `AuthInitial`, `AuthLoading`, `AuthSuccess`, `AuthFailure`). This hierarchy is always closed — developers do not expect external code to add new state types.

Before Dart 3.0, developers had no choice but to use `abstract class`. With Dart 3.0's `sealed` keyword, these hierarchies should be converted to sealed classes to:

1. **Enable exhaustive switch expressions** in UI widgets that respond to state.
2. **Catch missing state handlers at compile time** — if a new state subclass is added, all `switch` expressions over the state immediately produce a compile error if the new case is not handled.
3. **Communicate closed-hierarchy intent** explicitly — sealed is self-documenting.
4. **Prevent accidental external subclassing** — state classes should never be subclassed from outside the bloc file.

This rule is more targeted than `prefer_sealed_classes` — it uses naming conventions to detect state/event/result hierarchies specifically, enabling it to fire with higher confidence even with fewer subclasses.

## Description (from ROADMAP)
An abstract class whose name ends in a state/event/result pattern suffix (`State`, `Event`, `Result`, `Status`, `Action`, `Intent`, `Effect`) and that has concrete subclasses in the same file should use the `sealed` modifier instead of `abstract`.

## Trigger Conditions
A `ClassDeclaration` where ALL of the following hold:
1. The class is abstract (`node.abstractKeyword != null`).
2. The class is NOT already sealed.
3. The class name ends with one of: `State`, `Event`, `Result`, `Status`, `Action`, `Intent`, `Effect`, `Failure`, `Success`, `Response`.
4. At least ONE concrete subclass of this class exists in the same file (lower threshold than `prefer_sealed_classes` due to naming convention confidence).
5. Dart SDK constraint is ≥ 3.0.0.

## Implementation Approach

### AST Visitor
```dart
context.registry.addCompilationUnit((unit) {
  _checkStateHierarchies(unit, reporter);
});
```

### Detection Logic
```dart
const _stateSuffixes = {
  'State', 'Event', 'Result', 'Status',
  'Action', 'Intent', 'Effect',
  'Failure', 'Success', 'Response',
};

void _checkStateHierarchies(
  CompilationUnit unit,
  ErrorReporter reporter,
) {
  final classes = unit.declarations.whereType<ClassDeclaration>().toList();

  // Build a set of class names that are subclassed within this file
  final subclassedNames = <String>{};
  for (final cls in classes) {
    final superName = cls.extendsClause?.superclass.name2.lexeme;
    if (superName != null) subclassedNames.add(superName);
  }

  for (final cls in classes) {
    if (cls.abstractKeyword == null) continue;
    if (cls.sealedKeyword != null) continue;

    final name = cls.name.lexeme;
    final matchesSuffix = _stateSuffixes.any(name.endsWith);
    if (!matchesSuffix) continue;

    // Must have at least one local subclass
    if (!subclassedNames.contains(name)) continue;

    reporter.atToken(cls.abstractKeyword!, code);
  }
}
```

## Code Examples

### Bad (triggers rule)
```dart
// LINT: AuthState with naming convention and local subclasses
// should be sealed to enable exhaustive switch in UI
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final User user;
  AuthSuccess(this.user);
}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

// In the UI, without sealed, this has no exhaustiveness check:
Widget buildFromState(AuthState state) => switch (state) {
  AuthInitial() => const SplashScreen(),
  AuthLoading() => const LoadingSpinner(),
  AuthSuccess(:final user) => HomeScreen(user: user),
  // AuthFailure missing — no compile error without sealed!
  _ => const ErrorScreen(),  // forced to add wildcard
};
```

### Good (compliant)
```dart
// Correct: sealed enables exhaustive switch
sealed class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthSuccess extends AuthState {
  final User user;
  AuthSuccess(this.user);
}
class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

// Now this is exhaustive — no wildcard needed, new states are caught:
Widget buildFromState(AuthState state) => switch (state) {
  AuthInitial() => const SplashScreen(),
  AuthLoading() => const LoadingSpinner(),
  AuthSuccess(:final user) => HomeScreen(user: user),
  AuthFailure(:final message) => ErrorScreen(message: message),
};

// Compliant: not a state hierarchy by naming convention
abstract class BaseDataSource {
  Future<List<Item>> fetchAll();
}

// Compliant: already sealed
sealed class LoginEvent {}
class EmailChanged extends LoginEvent { final String email; EmailChanged(this.email); }
class PasswordChanged extends LoginEvent { final String password; PasswordChanged(this.password); }
class FormSubmitted extends LoginEvent {}
```

## Edge Cases & False Positives
- **Naming false positives**: Not every class ending in `State` is a BLoC state. For example, `WidgetState` (from `State<T>` in Flutter) or `GameState` in a non-BLoC architecture. However, the rule only flags when the class IS abstract AND has local concrete subclasses — the combination of abstract + naming + subclasses is a strong signal.
- **`flutter_bloc` package not present**: The rule applies regardless of whether `flutter_bloc` is a dependency — the naming convention is used in many state management approaches (Riverpod notifiers, MobX stores, plain setState patterns).
- **Subclasses with abstract intermediate classes**: A hierarchy like `abstract AuthState > abstract AuthErrorState > ConcreteAuthError` — the root should be sealed; the intermediate abstract class may also be flagged separately.
- **Dart version**: Requires Dart 3.0+. Skip if SDK constraint is below `3.0.0`.
- **`equatable` package**: BLoC states often extend `Equatable`. This does not affect sealed conversion — `sealed class AuthState extends Equatable` is valid. The rule should still flag.
- **External package state classes**: If the abstract state class is imported from a package (not defined in the current file), it cannot be sealed by the consuming code. The rule only flags classes DEFINED in the current compilation unit.
- **Single subclass**: Unlike `prefer_sealed_classes` (which requires 2+), this rule fires with 1+ subclass because the naming convention provides high confidence that the hierarchy is intentionally closed. Sealed with one subclass still prevents external extension.
- **Classes in `test/` files**: Test files often create mock state subclasses for testing. These should not trigger the rule — they are test infrastructure, not production state hierarchies.

## Unit Tests

### Should Trigger (violations)
```dart
// BLoC pattern — all in one file
abstract class CartEvent {}
class AddItem extends CartEvent { final String itemId; AddItem(this.itemId); }
class RemoveItem extends CartEvent { final String itemId; RemoveItem(this.itemId); }
class ClearCart extends CartEvent {}
// LINT: CartEvent should be sealed
```

```dart
// Riverpod-style result
abstract class FetchResult {}
class FetchLoading extends FetchResult {}
class FetchData extends FetchResult { final List<String> items; FetchData(this.items); }
class FetchError extends FetchResult { final Object error; FetchError(this.error); }
// LINT: FetchResult should be sealed
```

### Should NOT Trigger (compliant)
```dart
// Already sealed — no lint
sealed class PaymentStatus {}
class Pending extends PaymentStatus {}
class Completed extends PaymentStatus {}
class Failed extends PaymentStatus {}

// No local subclasses — not flagged
abstract class NetworkState {}
// (subclasses are in other files)

// Name suffix doesn't match — not flagged by this rule
abstract class BaseProcessor {
  void process();
}
class DefaultProcessor extends BaseProcessor {
  @override void process() {}
}
```

## Quick Fix
**"Add sealed modifier to state hierarchy"** — Replace `abstract class XxxState` with `sealed class XxxState`. No changes required to the subclass declarations.

Priority: 75 (higher priority than general `prefer_sealed_classes` because state hierarchies have the clearest benefit from exhaustiveness checking).

## Notes & Issues
- This rule pairs well with `require_exhaustive_sealed_switch` — first convert to sealed (this rule), then ensure all switches are exhaustive (the other rule).
- The suffix list (`State`, `Event`, `Result`, etc.) can be made configurable via `analysis_options.yaml` for teams using different naming conventions.
- The rule should also check for `abstract class` names ending in suffixes when used with the `equatable` package — BLoC states that extend `Equatable` are the most common real-world target.
- Consider adding `Bloc`, `Cubit`, `Notifier` as suffix triggers if a saropa_lints rule already detects BLoC usage — cross-rule context would improve precision.
- Distinct from `prefer_sealed_classes` in that: (1) it uses naming convention for detection, (2) it fires with only 1 subclass, (3) it is specifically motivated by state management patterns rather than general OOP design.
