# Dart SDK 3.5.0

## 3.5.0

- 2024-08-06

### Language

- **Breaking Change** [#55418][]: The context used by the compiler to perform
  type inference on the operand of an `await` expression has been changed to
  match the behavior of the analyzer. This change is not expected to make any
  difference in practice.

- **Breaking Change** [#55436][]: The context used by the compiler to perform
  type inference on the right hand side of an "if-null" expression (`e1 ?? e2`)
  has been changed to match the behavior of the analyzer. change is expected to
  have low impact on real-world code. But in principle it could cause
  compile-time errors or changes in runtime behavior by changing inferred
  types. The old behavior can be restored by supplying explicit types.

[#55418]: https://github.com/dart-lang/sdk/issues/55418
[#55436]: https://github.com/dart-lang/sdk/issues/55436

### Libraries

#### `dart:core`

- **Breaking Change** [#44876][]: `DateTime` on the web platform now stores
  microseconds. The web implementation is now practically compatible with the
  native implementation, where it is possible to round-trip a timestamp in
  microseconds through a `DateTime` value without rounding the lower
  digits. This change might be breaking for apps that rely in some way on the
  `.microsecond` component always being zero, for example, expecting only three
  fractional second digits in the `toString()` representation. Small
  discrepancies in arithmetic due to rounding of web integers may still occur
  for extreme values, (1) `microsecondsSinceEpoch` outside the safe range,
  corresponding to dates with a year outside of 1685..2255, and (2) arithmetic
  (`add`, `subtract`, `difference`) where the `Duration` argument or result
  exceeds 570 years.

[#44876]: https://github.com/dart-lang/sdk/issues/44876

#### `dart:io`

- **Breaking Change** [#55786][]: `SecurityContext` is now `final`. This means
  that `SecurityContext` can no longer be subclassed. `SecurityContext`
  subclasses were never able to interoperate with other parts of `dart:io`.

- A `ConnectionTask` can now be created using an existing `Future<Socket>`.
  Fixes [#55562].

[#55786]: https://github.com/dart-lang/sdk/issues/55786
[#55562]: https://github.com/dart-lang/sdk/issues/55562

#### `dart:typed_data`

- **Breaking Change** [#53785][]: The unmodifiable view classes for typed data
  have been removed. These classes were deprecated in Dart 3.4.

  To create an unmodifiable view of a typed-data object, use the
  `asUnmodifiableView()` methods added in Dart 3.3.

- Added superinterface `TypedDataList` to typed data lists, implementing both
  `List` and `TypedData`. Allows abstracting over all such lists without losing
  access to either the `List` or the `TypedData` members.
  A `ByteData` is still only a `TypedData`, not a list.

[#53785]: https://github.com/dart-lang/sdk/issues/53785

#### `dart:js_interop`

- **Breaking Change** [#55508][]: `importModule` now accepts a `JSAny` instead
  of a `String` to support other JS values as well, like `TrustedScriptURL`s.

- **Breaking Change** [#55267][]: `isTruthy` and `not` now return `JSBoolean`
  instead of `bool` to be consistent with the other operators.

- **Breaking Change** `ExternalDartReference` no longer implements `Object`.
  `ExternalDartReference` now accepts a type parameter `T` with a bound of
  `Object?` to capture the type of the Dart object that is externalized.
  `ExternalDartReferenceToObject.toDartObject` now returns a `T`.
  `ExternalDartReferenceToObject` and `ObjectToExternalDartReference` are now
  extensions on `T` and `ExternalDartReference<T>`, respectively, where `T
  extends Object?`. See [#55342][] and [#55536][] for more details.

- Fixed some consistency issues with `Function.toJS` across all compilers.
  Specifically, calling `Function.toJS` on the same function gives you a new JS
  function (see issue [#55515][]), the maximum number of arguments that are
  passed to the JS function is determined by the static type of the Dart
  function, and extra arguments are dropped when passed to the JS function in
  all compilers (see [#48186][]).

[#55508]: https://github.com/dart-lang/sdk/issues/55508
[#55267]: https://github.com/dart-lang/sdk/issues/55267
[#55342]: https://github.com/dart-lang/sdk/issues/55342
[#55536]: https://github.com/dart-lang/sdk/issues/55536
[#55515]: https://github.com/dart-lang/sdk/issues/55515
[#48186]: https://github.com/dart-lang/sdk/issues/48186

### Tools

#### Analyzer

- Add the [`unintended_html_in_doc_comment`][] lint rule.
- Add the [`invalid_runtime_check_with_js_interop_types`][] lint rule.
- Add the [`document_ignores`][] lint rule.
- Add quick fixes for more than 70 diagnostics.
- The "Add missing switch cases" quick fix now adds multiple cases, such that
  the switch becomes exhaustive.
- The "Remove const" quick fix now adds `const` keywords to child nodes, where
  appropriate.

[`unintended_html_in_doc_comment`]: https://dart.dev/lints/unintended_html_in_doc_comment
[`invalid_runtime_check_with_js_interop_types`]: https://dart.dev/lints/invalid_runtime_check_with_js_interop_types
[`document_ignores`]: https://dart.dev/lints/document_ignores

#### Pub

- New flag `dart pub downgrade --tighten` to restrict lower bounds of
  dependencies' constraints to the minimum that can be resolved.

### Dart Runtime

- The Dart VM only executes sound null safe code, running of unsound null
  safe code using the option `--no-sound-null-safety` has been removed.

- `Dart_NewListOf` and `Dart_IsLegacyType` functions are
  removed from Dart C API.

- `Dart_DefaultCanonicalizeUrl` is removed from the Dart C API.
