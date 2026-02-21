# Dart SDK 3.10.0

## 3.10.0

**Released on:** 2025-11-12

### Language

Dart 3.10 adds [dot shorthands][dot-shorthand-spec] to the language. To use
them, set your package's [SDK constraint][language version] lower bound to 3.10
or greater (`sdk: '^3.10.0'`).

Dart 3.10 also adjusts the inferred return type of a generator function (`sync*`
or `async*`) to avoid introducing unneeded nullability.

#### Dot shorthands

Dot shorthands allow you to omit the type name when accessing a static member
in a context where that type is expected.

These are some examples of ways you can use dot shorthands:

```dart
Color color = .blue;
switch (color) {
  case .blue:
    print('blue');
  case .red:
    print('red');
  case .green:
    print('green');
}
```

```dart
Column(
  crossAxisAlignment: .start,
  mainAxisSize: .min,
  children: widgets,
)
```

To learn more about the feature, check out the
[feature specification][dot-shorthand-spec].

[dot-shorthand-spec]: https://github.com/dart-lang/language/blob/main/accepted/3.10/dot-shorthands/feature-specification.md

#### Eliminate spurious Null from generator return type

The following local function `f` used to have return type `Iterable<int?>`.
The question mark in this type is spurious because the returned iterable
will never contain null (`return;` stops the iteration, it does not add null
to the iterable). This feature makes the return type `Iterable<int>`.

```dart
void main() {
  f() sync* {
    yield 1;
    return;
  }
}
```

This change may cause some code elements to be flagged as unnecessary. For
example, `f().first?.isEven` is flagged, and `f().first.isEven` is recommended
instead.

### Tools

#### Analyzer

- The analyzer includes a new plugin system. You can use this system to write
  your own analysis rules and IDE quick fixes.

  - **Analysis rules:** Static analysis checks that report diagnostics (lints
    or warnings). You see these in your IDE and at the command line via `dart
    analyze` or `flutter analyze`.
  - **Quick fixes:** Local refactorings that correct a reported lint or
    warning.
  - **Quick assists:** Local refactorings available in the IDE that are not
    associated with a specific diagnostic.

  See the documentation for [writing an analyzer plugin][], and the
  documentation for [using analyzer plugins][] to learn more.

- Lint rules which are incompatible with each other and which are specified in
  included analysis options files are now reported.
- Offer to add required named field formal parameters in a constructor when a
  field is not initialized.
- Support the new `@Deprecated` annotations by reporting warnings when specific
  functionality of an element is deprecated.
- Offer to import a library for an appropriate extension member when method or
  property is accessed on a nullable value.
- Offer to remove the `const` keyword for a constructor call which includes a
  method invocation.
- Remove support for the deprecated `@required` annotation.
- Add two assists to bind constructor parameters to an existing or a
  non-existing field.
- Add a warning which is reported when an `@experimental` member is used
  outside of the package in which it is declared.
- Add a new lint rule, `remove_deprecations_in_breaking_versions`, is added to
  encourage developers to remove any deprecated members when the containing
  package has a "breaking version" number, like `x.0.0` or `0.y.0`.
