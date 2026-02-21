# Dart SDK 3.4.0

## 3.4.0

- 2024-05-14

### Language

Dart 3.4 makes improvements to the type analysis of conditional expressions
(`e1 ? e2 : e3`), if-null expressions (`e1 ?? e2`), if-null assignments
(`e1 ??= e2`), and switch expressions (`switch (e) { p1 => e1, ... }`). To take
advantage of these improvements, set your package's
[SDK constraint][language version] lower bound to 3.4 or greater
(`sdk: '^3.4.0'`).

[language version]: https://dart.dev/to/language-version

- **Breaking Change** [#54640][]: The pattern context type schema for
  cast patterns has been changed from `Object?` to `_` (the unknown
  type), to align with the specification. This change is not expected
  to make any difference in practice.

- **Breaking Change** [#54828][]: The type schema used by the compiler front end
  to perform type inference on the operand of a null-aware spread operator
  (`...?`) in map and set literals has been made nullable, to match what
  currently happens in list literals. This makes the compiler front end behavior
  consistent with that of the analyzer. This change is expected to be very low
  impact.

[#54640]: https://github.com/dart-lang/sdk/issues/54640
[#54828]: https://github.com/dart-lang/sdk/issues/54828

### Libraries

#### `dart:async`

- Added option for `ParallelWaitError` to get some meta-information that
  it can expose in its `toString`, and the `Iterable<Future>.wait` and
  `(Future,...,Future).wait` extension methods now provide that information.
  Should make a `ParallelWaitError` easier to log.

#### `dart:cli`

- **Breaking change** [#52121][]: `waitFor` is removed in 3.4.

#### `dart:ffi`

- Added `Struct.create` and `Union.create` to create struct and union views
  of the sequence of bytes stored in a subtype of `TypedData`.

#### `dart:io`

- **Breaking change** [#53863][]: `Stdout` has a new field `lineTerminator`,
  which allows developers to control the line ending used by `stdout` and
  `stderr`. Classes that `implement Stdout` must define the `lineTerminator`
  field. The default semantics of `stdout` and `stderr` are not changed.

- Deprecates `FileSystemDeleteEvent.isDirectory`, which always returns
  `false`.

[#53863]: https://github.com/dart-lang/sdk/issues/53863

#### `dart:js_interop`

- Fixes an issue with several comparison operators in `JSAnyOperatorExtension`
  that were declared to return `JSBoolean` but really returned `bool`. This led
  to runtime errors when trying to use the return values. The implementation now
  returns a `JSBoolean` to align with the interface. See issue [#55024] for
  more details.

- Added `ExternalDartReference` and related conversion functions
  `toExternalReference` and `toDartObject`. This is a faster alternative to
  `JSBoxedDartObject`, but with fewer safety guarantees and fewer
  interoperability capabilities. See [#55187] for more details.

- On dart2wasm, `JSBoxedDartObject` now is an actual JS object that wraps the
  opaque Dart value instead of only externalizing the value. Like the JS
  backends, you'll now get a more useful error when trying to use it in another
  Dart runtime.

- Added `isA` helper to make type checks easier with interop types. See
  [#54138][] for more details.

[#54138]: https://github.com/dart-lang/sdk/issues/54138
[#55024]: https://github.com/dart-lang/sdk/issues/55024
[#55187]: https://github.com/dart-lang/sdk/issues/55187

#### `dart:typed_data`

- **BREAKING CHANGE** [#53218][] [#53785][]: The unmodifiable view classes for
  typed data are deprecated.

  To create an unmodifiable view of a typed-data object, use the
  `asUnmodifiableView()` methods added in Dart 3.3:

  ```dart
  Uint8List data = ...;
  final readOnlyView = data.asUnmodifiableView();
  // readOnlyView has type Uint8List, and throws if attempted modified.
  ```

  The reason for this change is to allow more flexibility in the implementation
  of typed data, so the native and web platforms can use different strategies
  to ensure that typed data has good performance.

  The deprecated types will be removed in Dart 3.5.

[#53218]: https://github.com/dart-lang/sdk/issues/53218
[#53785]: https://github.com/dart-lang/sdk/issues/53785

### Tools

#### Analyzer

- Improved code completion. Fixed over 50% of completion correctness bugs,
  tagged `analyzer-completion-correctness` in the [issue
  tracker][analyzer-completion-correction-issues].

- Support for new annotations introduced in version 1.14.0 of the [meta]
  package.

  - Support for the [`@doNotSubmit`] annotation, noting that any usage of an
    annotated member should not be submitted to source control.

  - Support for the [`@mustBeConst`] annotation, which indicates that an
    annotated parameter only accepts constant arguments.

[analyzer-completion-correction-issues]: https://github.com/dart-lang/sdk/labels/analyzer-completion-correctness
[meta]: https://pub.dev/packages/meta
[`@doNotSubmit`]: https://pub.dev/documentation/meta/latest/meta/doNotSubmit-constant.html
[`@mustBeConst`]: https://pub.dev/documentation/meta/latest/meta/mustBeConst-constant.html

#### Linter

- Added the [`unnecessary_library_name`][] lint.
- Added the [`missing_code_block_language_in_doc_comment`][] lint.

[`unnecessary_library_name`]: https://dart.dev/lints/unnecessary_library_name
[`missing_code_block_language_in_doc_comment`]: https://dart.dev/lints/missing_code_block_language_in_doc_comment

#### Compilers

- The compilation environment will no longer pretend to contain entries with
  value `""` for all `dart.library.foo` strings, where `dart:foo` is not an
  available library. Instead there will only be entries for the available
  libraries, like `dart.library.core`, where the value was, and still is,
  `"true"`. This should have no effect on `const bool.fromEnvironment(...)` or
  `const String.fromEnvironment(...)` without a `defaultValue` argument, an
  argument which was always ignored previously. It changes the behavior of
  `const bool.hasEnvironment(...)` on such an input, away from always being
  `true` and therefore useless.

#### DevTools

- Updated DevTools to version 2.33.0 from 2.31.1.
  To learn more, check out the release notes for versions
  [2.32.0][devtools-2-32-0] and [2.33.0][devtools-2-33-0].

[devtools-2-32-0]: https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.32.0
[devtools-2-33-0]: https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.33.0

#### Pub

- Dependency resolution and `dart pub outdated` will now surface if a dependency
  is affected by a security advisory, unless the advisory is listed under a
  `ignored_advisories` section in the `pubspec.yaml` file. To learn more about
  pub's support for security advisories, visit
  [dart.dev/go/pub-security-advisories][pub-security-advisories].

- `path`-dependencies inside `git`-dependencies are now resolved relative to the
  git repo.

- All `dart pub` commands can now be run from any subdirectory of a project. Pub
  will find the first parent directory with a `pubspec.yaml` and operate
  relative it.

- New command `dart pub unpack` that downloads a package from pub.dev and
  extracts it to a subfolder of the current directory.

  This can be useful for inspecting the code, or playing with examples.

[pub-security-advisories]: https://dart.dev/go/pub-security-advisories

### Dart Runtime

- Dart VM flags and options can now be provided to any executable generated
  using `dart compile exe` via the `DART_VM_OPTIONS` environment variable.
  `DART_VM_OPTIONS` should be set to a list of comma-separated flags and options
  with no whitespace. Options that allow for multiple values to be provided as
  comma-separated values are not supported (e.g.,
  `--timeline-streams=Dart,GC,Compiler`).

  Example of a valid `DART_VM_OPTIONS` environment variable:

  ```bash
  DART_VM_OPTIONS=--random_seed=42,--verbose_gc
  ```

- Dart VM no longer supports external strings: `Dart_IsExternalString`,
  `Dart_NewExternalLatin1String` and `Dart_NewExternalUTF16String` functions are
  removed from Dart C API.
