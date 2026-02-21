# Dart SDK 3.2.0

## 3.2.0

- 2023-11-15

### Language

Dart 3.2 adds the following features. To use them, set your package's [SDK
constraint][language version] lower bound to 3.2 or greater (`sdk: '^3.2.0'`).

[language version]: https://dart.dev/to/language-version

- **Private field promotion**: In most circumstances, the types of private final
  fields can now be promoted by null checks and `is` tests. For example:

  ```dart
  class Example {
    final int? _privateField;
    Example(this._privateField);

    f() {
      if (_privateField != null) {
        // _privateField has now been promoted; you can use it without
        // null checking it.
        int i = _privateField; // OK
      }
    }
  }

  // Private field promotions also work from outside of the class:
  f(Example x) {
    if (x._privateField != null) {
      int i = x._privateField; // OK
    }
  }
  ```

  To ensure soundness, a field is not eligible for field promotion in the
  following circumstances:
  - If it's not final (because a non-final field could be changed in between the
    test and the usage, invalidating the promotion).
  - If it's overridden elsewhere in the library by a concrete getter or a
    non-final field (because an access to an overridden field might resolve at
    runtime to the overriding getter or field).
  - If it's not private (because a non-private field might be overridden
    elsewhere in the program).
  - If it has the same name as a concrete getter or a non-final field in some
    other unrelated class in the library (because a class elsewhere in the
    program might extend one of the classes and implement the other, creating an
    override relationship between them).
  - If there is a concrete class `C` in the library whose interface contains a
    getter with the same name, but `C` does not have an implementation of that
    getter (such unimplemented getters aren't safe for field promotion, because
    they are implicitly forwarded to `noSuchMethod`, which might not return the
    same value each time it's called).

- **Breaking Change** [#53167][]: Use a more precise split point for refutable
  patterns. Previously, in an if-case statement, if flow analysis could prove
  that the scrutinee expression was guaranteed to throw an exception, it would
  sometimes fail to propagate type promotions implied by the pattern to the
  (dead) code that follows. This change makes the type promotion behavior of
  if-case statements consistent regardless of whether the scrutinee expression
  throws an exception.

  No live code is affected by this change, but there is a small chance that the
  change in types will cause a compile-time error to appear in some dead code in
  the user's project, where no compile-time error appeared previously.

[#53167]: https://github.com/dart-lang/sdk/issues/53167

### Libraries

#### `dart:async`

- Added `broadcast` parameter to `Stream.empty` constructor.

#### `dart:cli`

- **Breaking change** [#52121][]:
  - `waitFor` is disabled by default and slated for removal in 3.4. Attempting
  to call this function will now throw an exception. Users that still depend
  on `waitFor` can enable it by passing `--enable_deprecated_wait_for` flag
  to the VM.

[#52121]: https://github.com/dart-lang/sdk/issues/52121

#### `dart:convert`

- **Breaking change** [#52801][]:
  - Changed return types of `utf8.encode()` and `Utf8Codec.encode()` from
    `List<int>` to `Uint8List`.

[#52801]: https://github.com/dart-lang/sdk/issues/52801

#### `dart:developer`

- Deprecated the `Service.getIsolateID` method.
- Added `getIsolateId` method to `Service`.
- Added `getObjectId` method to `Service`.

#### `dart:ffi`

- Added the `NativeCallable.isolateLocal` constructor. This creates
  `NativeCallable`s with the same functionality as `Pointer.fromFunction`,
  except that `NativeCallable` accepts closures.
- Added the `NativeCallable.keepIsolateAlive` method, which determines whether
  the `NativeCallable` keeps the isolate that created it alive.
- All `NativeCallable` constructors can now accept closures. Previously
  `NativeCallable`s had the same restrictions as `Pointer.fromFunction`, and
  could only create callbacks for static functions.
- **Breaking change** [#53311][]: `NativeCallable.nativeFunction` now throws an
  error if is called after the `NativeCallable` has already been `close`d. Calls
  to `close` after the first are now ignored.

[#53311]: https://github.com/dart-lang/sdk/issues/53311

#### `dart:io`

- **Breaking change** [#53005][]: The headers returned by
  `HttpClientResponse.headers` and `HttpRequest.headers` no longer include
  trailing whitespace in their values.

- **Breaking change** [#53227][]: Folded headers values returned by
  `HttpClientResponse.headers` and `HttpRequest.headers` now have a space
  inserted at the fold point.

[#53005]: https://dartbug.com/53005
[#53227]: https://dartbug.com/53227

#### `dart:isolate`

- Added `Isolate.packageConfigSync` and `Isolate.resolvePackageUriSync` APIs.

#### `dart:js_interop`

- **Breaking Change on JSNumber.toDart and Object.toJS**:
  `JSNumber.toDart` is removed in favor of `toDartDouble` and `toDartInt` to
  make the type explicit. `Object.toJS` is also removed in favor of
  `Object.toJSBox`. Previously, this function would allow Dart objects to flow
  into JS unwrapped on the JS backends. Now, there's an explicit wrapper that is
  added and unwrapped via `JSBoxedDartObject.toDart`. Similarly,
  `JSExportedDartObject` is renamed to `JSBoxedDartObject` and the extensions
  `ObjectToJSExportedDartObject` and `JSExportedDartObjectToObject` are renamed
  to `ObjectToJSBoxedDartObject` and `JSBoxedDartObjectToObject` in order to
  avoid confusion with `@JSExport`.
- **Type parameters in external APIs**:
  Type parameters must now be bound to a static interop type or one of the
  `dart:js_interop` types like `JSNumber` when used in an external API. This
  only affects `dart:js_interop` classes and not `package:js` or other forms of
  JS interop.
- **Subtyping `dart:js_interop` types**:
  `@staticInterop` types can subtype only `JSObject` and `JSAny` from the set of
  JS types in `dart:js_interop`. Subtyping other types from `dart:js_interop`
  would result in confusing type errors before, so this makes it a static error.
- **Global context of `dart:js_interop` and `@staticInterop` APIs**:
  Static interop APIs will now use the same global context as non-static interop
  instead of `globalThis` to avoid a greater migration. Static interop APIs,
  either through `dart:js_interop` or the `@staticInterop` annotation, have used
  JavaScript's `globalThis` as the global context. This is relevant to things
  like external top-level members or external constructors, as this is the root
  context we expect those members to reside in. Historically, this was not the
  case in dart2js and DDC. We used either `self` or DDC's `global` in non-static
  interop APIs with `package:js`. So, static interop APIs will now use one of
  those global contexts. Functionally, this should matter in only a very small
  number of cases, like when using older browser versions. `dart:js_interop`'s
  `globalJSObject` is also renamed to `globalContext` and returns the global
  context used in the lowerings.
- **Breaking Change on Types of `dart:js_interop` External APIs**:
  External JS interop APIs when using `dart:js_interop` are restricted to a set
  of allowed types. Namely, this includes the primitive types like `String`, JS
  types from `dart:js_interop`, and other static interop types (either through
  `@staticInterop` or extension types).
- **Breaking Change on `dart:js_interop` `isNull` and `isUndefined`**:
  `null` and `undefined` can only be discerned in the JS backends. dart2wasm
  conflates the two values and treats them both as Dart null. Therefore, these
  two helper methods should not be used on dart2wasm and will throw to avoid
  potentially erroneous code.
- **Breaking Change on `dart:js_interop` `typeofEquals` and `instanceof`**:
  Both APIs now return a `bool` instead of a `JSBoolean`. `typeofEquals` also
  now takes in a `String` instead of a `JSString`.
- **Breaking Change on `dart:js_interop` `JSAny` and `JSObject`**:
  These types can only be implemented, and no longer extended, by user
  `@staticInterop` types.
- **Breaking Change on `dart:js_interop` `JSArray.withLength`**:
  This API now takes in an `int` instead of `JSNumber`.

### Tools

#### Development JavaScript compiler (DDC)

- Applications compiled by DDC will no longer add members to the native
  JavaScript Object prototype.
- **Breaking change for JS interop with Symbols and BigInts**:
  JavaScript `Symbol`s and `BigInt`s are now associated with their own
  interceptor and should not be used with `package:js` classes. These types were
  being intercepted with the assumption that they are a subtype of JavaScript's
  `Object`, but this is incorrect. This lead to erroneous behavior when using
  these types as Dart `Object`s. See [#53106][] for more details. Use
  `dart:js_interop`'s `JSSymbol` and `JSBigInt` with extension types to interop
  with these types.

#### Production JavaScript compiler (dart2js)

- **Breaking change for JS interop with Symbols and BigInts**:
  JavaScript `Symbol`s and `BigInt`s are now associated with their own
  interceptor and should not be used with `package:js` classes. These types were
  being intercepted with the assumption that they are a subtype of JavaScript's
  `Object`, but this is incorrect. This lead to erroneous behavior when using
  these types as Dart `Object`s. See [#53106][] for more details. Use
  `dart:js_interop`'s `JSSymbol` and `JSBigInt` with extension types to interop
  with these types.

[#53106]: https://github.com/dart-lang/sdk/issues/53106

#### Dart command line

- The `dart create` command has a new `cli` template
  to quickly create Dart command-line applications
  with basic argument parsing capabilities.
  To learn more about using the template,
  run `dart help create`.

#### Dart format

- Always split enum declarations containing a line comment.
- Fix regression in splitting type annotations with library prefixes.
- Support `--enable-experiment` command-line option to enable language
  experiments.

#### DevTools

- Incorporated the [2.26.1][devtools-2-26-1], [2.27.0][devtools-2-27-0], and
  [2.28.1][devtools-2-28-1] releases of DevTools.

[devtools-2-26-1]: https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.26.1
[devtools-2-27-0]: https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.27.0
[devtools-2-28-1]: https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.28.1

#### Linter

- Added the experimental [`annotate_redeclares`][] lint.
- Marked the [`use_build_context_synchronously`][] lint as stable.

[`annotate_redeclares`]: https://dart.dev/lints/annotate_redeclares
[`use_build_context_synchronously`]: https://dart.dev/lints/use_build_context_synchronously

#### Pub

- New option `dart pub upgrade --tighten` which will update dependencies' lower
  bounds in `pubspec.yaml` to match the current version.
- The commands `dart pub get`/`add`/`upgrade` will now show if a dependency
  changed between direct, dev and transitive dependency.
- The command `dart pub upgrade` no longer shows unchanged dependencies.
