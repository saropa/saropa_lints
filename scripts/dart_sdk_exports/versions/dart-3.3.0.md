# Dart SDK 3.3.0

## 3.3.0

### Language

Dart 3.3 adds [extension types] to the language. To use them, set your
package's [SDK constraint][language version] lower bound to 3.3 or greater
(`sdk: '^3.3.0'`).

#### Extension types

[extension types]: https://github.com/dart-lang/language/issues/2727

An _extension type_ wraps an existing type with a different, static-only
interface. It works in a way which is in many ways similar to a class that
contains a single final instance variable holding the wrapped object, but
without the space and time overhead of an actual wrapper object.

Extension types are introduced by _extension type declarations_. Each
such declaration declares a new named type (not just a new name for the
same type). It declares a _representation variable_ whose type is the
_representation type_. The effect of using an extension type is that the
_representation_ (that is, the value of the representation variable) has
the members declared by the extension type rather than the members declared
by its "own" type (the representation type). Example:

```dart
extension type Meters(int value) {
  String get label => '${value}m';
  Meters operator +(Meters other) => Meters(value + other.value);
}

void main() {
  var m = Meters(42); // Has type `Meters`.
  var m2 = m + m; // OK, type `Meters`.
  // int i = m; // Compile-time error, wrong type.
  // m.isEven; // Compile-time error, no such member.
  assert(identical(m, m.value)); // Succeeds.
}
```

The declaration `Meters` is an extension type that has representation type
`int`. It introduces an implicit constructor `Meters(int value);` and a
getter `int get value`. `m` and `m.value` is the very same object, but `m`
has type `Meters` and `m.value` has type `int`. The point is that `m`
has the members of `Meters` and `m.value` has the members of `int`.

Extension types are entirely static, they do not exist at run time. If `o`
is the value of an expression whose static type is an extension type `E`
with representation type `R`, then `o` is just a normal object whose
run-time type is a subtype of `R`, exactly like the value of an expression
of type `R`. Also the run-time value of `E` is `R` (for example, `E == R`
is true). In short: At run time, an extension type is erased to the
corresponding representation type.

A method call on an expression of an extension type is resolved at
compile-time, based on the static type of the receiver, similar to how
extension method calls work. There is no virtual or dynamic dispatch. This,
combined with no memory overhead, means that extension types are zero-cost
wrappers around their representation value.

While there is thus no performance cost to using extension types, there is
a safety cost. Since extension types are erased at compile time, run-time
type tests on values that are statically typed as an extension type will
check the type of the representation object instead, and if the type check
looks like it tests for an extension type, like `is Meters`, it actually
checks for the representation type, that is, it works exactly like `is int`
at run time. Moreover, as mentioned above, if an extension type is used as
a type argument to a generic class or function, the type variable will be
bound to the representation type at run time. For example:

```dart
void main() {
  var meters = Meters(3);

  // At run time, `Meters` is just `int`.
  print(meters is int); // Prints "true".
  print(<Meters>[] is List<int>); // Prints "true".

  // An explicit cast is allowed and succeeds as well:
  List<Meters> meterList = <int>[1, 2, 3] as List<Meters>;
  print(meterList[1].label); // Prints "2m".
}
```

Extension types are useful when you are willing to sacrifice some run-time
encapsulation in order to avoid the overhead of wrapping values in
instances of wrapper classes, but still want to provide a different
interface than the wrapped object. An example of that is interop, where you
may have data that are not Dart objects to begin with (for example, raw
JavaScript objects when using JavaScript interop), and you may have large
collections of objects where it's not efficient to allocate an extra object
for each element.

#### Other changes

