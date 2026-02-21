# Dart SDK 3.1.2

## 3.1.2

- 2023-09-13

This is a patch release that:

- Fixes a bug in dart2js which crashed the compiler when a typed record pattern
  was used outside the scope of a function body, such as in a field initializer.
  For example `final x = { for (var (int a,) in someList) a: a };`
  (issue [#53449])

- Fixes an expedient issue of users seeing an unhandled
  exception pause in the debugger, please see
  https://github.com/dart-lang/sdk/issues/53450 for more
  details.
  The fix uses try/catch in lookupAddresses instead of
  Future error so that we don't see an unhandled exception
  pause in the debugger (issue [#53450])

[#53449]: https://github.com/dart-lang/sdk/issues/53449
[#53450]: https://github.com/dart-lang/sdk/issues/53450
