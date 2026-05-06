# Bug: prefer_const_constructor_declarations suggests const when initializers are not const-capable

**Resolution (fixed):** prefer_const_constructor_declarations no longer suggests const when the constructor initializer list or super arguments use non-const expressions (method calls, non-const constructor calls, binary/conditional/prefix/postfix/await). _constructorHasNonConstInitializers and _expressionIsNonConst implement a conservative check.

**Status:** Fixed

**Rule:** `prefer_const_constructor_declarations`  
**Reporter:** radiance_vector_game

---

## Summary

The rule reported "Constructor could be const..." on constructors whose initializer list used non-constant expressions (e.g. method calls, non-const constructor calls, super with non-const argument). Adding const caused compile errors. The rule had only checked that the class has only final fields.

## Fix applied

_constructorHasNonConstInitializers walks node.initializers; for ConstructorFieldInitializer and SuperConstructorInvocation arguments, _expressionIsNonConst returns true for MethodInvocation, InstanceCreationExpression, BinaryExpression, ConditionalExpression, PrefixExpression, PostfixExpression, AwaitExpression. Reporting is skipped when any such expression is present.

## Environment (at report)

- saropa_lints: 6.2.2
- Dart SDK: ^3.11.0
