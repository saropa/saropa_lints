# Dart SDK 3.2.1

## 3.2.1

- 2023-11-22

This is a patch release that:

- Fixes the left/mobile sidebar being empty on non-class pages
  in documentation generated with `dart doc` (issue [#54073][]).

- Fixes a JSON array parsing bug that causes a segmentation fault when
  `flutter test` is invoked with the `--coverage` flag
  (SDK issue [#54059][], Flutter issue [#124145][]).

- Upgrades Dart DevTools to version 2.28.3 (issue [#54085][]).

[#54073]: https://github.com/dart-lang/sdk/issues/54073
[#54059]: https://github.com/dart-lang/sdk/issues/54059
[#124145]: https://github.com/flutter/flutter/issues/124145
[#54085]: https://github.com/dart-lang/sdk/issues/54085
