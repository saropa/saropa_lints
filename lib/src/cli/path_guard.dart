/// Shared path-sanitization utility for CLI entry points.
///
/// Normalizes a user-supplied path and rejects any that still contain
/// parent-directory (`..`) segments after normalization — those are the
/// only dangerous ones (`p.normalize` resolves embedded `../` pairs).
library;

import 'package:path/path.dart' as p;

/// Normalizes [path] and throws [ArgumentError] if it escapes upward.
///
/// Call at the boundary where a CLI argument or external input first
/// enters the program, before any `File()` or `Directory()` construction.
///
/// Callers with a legitimate need for `../` in their input (e.g. pointing
/// at a sibling project) must resolve to an absolute path *before* calling
/// this function — `p.absolute()` or `Directory(x).resolveSymbolicLinksSync()`
/// will eliminate the `..` segments that this guard rejects.
///
/// **Limitation:** this does not resolve symlinks. A symlink whose target
/// lies outside the intended directory will pass. For symlink-safe
/// containment, resolve with `resolveSymbolicLinksSync()` first.
String sanitizePath(String path, {String label = 'path'}) {
  final normalized = p.normalize(path);
  // Only leading ".." segments survive normalization — exactly the
  // ones that escape the intended directory.
  if (p.split(normalized).contains('..')) {
    throw ArgumentError('$label must not contain ".." segments: $normalized');
  }
  return normalized;
}
