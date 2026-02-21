# Dart SDK 3.10.1

## 3.10.1

**Released on:** 2025-11-18

This is a patch release that:

- Fixes an issue with dot shorthand code completion for the `==` operator,
  `FutureOr` types, switch expressions, and switch statements.
  (issue [dart-lang/sdk#61872][]).
- Fixes an issue with the analyzer not reporting an error when invoking an
  instance method with a dot shorthand. (issue [dart-lang/sdk#61954][]).
- Fixes a crash with the `ExitDetector` in the analyzer missing a few visitor
  methods for dot shorthand AST nodes. (issue [dart-lang/sdk#61963])
- Fixes an analyzer crash that would sometimes occur when the
  `prefer_const_constructors` lint was enabled (issue [dart-lang/sdk#61953][]).
- Updates dartdoc dependency to dartdoc 9.0.0 which fixes dartdoc rendering of
  `@Deprecated.extend()` and the other new deprecated annotations.

[dart-lang/sdk#61872]: https://github.com/dart-lang/sdk/issues/61872
[dart-lang/sdk#61954]: https://github.com/dart-lang/sdk/issues/61954
[dart-lang/sdk#61963]: https://github.com/dart-lang/sdk/issues/61963
[dart-lang/sdk#61953]: https://github.com/dart-lang/sdk/issues/61953
