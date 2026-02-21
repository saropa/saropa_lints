# Dart SDK 3.4.2

## 3.4.2

- 2024-05-29

This is a patch release that:

- Marks `dart compile wasm` as no longer experimental.

- Fixes two bugs in exception handling in `async` functions in dart2wasm
  (issues [#55347], [#55457]).

- Fixes restoration of `this` variable in `sync*` and `async` functions in
  dart2wasm.

- Implements missing control flow constructs (exceptions, switch/case with
  yields) in `sync*` in dart2wasm (issues [#51342], [#51343]).

- Fixes a bug dart2wasm compiler that surfaces as a compiler crash when indexing
  lists where the compiler proofs the list to be constant and the index is
  out-of-bounds (issue [#55817]).

[#55347]: https://github.com/dart-lang/sdk/issues/55347
[#55457]: https://github.com/dart-lang/sdk/issues/55457
[#51342]: https://github.com/dart-lang/sdk/issues/51342
[#51343]: https://github.com/dart-lang/sdk/issues/51343
[#55817]: https://github.com/dart-lang/sdk/issues/55817
