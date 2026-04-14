/**
 * Flutter/Dart SDK packages that ship with the SDK and should not be
 * looked up on pub.dev. These use `sdk: flutter` or `sdk: dart` in
 * pubspec.yaml and have `source: sdk` in pubspec.lock.
 *
 * Centralized here because multiple features (adoption gate, annotate
 * command, unused-detector, pubspec sorter) need to skip them.
 */
export const SDK_PACKAGES = new Set([
    'flutter',
    'flutter_driver',
    'flutter_localizations',
    'flutter_test',
    'flutter_web_plugins',
    'integration_test',
]);
