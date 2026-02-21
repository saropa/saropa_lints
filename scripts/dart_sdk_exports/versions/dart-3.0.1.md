# Dart SDK 3.0.1

## 3.0.1

- 2023-05-17

This is a patch release that:

- Fixes a compiler crash involving redirecting factories and FFI
  (issue [#124369]).
- Fixes a dart2js crash when using a combination of local functions, generics,
  and records (issue [#51899]).
- Fixes incorrect error using a `void` in a switch case expression
  (issue [#52191]).
- Fixes a false error when using in switch case expressions when the switch
  refers to a private getter (issue [#52041]).
- Prevent the use of `when` and `as` as variable names in patterns
  (issue [#52260]).
- Fixes an inconsistency in type promotion between the analyzer and VM
  (issue [#52241]).
- Improve performance on functions with many parameters (issue [#1212]).

[#124369]: https://github.com/flutter/flutter/issues/124369
[#51899]: https://github.com/dart-lang/sdk/issues/51899
[#52191]: https://github.com/dart-lang/sdk/issues/52191
[#52041]: https://github.com/dart-lang/sdk/issues/52041
[#52260]: https://github.com/dart-lang/sdk/issues/52260
[#52241]: https://github.com/dart-lang/sdk/issues/52241
[#1212]: https://github.com/dart-lang/dart_style/issues/1212
