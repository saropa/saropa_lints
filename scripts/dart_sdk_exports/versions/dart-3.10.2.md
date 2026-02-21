# Dart SDK 3.10.2

## 3.10.2

**Released on:** 2025-11-25

This is a patch release that:

- Fixes an issue with code completion for argument lists in a dot shorthand
  invocation, as well as an issue with renaming dot shorthands.
  (issue [dart-lang/sdk#61969])
- Fixes an issue in dart2wasm that causes the compiler to crash for switch
  statements that contain int cases and a null case.
  (issue [dart-lang/sdk#62022])
- Fixes an issue with renaming fields/parameters on dot shorthand
  constructor invocations.
  (issue [dart-lang/sdk#62036])

[dart-lang/sdk#61969]: https://github.com/dart-lang/sdk/issues/61969
[dart-lang/sdk#62022]: https://github.com/dart-lang/sdk/issues/62022
[dart-lang/sdk#62036]: https://github.com/dart-lang/sdk/issues/62036
