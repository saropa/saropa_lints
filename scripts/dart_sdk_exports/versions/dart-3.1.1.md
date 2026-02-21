# Dart SDK 3.1.1

## 3.1.1

- 2023-09-07

This is a patch release that:

- Fixes a bug in the parser which prevented a record pattern from containing a
  nested record pattern, where the nested record pattern uses record
  destructuring shorthand syntax, for example `final ((:a, :b), c) = record;`
  (issue [#53352]).

[#53352]: https://github.com/dart-lang/sdk/issues/53352
