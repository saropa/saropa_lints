# Dart SDK 3.5.2

## 3.5.2

- 2024-08-28

- Fixes a bug where `ZLibDecoder` would incorrectly attempt to decompress data
  past the end of the zlib footer (issue [#56481][]).
- Fixes issue where running `dart` from `PATH` could result in some commands not
  working as expected (issues [#56080][], [#56306][], [#56499][]).
- Fixes analysis server plugins not receiving `setContextRoots` requests or
  being provided incorrect context roots in multi-package workspaces (issue
  [#56475][]).

[#56481]: https://github.com/dart-lang/sdk/issues/56481
[#56080]: https://github.com/dart-lang/sdk/issues/56080
[#56306]: https://github.com/dart-lang/sdk/issues/56306
[#56499]: https://github.com/dart-lang/sdk/issues/56499
[#56475]: https://github.com/dart-lang/sdk/issues/56475
