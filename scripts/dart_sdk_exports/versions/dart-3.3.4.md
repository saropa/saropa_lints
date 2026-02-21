# Dart SDK 3.3.4

## 3.3.4

- 2024-04-17

This is a patch release that:

- Fixes an issue with JS interop in dart2wasm where JS interop methods that used
  the enclosing library's `@JS` annotation were actually using the invocation's
  enclosing library's `@JS` annotation. (issue [#55430]).

[#55430]: https://github.com/dart-lang/sdk/issues/55430
