# Dart SDK 3.3.2

## 3.3.2

- 2024-03-20

This is a patch release that:

- Fixes an issue in the CFE that placed some structural parameter references out
  of their context in the code restored from dill files, causing crashes in the
  incremental compiler whenever it restored a typedef from dill such that the
  typedef contained a generic function type on its right-hand side (issue
  [#55158][]).
- Fixes an issue in the CFE that prevented redirecting factories from being
  resolved in initializers of extension types (issue [#55194][]).
- Fixes an issues with VM's implementation of `DateTime.timeZoneName`
  on Windows, which was checking whether current date is in the summer or
  standard time rather than checking if the given moment is in the summer or
  standard time (issue [#55240][]).

[#55158]: https://github.com/dart-lang/sdk/issues/55158
[#55194]: https://github.com/dart-lang/sdk/issues/55194
[#55240]: https://github.com/dart-lang/sdk/issues/55240
