# Dart SDK 3.1.3

## 3.1.3

- 2023-09-27

This is a patch release that:

- Fixes a bug in dart2js which would cause the compiler to crash when using
  `@staticInterop` `@anonymous` factory constructors with type parameters (see
  issue [#53579] for more details).

- The standalone Dart VM now exports symbols only for the Dart_* embedding API
  functions, avoiding conflicts with other DSOs loaded into the same process,
  such as shared libraries loaded through `dart:ffi`, that may have different
  versions of the same symbols (issue [#53503]).

- Fixes an issue with super slow access to variables while debugging.
  The fix avoids searching static functions in the imported libraries
  as references to members are fully resolved by the front-end. (issue
  [#53541])

[#53579]: https://github.com/dart-lang/sdk/issues/53579
[#53267]: https://github.com/dart-lang/sdk/issues/53503
[#53541]: https://github.com/dart-lang/sdk/issues/53541
