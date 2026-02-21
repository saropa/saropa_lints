# Dart SDK 3.7.2

## 3.7.2

**Released on:** 2025-03-12

This is a patch release that:

 - Fixes a bug in dart2wasm that imports a `js-string` builtin function with a
   non-nullable parameter type where it must use a nullable one (issue [#59899]).

[#59899]: https://github.com/dart-lang/sdk/issues/59899
