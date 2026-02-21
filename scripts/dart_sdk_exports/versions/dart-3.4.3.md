# Dart SDK 3.4.3

## 3.4.3

- 2024-06-05

This is a patch release that:

- Fixes an issue where `DART_VM_OPTIONS` were not correctly parsed for
  standalone Dart executables created with `dart compile exe` (issue
  [#55818]).

- Fixes a bug in dart2wasm that can result in a runtime error that says
  `array.new_fixed()` has a constant larger than 10000 (issue [#55873]).

- Adds support for `--enable-experiment` flag to `dart compile wasm`
  (issue [#55894]).

- Fixes an issue in dart2wasm compiler that can result in incorrect
  nullability of type parameter (see [#55895]).

- Disallows `dart:ffi` imports in user code in dart2wasm (e.g. issue
  [#53910]) as dart2wasm's currently only supports a small subset of
  `dart:ffi` (issue [#55890]).

[#55818]: https://github.com/dart-lang/sdk/issues/55818
[#55873]: https://github.com/dart-lang/sdk/issues/55873
[#55894]: https://github.com/dart-lang/sdk/issues/55894
[#55895]: https://github.com/dart-lang/sdk/issues/55895
[#55910]: https://github.com/dart-lang/sdk/issues/53910
[#55890]: https://github.com/dart-lang/sdk/issues/55890
