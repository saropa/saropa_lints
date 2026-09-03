# PROPOSAL: Avoid Implementing Value Types

**Status: Open**

Created: 2026-09-02

## Summary

Flags a class that uses `implements` (rather than `extends`) on a known value type — a class whose identity is defined by its `==`/`hashCode` contract (e.g. `Equatable`, `String`, `int`, or any class already flagged as a value type by this package's Equatable rules).

## Existing Coverage

No existing rule in `lib/src/rules/` addresses `implements` vs `extends` for value types. `equatable_rules.dart` has rules about correct `Equatable` usage (`ExtendEquatableRule`, `PreferEquatableMixinRule`) but nothing about the `implements`-breaks-inheritance-of-`==` failure mode. No duplicate.

## Motivation

`implements` on a class does not inherit its implementation — only its interface (member signatures) are enforced. A class that `implements` a value type such as `Equatable` must redeclare `props`, `==`, and `hashCode` from scratch; if it doesn't (or gets it subtly wrong), instances silently fall back to identity equality (`==` compares references), breaking every collection, `Set`, `Map` key, or equality-based test that assumes value semantics. This is a common and hard-to-spot Dart footgun because the code compiles cleanly and only misbehaves at runtime.

## Detection / Behavior

Triggers when a class's `implements` clause names a type known to define value equality (the `equatable` package's `Equatable`/`EquatableMixin`, or any class in the same library that itself extends/mixes in one of those), and the implementing class does not also override `==` and `hashCode` itself.

```dart
// BAD
class UserId implements Equatable {
  UserId(this.value);
  final String value;
  // == and hashCode are NOT inherited — reference equality applies.
}

// GOOD
class UserId extends Equatable {
  const UserId(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}
```

## Quick Fix

Suggest changing `implements` to `extends` (or `with` for a mixin) when the target type's constructor is compatible. None — manual refactor required when the class already extends another type (Dart is single-inheritance), since the fix then involves composition or explicit `==`/`hashCode` overrides.

## Alternatives Considered

Broadening to all value types (not just Equatable-based ones) via `usesTypeResolution` checks against the SDK's own value types (`Duration`, `Uri`, etc.) was considered but deferred — the Equatable-based case is the dominant real-world occurrence in Flutter codebases and keeps the first version's false-positive rate low.
