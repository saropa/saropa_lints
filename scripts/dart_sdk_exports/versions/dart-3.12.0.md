# Dart SDK 3.12.0

## 3.12.0

**Released on:** Unreleased

### Language

#### Private named parameters

Dart now supports [private named parameters][]. Before 3.12, it was an error to
have a named parameter that starts with an underscore:

[private named parameters]: https://github.com/dart-lang/language/blob/main/accepted/future-releases/2509-private-named-parameters/feature-specification.md

```dart
class Point {
  final int _x, _y;
  // Compile error in Dart 3.11.
  Point({required this._x, required this._y});
}
```

That means that when you wanted to initialize a *private* field from a named
parameter, you had to write an explicit initializer list:

```dart
class Point {
  final int _x, _y;
  Point({required int x, required int y})
    : x = _x,
      y = _y;
}
```

All the initializer list is doing is scraping off the `_`. In Dart 3.12, the
language will do that for you. Now you can write:

```dart
class Point {
  final int _x, _y; // Private fields.
  Point({required this._x, required this._y});
}
```

It behaves exactly like the previous example. The initialized fields are
private, but the argument names written at the call site are public:

```dart
main() {
  print(Point(x: 1, y: 2));
}
```

### Tools

#### Pub

- `dart pub cache repair` now by default only repairs the packages referenced
  by the current projects pubspec.lock. For the old behavior of repairing all
  packages use the `--all` flag.

#### dart2wasm

- Updated deferred loading module loader API to allow batched fetching of
  deferred modules. The embedder now takes `loadDeferredModules` instead of
  `loadDeferredModule` where the new function should now expect an array of
  module names rather than individual module names. All the module loading
  functions must now also accept an `instantiator` callback to which they
  should pass the loaded results.

### Libraries

#### `dart:js_interop`

- **Breaking Change in extension name of `isA`**: `isA` is moved from
  `JSAnyUtilityExtension` to `NullableObjectUtilExtension` to support
  type-checking any `Object?`. `isA<JSObject>()` also now handles JS objects
  with no prototypes correctly and `isA<JSAny>()` does a non-trivial check to
  make sure the value is a JS value. See [#56905][] for more details. As
  `JSAnyUtilityExtension` is on `JSAny?` and `NullableObjectUtilExtension` is on
  the supertype `Object?`, this change is only breaking if users referred to the
  extension name directly, either through applying the extension directly or
  through using `show`/`hide` directives.

[#56905]: https://github.com/dart-lang/sdk/issues/56905
