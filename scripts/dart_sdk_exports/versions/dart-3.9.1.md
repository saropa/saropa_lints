# Dart SDK 3.9.1

## 3.9.1

**Released on:** 2025-08-20

This is a patch release that:

- Fixes an issue in DevTools causing assertion errors in the terminal after
  clicking 'Clear' on the Network Screen (issue [dart-lang/sdk#61187][]).
- Fixes miscompilation to ARM32 when an app used
  a large amount of literals (issue [flutter/flutter#172626][]).
- Fixes an issue with git dependencies using `tag_pattern`,
  where the `pubspec.lock` file would not be stable when
  running `dart pub get` (issue [dart-lang/pub#4644][]).

[dart-lang/sdk#61187]: https://github.com/dart-lang/sdk/issues/61187
[flutter/flutter#172626]: https://github.com/flutter/flutter/issues/172626
[dart-lang/pub#4644]: https://github.com/dart-lang/pub/issues/4644
