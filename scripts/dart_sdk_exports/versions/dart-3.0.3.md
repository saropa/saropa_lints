# Dart SDK 3.0.3

## 3.0.3

- 2023-02-07

This is a patch release that:

- Fixes an AOT compiler crash when generating an implicit getter
  returning an unboxed record (issue [#52449]).
- Fixes a situation in which variables appearing in multiple branches of an
  or-pattern might be erroneously reported as being mismatched (issue [#52373]).
- Adds missing `interface` modifiers on the purely abstract classes
  `MultiStreamController`, `StreamConsumer`, `StreamIterator` and
  `StreamTransformer` (issue [#52334]).
- Fixes an error during debugging when `InternetAddress.tryParse` is
  used (issue [#52423]).
- Fixes a VM issue causing crashes on hot reload (issue [#126884]).
- Improves linter support (issue [#4195]).
- Fixes an issue in variable patterns preventing users from expressing
  a pattern match using a variable or wildcard pattern with a nullable
  record type (issue [#52439]).
- Updates warnings and provide instructions for updating the Dart pub
  cache on Windows (issue [#52386]).

[#52373]: https://github.com/dart-lang/sdk/issues/52373
[#52334]: https://github.com/dart-lang/sdk/issues/52334
[#52423]: https://github.com/dart-lang/sdk/issues/52423
[#126884]: https://github.com/flutter/flutter/issues/126884
[#4195]: https://github.com/dart-lang/linter/issues/4195
[#52439]: https://github.com/dart-lang/sdk/issues/52439
[#52449]: https://github.com/dart-lang/sdk/issues/52449
[#52386]: https://github.com/dart-lang/sdk/issues/52386
