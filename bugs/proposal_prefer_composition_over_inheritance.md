# PROPOSAL: Prefer Composition Over Inheritance

**Status: Open**

Created: 2026-09-02

## Summary

Flags a concrete class that `extends` another concrete (non-abstract) class which itself extends a concrete class — an inheritance chain three or more levels deep — as a candidate for refactoring to composition.

## Existing Coverage

No existing rule measures inheritance depth. `AvoidReferencingSubclassesRule` (`lib/src/rules/core/class_constructor_rules.dart:2876`) addresses a different concern (a base class referencing its own subclasses, a layering violation), not chain depth. No duplicate.

## Motivation

Deep concrete-class inheritance chains couple every level to the implementation details of the levels above it: a change to a grandparent class can silently break a grandchild through inherited state or overridden-method interactions the author never sees together. This is the classic "fragile base class" problem. Composition — depending on an interface and injecting/delegating to an implementation — keeps each class's contract explicit and testable in isolation, and is the widely recommended default in modern Dart/Flutter architecture guidance.

## Detection / Behavior

Triggers when a class's `extends` chain (walking up through resolved supertypes) passes through three or more non-abstract, non-widget-framework classes before reaching `Object` or an SDK/framework root (Flutter's `StatelessWidget`/`StatefulWidget`/`State`/`Widget` chains are excluded, since that inheritance is framework-mandated, not a design choice).

```dart
// BAD
class Animal { void makeSound() {} }
class Mammal extends Animal { void nurse() {} }
class Dog extends Mammal { void fetch() {} } // 3rd concrete level

// GOOD
abstract class SoundMaker { void makeSound(); }
abstract class Nurser { void nurse(); }

class Dog implements SoundMaker, Nurser {
  Dog(this._sound, this._nursing);
  final SoundBehavior _sound;
  final NursingBehavior _nursing;

  @override
  void makeSound() => _sound.play();

  @override
  void nurse() => _nursing.feed();
}
```

## Quick Fix

None — manual refactor required. Converting an inheritance chain to composition is an architectural decision (which behaviors become injected dependencies, what the resulting interfaces look like) that cannot be automated safely.

## Alternatives Considered

A stricter two-level threshold was considered but rejected as too aggressive — two-level hierarchies (a single intermediate abstract/base class) are extremely common and idiomatic in Dart; the smell becomes clear only from three concrete levels onward.
