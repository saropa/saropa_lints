/// Utilities for detecting Flutter mode constants in source code.
///
/// Flutter provides three compile-time constants for conditional code:
/// - `kReleaseMode` - true in release builds
/// - `kDebugMode` - true in debug builds
/// - `kProfileMode` - true in profile builds
///
/// Code that uses these constants is considered "properly conditional" because
/// it intentionally handles different build modes. Rules that detect mixed
/// environments or debug-only code should skip such expressions.
library;

/// Check if source code uses Flutter's mode constants for conditional logic.
///
/// Returns `true` if the source contains any of:
/// - `kReleaseMode`
/// - `kDebugMode`
/// - `kProfileMode`
///
/// This is a fast string-based check suitable for early exit before
/// more expensive AST analysis.
///
/// Example usage:
/// ```dart
/// final source = init.toSource();
/// if (usesFlutterModeConstants(source)) {
///   // Skip this field - it's properly conditional
///   return;
/// }
/// ```
bool usesFlutterModeConstants(String source) =>
    source.contains('kReleaseMode') ||
    source.contains('kDebugMode') ||
    source.contains('kProfileMode');

/// The set of Flutter mode constant names.
///
/// Useful for more precise matching when needed:
/// ```dart
/// for (final constant in flutterModeConstants) {
///   if (source.contains(constant)) { ... }
/// }
/// ```
const Set<String> flutterModeConstants = <String>{
  'kReleaseMode',
  'kDebugMode',
  'kProfileMode',
};
