# Dart SDK 3.9.4

## 3.9.4

**Released on:** 2025-09-30

#### Pub

- `dart pub get --example` will now resolve `example/` folders in the
  entire workspace, not only in the root package.
  This fixes [dart-lang/pub#4674][] that made `flutter pub get`
  crash if the examples had not been resolved before resolving the workspace.

[dart-lang/pub#4674]: https://github.com/dart-lang/pub/issues/4674
