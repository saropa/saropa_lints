# Dart SDK 3.6.2

## 3.6.2

**Released on:** 2025-01-30

- Fixes a bug where `HttpServer` responses were not correctly encoded
  if a "Content-Type" header was set (issue [#59719][]).
- Fix `dart format` to parse code at language version 3.6 so that digit
  separators can be parsed correctly (issue [#59815][], dart_style issue
  [#1630][dart_style #1630]).
- Fixes an issue where the DevTools analytics did not distinguish
  between new and legacy inspector events (issue [#59884][]).
- When running `dart fix` on a folder that contains a library with multiple
  files and more than one needs a fix, the fix will now be applied correctly
  only once to each file (issue [#59572][]).

[#59719]: https://github.com/dart-lang/sdk/issues/59719
[#59815]: https://github.com/dart-lang/sdk/issues/59815
[dart_style #1630]: https://github.com/dart-lang/dart_style/issues/1630
[#59884]: https://github.com/dart-lang/sdk/issues/59884
[#59572]: https://github.com/dart-lang/sdk/issues/59572
