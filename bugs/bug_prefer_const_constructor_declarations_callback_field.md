# Bug: prefer_const_constructor_declarations suggests const for constructor with callback field

**Rule:** `prefer_const_constructor_declarations`  
**Status:** Open  
**Reporter:** radiance_vector_game (game/lib/screens/dev_test_tabs/color_filter_utils.dart)

---

## Summary

The rule reports "Constructor could be const. Class has only final fields; add const to the constructor declaration" on a class whose constructor has a **required callback parameter** (e.g. `List<double> Function() onBuildMatrix`). In Dart, const constructors require all initializers to be constant expressions; a function type parameter is never const. So the constructor **cannot** be const, and the suggestion is impossible to apply.

## Expected behavior

Do not report when the constructor has one or more parameters whose type is a function type (e.g. `void Function()`, `List<double> Function()`, or any typedef/function type), because such parameters cannot be constant and the constructor cannot be const.

## Actual behavior

The rule reports at the constructor of `DynamicMatrixFilterDef` (color_filter_utils.dart, lines 264–267):

```dart
class DynamicMatrixFilterDef extends ColorFilterDef {
  DynamicMatrixFilterDef({
    required this.name,
    required this.onBuildMatrix,
  });

  @override
  final String name;

  /// Returns full-strength matrix (20 values). Intensity applied by lerp in UI.
  final List<double> Function() onBuildMatrix;
  // ...
}
```

Adding `const` to the constructor yields a compile error: the initializer list uses `this.onBuildMatrix`, which is not a constant expression.

## Minimal reproduction

```dart
class Foo {
  Foo({required this.callback});
  final void Function() callback;
}
```

Rule reports: "Constructor could be const. Class has only final fields; add const to the constructor declaration." Adding `const` to `Foo` causes: "Const constructor can't have a non-const initializer for 'callback'."

## Suggested fix

When analyzing whether a constructor "could be const", exclude constructors that initialize any final field from a parameter (or other expression) whose static type is a function type (including `Function`, `void Function()`, `R Function(...)`, and typedefs that refer to function types). Alternatively, require that **all** initializer expressions be constant; today the rule appears to only check that the class has only final fields, without checking that the initializers are const-capable.

## Environment

- saropa_lints: 6.2.2
- Dart SDK: ^3.11.0
