# Dart SDK 3.4.1

## 3.4.1

- 2024-05-22

This is a patch release that:

- Fixes a bug in the CFE which could manifest as compilation errors of Flutter
  web apps when compiled with dart2wasm (issue [#55714]).

- Fixes a bug in the pub client, such that `dart run` will not interfere with
  Flutter l10n (at least for most cases) (issue [#55758]).

[#55714]: https://github.com/dart-lang/sdk/issues/55714
[#55758]: https://github.com/dart-lang/sdk/issues/55758
