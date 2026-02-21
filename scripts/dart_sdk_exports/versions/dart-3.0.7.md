# Dart SDK 3.0.7

## 3.0.7

- 2023-07-26

This is a patch release that:

- Fixes a bug in dart2js which would cause certain uses of records to lead to
  bad codegen causing a `TypeError` or `NoSuchMethodError` to be thrown
  at runtime (issue [#53001]).

[#53001]: https://github.com/dart-lang/sdk/issues/53001
