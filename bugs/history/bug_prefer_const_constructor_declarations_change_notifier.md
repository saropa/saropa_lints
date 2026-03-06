# Bug: prefer_const_constructor_declarations on class extending ChangeNotifier

**Resolution (fixed):** prefer_const_constructor_declarations no longer suggests const when the class extends a superclass that has no const constructor (e.g. ChangeNotifier). Rule resolves superclass type and checks constructors.any((c) => c.isConst).

**Status:** Fixed

**Rule:** `prefer_const_constructor_declarations`  
**Reporter:** radiance_vector_game

---

## Summary

The rule reported on a private constructor of a class that extends ChangeNotifier. ChangeNotifier does not have a const constructor, so the subclass constructor cannot be const. Adding const yielded "Const constructor can't call a non-constant super constructor of 'ChangeNotifier'."

## Fix applied

_superclassLacksConstConstructor(ClassDeclaration): if the class has an extends clause, resolve the superclass type's element (InterfaceElement) and return true when no constructor is const. Reporting is skipped in that case.

## Environment (at report)

- saropa_lints: 6.2.2
- Dart SDK: ^3.11.0
