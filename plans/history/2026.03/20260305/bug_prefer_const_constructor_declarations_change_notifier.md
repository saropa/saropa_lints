# Bug: prefer_const_constructor_declarations on class extending ChangeNotifier

**Rule:** `prefer_const_constructor_declarations`  
**Status:** Open  
**Reporter:** radiance_vector_game

---

## Summary

The rule reports "Constructor could be const. Class has only final fields; add const to the constructor declaration" on a **private constructor** of a class that **extends ChangeNotifier**. In Dart, const constructors are not allowed for classes that extend a class other than Object (and that superclass must have a const constructor). ChangeNotifier does not have a const constructor, so the subclass constructor cannot be const.

## Expected behavior

Do not report when the enclosing class extends (directly or indirectly) a class that does not have a const constructor (e.g. ChangeNotifier, StatefulWidget, StatelessWidget with certain patterns).

## Actual behavior

In game/lib/screens/dev_test_screen.dart (lines 55–56) and game/lib/widgets/super_fab.dart (lines 321–322):

```dart
final class DevTestPanelParamsHolder extends ChangeNotifier {
  DevTestPanelParamsHolder._();
  // ...
}
```

Adding `const` yields: "Const constructor can't call a non-constant super constructor of 'ChangeNotifier'."

## Minimal reproduction

```dart
final class MyHolder extends ChangeNotifier {
  MyHolder._();
}
```

Rule suggests adding const; compiler then reports that the super constructor is not const.

## Suggested fix

When analyzing whether a constructor could be const, check the superclass chain. If any superclass has no const constructor (or the super invocation in the constructor is not const), do not report.

## Environment

- saropa_lints: 6.2.2
- Dart SDK: ^3.11.0
