# Bug: prefer_const_constructor_declarations suggests const for constructor with callback field

**Resolution (fixed):** prefer_const_constructor_declarations no longer suggests const when any constructor parameter has a function type (e.g. `void Function()`, `List<double> Function()`). Rule now checks for GenericFunctionType / function-type parameters and skips reporting.

**Status:** Fixed

**Rule:** `prefer_const_constructor_declarations`  
**Reporter:** radiance_vector_game (game/lib/screens/dev_test_tabs/color_filter_utils.dart)

---

## Summary

The rule reported "Constructor could be const..." on a class whose constructor had a required callback parameter. In Dart, const constructors require all initializers to be constant; a function type parameter is never const. So the suggestion was impossible to apply.

## Fix applied

When analyzing whether a constructor could be const, the rule now excludes constructors that have any parameter whose type is a function type (SimpleFormalParameter or FieldFormalParameter with GenericFunctionType). Combined with the other two fixes (superclass without const constructor, non-const initializers), the rule no longer reports in these cases.

## Environment (at report)

- saropa_lints: 6.2.2
- Dart SDK: ^3.11.0
