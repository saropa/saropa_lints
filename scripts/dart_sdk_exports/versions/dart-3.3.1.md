# Dart SDK 3.3.1

## 3.3.1

- 2024-03-06

This is a patch release that:

- Fixes an issue in dart2js where object literal constructors in interop
  extension types would fail to compile without an `@JS` annotation on the
  library (issue [#55057][]).
- Disallows certain types involving extension types from being used as the
  operand of an `await` expression, unless the extension type itself implements
  `Future` (issue [#55095][]).

[#55057]: https://github.com/dart-lang/sdk/issues/55057
[#55095]: https://github.com/dart-lang/sdk/issues/55095
