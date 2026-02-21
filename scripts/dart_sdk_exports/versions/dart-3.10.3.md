# Dart SDK 3.10.3

## 3.10.3

**Released on:** 2025-12-02

This is a patch release that:

- Fixes an issue with the color picker not working with dot shorthands. (issue
   [Dart-Code/Dart-Code#61978])
- Enables hiding `Running build hooks` in `dart run` with `--verbosity=error`.
  (issue [dart-lang/sdk#61996])
- Fixes an issue with test_with_coverage and build hooks in dev depencencies.
  (issue [dart-lang/tools#2237])
- Fixes an issue where a crash could occur when evaluating expressions
  after a recompilation (issue [flutter/flutter#178740]).
- Fixes watching of directory moves on MacOS [dart-lang/sdk#62136].
- Fixes an issue with the analyzer not emitting an error when using a dot
  shorthand with type arguments on a factory constructor in an abstract class.
  (issue [dart-lang/sdk#61978])

[Dart-Code/Dart-Code#61978]: https://github.com/Dart-Code/Dart-Code/issues/5810
[dart-lang/sdk#61996]: https://github.com/dart-lang/sdk/issues/61996
[dart-lang/tools#2237]: https://github.com/dart-lang/tools/issues/2237
[flutter/flutter#178740]: https://github.com/flutter/flutter/issues/178740
[dart-lang/sdk#62136]: https://github.com/dart-lang/sdk/issues/62136
[dart-lang/sdk#61978]: https://github.com/dart-lang/sdk/issues/61978
