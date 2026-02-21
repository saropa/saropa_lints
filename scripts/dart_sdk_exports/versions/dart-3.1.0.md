# Dart SDK 3.1.0

## 3.1.0

- 2023-08-16

### Libraries

#### `dart:async`

- **Breaking change** [#52334][]:
  - Added the `interface` modifier to purely abstract classes:
    `MultiStreamController`, `StreamConsumer`, `StreamIterator` and
    `StreamTransformer`. As a result, these types can only be implemented,
    not extended or mixed in.

[#52334]: https://github.com/dart-lang/sdk/issues/52334

#### `dart:core`

- `Uri.base` on native platforms now respects `IOOverrides` overriding
   current directory ([#39796][]).

[#39796]: https://github.com/dart-lang/sdk/issues/39796

#### `dart:ffi`

- Added the `NativeCallable` class, which can be used to create callbacks that
  allow native code to call into Dart code from any thread. See
  `NativeCallable.listener`. In future releases, `NativeCallable` will be
  updated with more functionality, and will become the recommended way of
  creating native callbacks for all use cases, replacing `Pointer.fromFunction`.

#### `dart:io`

- **Breaking change** [#51486][]:
  - Added `sameSite` to the `Cookie` class.
  - Added class `SameSite`.
- **Breaking change** [#52027][]: `FileSystemEvent` is
  [`sealed`](https://dart.dev/language/class-modifiers#sealed). This means
  that `FileSystemEvent` cannot be extended or implemented.
- Added a deprecation warning when `Platform` is instantiated.
- Added `Platform.lineTerminator` which exposes the character or characters
  that the operating system uses to separate lines of text, e.g.,
  `"\r\n"` on Windows.

[#51486]: https://github.com/dart-lang/sdk/issues/51486
[#52027]: https://github.com/dart-lang/sdk/issues/52027

#### `dart:js_interop`

- **Object literal constructors**:
  `ObjectLiteral` is removed from `dart:js_interop`. It's no longer needed in
  order to declare an object literal constructor with inline classes. As long as
  an external constructor has at least one named parameter, it'll be treated as
  an object literal constructor. If you want to create an object literal with no
  named members, use `{}.jsify()`.

### Other libraries

#### `package:js`

- **Breaking change to `@staticInterop` and `external` extension members**:
  `external` `@staticInterop` members and `external` extension members can no
  longer be used as tear-offs. Declare a closure or a non-`external` method that
  calls these members, and use that instead.
- **Breaking change to `@staticInterop` and `external` extension members**:
  `external` `@staticInterop` members and `external` extension members will
  generate slightly different JS code for methods that have optional parameters.
  Whereas before, the JS code passed in the default value for missing optionals,
  it will now pass in only the provided members. This aligns with how JS
  parameters work, where omitted parameters are actually omitted. For example,
  calling `external void foo([int a, int b])` as `foo(0)` will now result in
  `foo(0)`, and not `foo(0, null)`.

### Tools

#### DevTools

- Incorporated the [2.24.0][devtools-2-24-0] and [2.25.0][devtools-2-25-0]
  releases of DevTools.

[devtools-2-24-0]: https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.24.0
[devtools-2-25-0]: https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.25.0

#### Linter

- Added new static analysis lints you can [enable][enable-lints] in
  your package's `analysis_options.yaml` file:
  - [`no_self_assignments`](https://dart.dev/lints/no_self_assignments)
  - [`no_wildcard_variable_uses`](https://dart.dev/lints/no_wildcard_variable_uses)

[enable-lints]: https://dart.dev/tools/analysis#enabling-linter-rules
