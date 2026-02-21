# Dart SDK 3.0.2

## 3.0.2

- 2023-05-24

This is a patch release that:

- Fixes a dart2js crash when using a switch case expression on a record where
  the fields don't match the cases (issue [#52438]).
- Add class modifier chips on class and mixin pages
  generated with `dart doc` (issue [#3392]).
- Fixes a situation causing the parser to fail resulting in an infinite loop
  leading to higher memory usage (issue [#52352]).
- Add clear errors when mixing inheritance in pre and post Dart 3 libraries
  (issue: [#52078]).

[#52438]: https://github.com/dart-lang/sdk/issues/52438
[#3392]: https://github.com/dart-lang/dartdoc/issues/3392
[#52352]: https://github.com/dart-lang/sdk/issues/52352
[#52078]: https://github.com/dart-lang/sdk/issues/52078
