# Dart SDK 3.0.4

## 3.0.4

- 2023-06-07

This is a patch release that:

- `dart format` now handles formatting nullable record types
  with no fields (dart_style issue [#1224]).
- Fixes error when using records when targeting the web in development mode
  (issue [#52480]).

[#1224]: https://github.com/dart-lang/dart_style/issues/1224
[#52480]: https://github.com/dart-lang/sdk/issues/52480
