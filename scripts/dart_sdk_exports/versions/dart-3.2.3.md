# Dart SDK 3.2.3

## 3.2.3

- 2023-12-06

This is a patch release that:

- Disallows final fields to be used in a constant context during analysis
  (issue [#54232][]).
- Upgrades Dart DevTools to version 2.28.4 (issue [#54213][]).
- Fixes new AOT snapshots in the SDK failing with SIGILL in ARM
  environments that don't support the integer division
  instructions or x86-64 environments that don't support
  SSE4.1 (issue [#54215][]).

[#54232]: https://github.com/dart-lang/sdk/issues/54232
[#54213]: https://github.com/dart-lang/sdk/issues/54213
[#54215]: https://github.com/dart-lang/sdk/issues/54215
