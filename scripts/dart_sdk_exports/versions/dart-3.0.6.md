# Dart SDK 3.0.6

## 3.0.6

- 2023-07-12

This is a patch release that:

- Fixes a flow in flow analysis that causes it to sometimes ignore destructuring
  assignments (issue [#52767]).
- Fixes an infinite loop in some web development compiles that include `is` or
  `as` expressions involving record types with named fields (issue [#52869]).
- Fixes a memory leak in Dart analyzer's file-watching (issue [#52791]).
- Fixes a memory leak of file system watcher related data structures (issue [#52793]).

[#52767]: https://github.com/dart-lang/sdk/issues/52767
[#52869]: https://github.com/dart-lang/sdk/issues/52869
[#52791]: https://github.com/dart-lang/sdk/issues/52791
[#52793]: https://github.com/dart-lang/sdk/issues/52793