- (Thanks [@FMorschel](https://github.com/FMorschel) for many of the above
  enhancements!)

[writing an analyzer plugin]: https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server_plugin/doc/writing_a_plugin.md
[using analyzer plugins]: https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server_plugin/doc/using_plugins.md

#### Hooks

Support for **hooks** -- formerly know as _native assets_ -- are now stable.

You can currently use hooks to do things such as compile or download native assets
(code written in other languages that are compiled into machine code),
and then call these assets from the Dart code of a package.

For more details see the [hooks documentation](https://dart.dev/tools/hooks).

#### Dart CLI and Dart VM

- The Dart CLI and Dart VM have been split into two separate executables.

  The Dart CLI tool has been split out of the VM into it's own embedder which
  runs in AOT mode. The pure Dart VM executable is called `dartvm` and
  has no Dart CLI functionality in it.

  The Dart CLI executable parses the CLI commands and invokes the rest
  of the AOT tools in the same process, for the 'run' and 'test'
  commands it execs a process which runs `dartvm`.

  `dart hello.dart` execs the `dartvm` process and runs the `hello.dart` file.

  The Dart CLI is not generated for ia32 as we are not shipping a
  Dart SDK for ia32 anymore (support to execute the `dartvm` for ia32
  architecture is retained).

### Libraries

#### `dart:async`

- Added `Future.syncValue` constructor for creating a future with a
  known value. Unlike `Future.value`, it does not allow an asynchronous
  `Future<T>` as the value of a new `Future<T>`.

#### `dart:core`

- **Breaking Change** [#61392][]: The `Uri.parseIPv4Address` function
  no longer incorrectly allows leading zeros. This also applies to
  `Uri.parseIPv6Address` for IPv4 addresses embedded in IPv6 addresses.
- The `Uri.parseIPv4Address` adds `start` and `end` parameters
  to allow parsing a substring without creating a new string.
- New annotations are offered for deprecating specific functionalities:
  - [`@Deprecated.extend()`][] indicates the ability to extend a class is
    deprecated.
  - [`@Deprecated.implement()`][] indicates the ability to implement a class or
    mixin is deprecated.
  - [`@Deprecated.subclass()`][] indicates the ability to extend a class or
    implement a class or mixin is deprecated.
  - [`@Deprecated.mixin()`][] indicates the ability to mix in a class is
    deprecated.
  - [`@Deprecated.instantiate()`][] indicates the ability to instantiate a
    class is deprecated.
- The ability to implement the RegExp class and the RegExpMatch class is
  deprecated.

[#61392]: https://dartbug.com/61392
[`@Deprecated.extend()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.extend.html
[`@Deprecated.implement()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.implement.html
[`@Deprecated.subclass()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.subclass.html
[`@Deprecated.mixin()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.mixin.html
[`@Deprecated.instantiate()`]: https://api.dart.dev/dev/latest/dart-core/Deprecated/Deprecated.instantiate.html

#### `dart:io`

- **Breaking Change** [#56468][]: Marked `IOOverrides` as an `abstract base`
  class so it can no longer be implemented.
- Added ability to override behavior of `exit(...)` to `IOOverrides`.

[#56468]: https://github.com/dart-lang/sdk/issues/56468

#### `dart:js_interop`

- `JSArray.add` is added to avoid cases where during migration from `List` to
  `JSArray`, `JSAnyOperatorExtension.add` is accidentally used. See [#59830][]
  for more details.
- `isA<JSBoxedDartObject>` now checks that the value was the result of a
  `toJSBox` operation instead of returning true for all objects.
- For object literals created from extension type factories, the `@JS()`
  annotation can now be used to change the name of keys in JavaScript. See
  [#55138][] for more details.
- Compile-time checks for `Function.toJS` now apply to `toJSCaptureThis` as
  well. Specifically, the function should be a statically known type, cannot
  contain invalid types in its signature, cannot have any type parameters, and
  cannot have any named parameters.
- On dart2wasm, typed lists that are wrappers around typed arrays now return the
  original typed array when unwrapped instead of instantiating a new typed array
  with the same buffer. This applies to both the `.toJS` conversions and
  `jsify`. See [#61543][] for more details.
- `Uint16ListToJSInt16Array` is renamed to `Uint16ListToJSUint16Array`.
- `JSUint16ArrayToInt16List` is renamed to `JSUint16ArrayToUint16List`.
- The dart2wasm implementation of `dartify` now converts JavaScript `Promise`s
  to Dart `Future`s rather than `JSValue`s, consistent with dart2js and DDC. See
  [#54573][] for more details.
- `createJSInteropWrapper` now additionally takes an optional parameter which
  specifies the JavaScript prototype of the created object, similar to
  `createStaticInteropMock` in `dart:js_util`. See [#61567][] for more details.

[#59830]: https://github.com/dart-lang/sdk/issues/59830
[#55138]: https://github.com/dart-lang/sdk/issues/55138
[#61543]: https://github.com/dart-lang/sdk/issues/61543
[#54573]: https://github.com/dart-lang/sdk/issues/54573
[#61567]: https://github.com/dart-lang/sdk/issues/61567

#### `dart:js_util`

- dart2wasm no longer supports `dart:js_util` and will throw an
  `UnsupportedError` if any API from this library is invoked. This also applies
  to `package:js/js_util.dart`. `package:js/js.dart` continues to be supported.
  See [#61550][] for more details.

[#61550]: https://github.com/dart-lang/sdk/issues/61550
