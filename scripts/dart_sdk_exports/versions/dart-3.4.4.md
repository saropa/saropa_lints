# Dart SDK 3.4.4

## 3.4.4

- 2024-06-12

This is a patch release that:

- Fixes an issue where pub would crash when failing to fetch advisories from
 the server. (issue [pub#4269]).

- Fixes an issue where `const bool.fromEnvironment('dart.library.ffi')` is true
  and conditional import condition `dart.library.ffi` is true in dart2wasm.
  (issue [#55948]).

- Fixes an issue where FFI calls with variadic arguments on MacOS Arm64
  would mangle the arguments. (issue [#55943]).

[pub#4269]: https://github.com/dart-lang/pub/issues/4269
[#55948]: https://github.com/dart-lang/sdk/issues/55948
[#55943]: https://github.com/dart-lang/sdk/issues/55943
