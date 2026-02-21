# Dart SDK 3.10.5

## 3.10.5

**Released on:** 2025-12-16

This is a patch release that:

- Fixes several issues with elements that are deprecated with one of the new
  "deprecated functionality" annotations, like `@Deprecated.implement`. This
  fix directs IDEs to not display such elements (like the `RegExp` class) as
  fully deprecated (for example, with struck-through text). (issue
  [dart-lang/sdk#62013])
- Fixes code completion for dot shorthands in enum constant arguments. (issue
  [dart-lang/sdk#62168])
- Fixes code completion for dot shorthands and the `!=` operator. (issue
  [dart-lang/sdk#62216])

[dart-lang/sdk#62013]: https://github.com/dart-lang/sdk/issues/62013
[dart-lang/sdk#62168]: https://github.com/dart-lang/sdk/issues/62168
[dart-lang/sdk#62216]: https://github.com/dart-lang/sdk/issues/62216