- **Breaking Change** [#54056][]: The rules for private field promotion have
  been changed so that an abstract getter is considered promotable if there are
  no conflicting declarations. There are no conflicting declarations if
  there are no non-final fields, external fields, concrete getters, or
  `noSuchMethod` forwarding getters with the same name in the same library.
  This makes the implementation more consistent and allows
  type promotion in a few rare scenarios where it wasn't previously allowed.
  It is unlikely, but this change could cause a breakage by changing
  an inferred type in a way that breaks later code. For example:

  ```dart
  class A {
    int? get _field;
  }
  class B extends A {
    final int? _field;
    B(this._field);
  }
  test(A a) {
    if (a._field != null) {
      var x = a._field; // Previously had type `int?`; now has type `int`
      ...
      x = null; // Previously allowed; now causes a compile-time error.
    }
  }
  ```

  Affected code can be fixed by adding an explicit type annotation.
  For example, in the above snippet, `var x` can be changed to `int? x`.

  It's also possible that some continuous integration configurations might fail
  if they have been configured to treat warnings as errors, because the expanded
  type promotion could lead to one of the following warnings:

  - `unnecessary_non_null_assertion`
  - `unnecessary_cast`
  - `invalid_null_aware_operator`

  These warnings can be addressed in the usual way, by removing the unnecessary
  operation in the first two cases, or changing `?.` to `.` in the third case.

  To learn more about other rules surrounding type promotion,
  check out the guide on [Fixing type promotion failures][].

[#54056]: https://github.com/dart-lang/sdk/issues/54056
[Fixing type promotion failures]: https://dart.dev/tools/non-promotion-reasons

### Libraries

#### `dart:core`

- `String.fromCharCodes` now allow `start` and `end` to be after the end of
  the `Iterable` argument, just like `skip` and `take` does on an `Iterable`.

#### `dart:ffi`

- In addition to functions, `@Native` can now be used on fields.
- Allow taking the address of native functions and fields via
  `Native.addressOf`.
- The `elementAt` pointer arithmetic extension methods on
  core `Pointer` types are now deprecated.
  Migrate to the new `-` and `+` operators instead.
- The experimental and deprecated `@FfiNative` annotation has been removed.
  Usages should be updated to use the `@Native` annotation.

#### `dart:js_interop`

- **Breaking Change in the representation of JS types** [#52687][]: JS types
  like `JSAny` were previously represented using a custom erasure of
  `@staticInterop` types that were compiler-specific. They are now represented
  as extension types where their representation types are compiler-specific.
  This means that user-defined `@staticInterop` types that implemented `JSAny`
  or `JSObject` can no longer do so and need to use
  `JSObject.fromInteropObject`. Going forward, it's recommended to use extension
  types to define interop APIs. Those extension types can still implement JS
  types.
- **JSArray and JSPromise generics**: `JSArray` and `JSPromise` are now generic
  types whose type parameter is a subtype of `JSAny?`. Conversions to and from
  these types are changed to account for the type parameters of the Dart or JS
  type, respectively.
- **Breaking Change in names of extensions**: Some `dart:js_interop` extension
  members are moved to different extensions on the same type or a supertype to
  better organize the API surface. See `JSAnyUtilityExtension` and
  `JSAnyOperatorExtension` for the new extensions. This shouldn't make a
  difference unless the extension names were explicitly used.
- Add `importModule` to allow users to dynamically import modules using the JS
  `import()` expression.

[#52687]: https://github.com/dart-lang/sdk/issues/52687

#### `dart:js_interop_unsafe`

- Add `has` helper to make `hasProperty` calls more concise.

#### `dart:typed_data`

- **BREAKING CHANGE** (https://github.com/dart-lang/sdk/issues/53218) The
  unmodifiable view classes for typed data are deprecated. Instead of using the
  constructors for these classes to create an unmodifiable view, e.g.

  ```dart
  Uint8List data = ...
  final readOnlyView = UnmodifiableUint8ListView(data);
  ```

  use the new `asUnmodifiableView()` methods:

  ```dart
  Uint8List data = ...
  final readOnlyView = data.asUnmodifiableView();
  ```

  The reason for this change is to allow more flexibility in the implementation
  of typed data so the native and web platforms can use different strategies
  for ensuring typed data has good performance.

  The deprecated types will be removed in a future Dart version.

#### `dart:nativewrappers`

- **Breaking Change** [#51896][]: The NativeWrapperClasses are marked `base` so
  that none of their subtypes can be implemented. Implementing subtypes can lead
  to crashes when passing such native wrapper to a native call, as it will try
  to unwrap a native field that doesn't exist.

[#51896]: https://github.com/dart-lang/sdk/issues/51896

### Tools

#### Dart command line

- The `dart create` command now uses v3 of `package:lints`,
  including multiple new recommended lints by default.
  To learn more about the updated collection of lints,
  check out the `package:lints` [3.0.0 changelog entry][lints-3-0].

[lints-3-0]: https://pub.dev/packages/lints/changelog#300

#### DevTools

- Updated DevTools to version 2.31.1 from 2.28.1.
  To learn more, check out the release notes for versions
  [2.29.0][devtools-2-29-0], [2.30.0][devtools-2-30-0],
  and [2.31.0][devtools-2-31-0].

[devtools-2-29-0]: https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.29.0
[devtools-2-30-0]: https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.30.0
[devtools-2-31-0]: https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.31.0

#### Wasm compiler (dart2wasm)

- **Breaking Change** [#54004][]: `dart:js_util`, `package:js`, and `dart:js`
  are now disallowed from being imported when compiling with `dart2wasm`. Prefer
  using `dart:js_interop` and `dart:js_interop_unsafe`.

[#54004]: https://github.com/dart-lang/sdk/issues/54004

#### Development JavaScript compiler (DDC)

- Type arguments of `package:js` interop types are now printed as `any` instead
  of being omitted. This is simply a change to the textual representation of
  package js types that have type arguments. These type arguments are still
  completely ignored by the type system at runtime.

- Removed "implements <...>" text from the Chrome custom formatter display for
  Dart classes. This information provides little value and keeping it imposes an
  unnecessary maintenance cost.

#### Production JavaScript compiler (dart2js)

- **Breaking Change** [#54201][]:
  The `Invocation` that is passed to `noSuchMethod` will no longer have a
  minified `memberName`, even when dart2js is invoked with `--minify`.
  See [#54201][] for more details.

[#54201]: https://github.com/dart-lang/sdk/issues/54201

#### Analyzer

- You can now suppress diagnostics in `pubspec.yaml` files by
  adding an `# ignore: <diagnostic_id>` comment.
- Invalid `dart doc` comment directives are now reported.
- The [`flutter_style_todos`][] lint now has a quick fix.

[`flutter_style_todos`]: https://dart.dev/lints/flutter_style_todos

#### Linter

- Removed the `iterable_contains_unrelated_type` and
  `list_remove_unrelated_type` lints.
  Consider migrating to the expanded
  [`collection_methods_unrelated_type`][] lint.
- Removed various lints that are no longer necessary with sound null safety:
  - `always_require_non_null_named_parameters`
  - `avoid_returning_null`,
  - `avoid_returning_null_for_future`

[`collection_methods_unrelated_type`]: https://dart.dev/lints/collection_methods_unrelated_type
