// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: unnecessary_null_comparison, dead_code
// ignore_for_file: parameter_assignments

/// Fixture for `avoid_case_sensitive_path_comparison` lint rule.
///
/// Uses `// LINT:` and `// LINT_NOT:` markers for machine-verified assertions
/// via `assertFixtureMarkers` + `runRuleResolved`.

import 'dart:io';

// --- BAD: case-sensitive string-to-string path comparisons ---

/// Direct path variable comparison without case normalization.
void badStringComparison(String filePath, String otherPath) {
  // LINT: avoid_case_sensitive_path_comparison
  if (filePath == otherPath) {}
}

/// Not-equal string-to-string path comparison.
void badNotEqualComparison(String dirPath, String expected) {
  // LINT: avoid_case_sensitive_path_comparison
  if (dirPath != expected) {}
}

// --- GOOD: null checks on path variables are NOT path comparisons ---

/// Null equality check — this is a nullability guard, not a case comparison.
void goodNullCheck(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePathUrl == null) return;
}

/// Reversed null equality check.
void goodNullCheckReversed(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (null == filePathUrl) return;
}

/// Not-null check.
void goodNotNullCheck(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePathUrl != null) {
    // use it
  }
}

/// Reversed not-null check.
void goodNotNullCheckReversed(String? filePathUrl) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (null != filePathUrl) {
    // use it
  }
}

// --- GOOD: non-string comparisons on path variables ---

/// Integer comparison — not a string comparison.
void goodIntegerComparison(int pathIndex) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (pathIndex == 0) return;
}

/// Boolean comparison — not a string comparison.
void goodBooleanComparison(bool isPathValid) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (isPathValid == true) return;
}

/// Double comparison — not a string comparison.
void goodDoubleComparison(double pathLength) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (pathLength == 0.0) return;
}

/// Enum comparison — not a string comparison.
enum PathType { absolute, relative }

void goodEnumComparison(PathType dirPathType) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (dirPathType == PathType.absolute) return;
}

// --- GOOD: already using case normalization ---

/// toLowerCase() applied — no lint.
void goodWithLowerCase(String filePath, String otherPath) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePath.toLowerCase() == otherPath.toLowerCase()) {}
}

/// toUpperCase() applied — no lint.
void goodWithUpperCase(String filePath, String otherPath) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (filePath.toUpperCase() == otherPath.toUpperCase()) {}
}

// --- GOOD: root-detection idiom — both sides come from the same
// Directory API call so casing is always consistent (standard Dart
// filesystem-root traversal test). ---

/// `dir.path != dir.parent.path` — walks up to the filesystem root.
void goodRootDetectionIdiom(_FakeDirectory dir) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  while (dir.path != dir.parent.path) {
    dir = dir.parent;
  }
}

/// Reversed root-detection idiom — same idiom, operands swapped.
void goodRootDetectionIdiomReversed(_FakeDirectory dir) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (dir.parent.path == dir.path) {
    return;
  }
}

/// Mismatched base expressions — `a.path == b.parent.path` is NOT the
/// root-detection idiom because `a` and `b` are different variables.
/// Casing consistency is not guaranteed across different directories.
void badMismatchedRootDetection(_FakeDirectory a, _FakeDirectory b) {
  // LINT: avoid_case_sensitive_path_comparison
  if (a.path == b.parent.path) {}
}

/// Reversed mismatched base — `b.parent.path == a.path` is equally wrong.
void badMismatchedRootDetectionReversed(_FakeDirectory a, _FakeDirectory b) {
  // LINT: avoid_case_sensitive_path_comparison
  if (b.parent.path == a.path) {}
}

class _FakeDirectory {
  _FakeDirectory(this.path, this.parent);
  final String path;
  final _FakeDirectory parent;
}

// --- GOOD: string literal without a path separator is a CLI flag or
// label, not a filesystem path — the word "path" in the name (e.g.
// '--json-file-path') must not trigger the heuristic. ---

/// CLI flag comparison — literal has no '/' or '\\', so it is not a path.
void goodCliFlagComparison(String arg) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (arg == '--json-file-path') {}
}

// --- GOOD: Dart import URI comparison — import specifiers are
// case-sensitive by language spec, so this is not a filesystem path
// comparison that needs case normalization. ---

/// Import URI comparison — case sensitivity here is correct as-is.
void goodImportUriComparison(String namedUri, String pathFirst) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (namedUri == pathFirst) {}
}

/// Import URI comparison via an abbreviated for-each loop variable
/// ('imp') that doesn't itself carry "import"/"uri" in its name — the
/// guard falls back to inspecting the loop's iterable expression.
void goodImportUriComparisonLoopVariable(
  List<String> imports,
  String? pathFirst,
) {
  for (final imp in imports) {
    // LINT_NOT: avoid_case_sensitive_path_comparison
    if (pathFirst != null && imp == pathFirst) {}
  }
}

// --- GOOD: "path" embedded inside an unrelated word must not trigger
// the heuristic — only a standalone camelCase "path"/"Path" word
// component counts (see _hasPathAsWord). ---

/// "pathology"/"empathy" are unrelated words that happen to contain the
/// substring "path" — this is a plain string comparison, not a path
/// comparison, so it must not lint even though both sides are strings.
void goodUnrelatedWordContainingPath(
  String pathologyReport,
  String empathyNote,
) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (pathologyReport == empathyNote) {}
}

// --- GOOD: root-detection idiom via an intermediate `.parent` local —
// the `.parent` hop is factored into a named variable (as it must be when
// the loop also reassigns `dir = parent;` on the next line), so the
// exemption has to trace back through that single assignment instead of
// matching `.parent.path` as a literal source-text suffix. ---

/// Two-statement root-walk idiom: `parent` is assigned from `dir.parent`
/// one statement earlier, then compared via `.path` against `dir.path`.
void goodRootDetectionIdiomViaVariable(_FakeDirectory dir) {
  while (true) {
    final parent = dir.parent;
    // LINT_NOT: avoid_case_sensitive_path_comparison
    if (parent.path == dir.path) break;
    dir = parent;
  }
}

// --- GOOD: HTTP request-target path (`HttpRequest.uri.path`) compared to
// a route constant — case-sensitive by specification, not a filesystem
// path, even though the local variable is conventionally named "path".
// Identified via `HttpRequest`'s declaring library (dart:io), not by a
// bare `Uri`-typed parameter — see the BAD leak cases below for why a
// bare `Uri` alone can't be trusted. ---

/// Direct `HttpRequest.uri.path` access compared inline — the real shape
/// used throughout the reporting project's router (`req.uri.path == ...`).
void goodHttpRoutePathDirect(HttpRequest request) {
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (request.uri.path == '/api/health') {}
}

/// `HttpRequest.uri.path` stored in a local variable before comparison —
/// the shape that appears in real routers
/// (`final String path = request.uri.path;`).
void goodHttpRoutePath(HttpRequest request) {
  final String path = request.uri.path;
  // LINT_NOT: avoid_case_sensitive_path_comparison
  if (path == '/api/health') {}
}

// --- BAD: an arbitrary `Uri.path` is still a filesystem path, not an HTTP
// request path — the HTTP-Uri exemption must be narrow (traceably from an
// HTTP request object), not a blanket exemption for every `Uri`. ---

/// `Platform.script` is the running script file's `Uri` — a filesystem
/// path, not a request path, even though it's `Uri`-typed.
void badPlatformScriptPath(String expectedPath) {
  // LINT: avoid_case_sensitive_path_comparison
  if (Platform.script.path == expectedPath) {}
}

/// `File(...).uri.path` — the `.uri` receiver's static type is `File`, not
/// an HTTP request type, so this must not be exempted.
void badFileUriPath(File a, File b) {
  // LINT: avoid_case_sensitive_path_comparison
  if (a.uri.path == b.path) {}
}

// --- BAD: tracing through a reassignable (`var`) local, or through a
// `final` local whose captured base was itself reassigned afterward, is
// unsound — the initializer captured at declaration time may no longer
// describe the value at the comparison, so neither exemption may apply. ---

/// `parent` is declared with `var` and reassigned before use — the
/// root-detection exemption must not trust the stale `dir.parent`
/// initializer.
void badMutableParentReassigned(_FakeDirectory dir, _FakeDirectory other) {
  var parent = dir.parent;
  parent = other;
  // LINT: avoid_case_sensitive_path_comparison
  if (parent.path == dir.path) {}
}

/// `path` is declared with `var` and reassigned to a filesystem path
/// (`file.path`) before use — the Uri-path exemption must not trust the
/// stale `u.path` initializer.
void badMutablePathReassigned(Uri u, File file, String expectedPath) {
  var path = u.path;
  path = file.path;
  // LINT: avoid_case_sensitive_path_comparison
  if (path == expectedPath) {}
}

/// `parent` is `final`, but the base `dir` it was captured from is
/// reassigned afterward — the cached `parent` no longer corresponds to the
/// current `dir`, so the exemption must not apply.
void badParentBaseReassignedAfterCapture(
  _FakeDirectory dir,
  _FakeDirectory other,
) {
  final parent = dir.parent;
  dir = other;
  // LINT: avoid_case_sensitive_path_comparison
  if (parent.path == dir.path) {}
}

/// Mismatched base via an intermediate variable — `parent` is `b.parent`,
/// compared against `a.path`; `a` and `b` are different directories, so
/// this is NOT the root-detection idiom even through the indirection.
void badMismatchedRootDetectionViaVariable(_FakeDirectory a, _FakeDirectory b) {
  final parent = b.parent;
  // LINT: avoid_case_sensitive_path_comparison
  if (parent.path == a.path) {}
}

// --- BAD: a bare `Uri`-typed parameter or local is NOT, on its own,
// evidence of an HTTP request — nothing distinguishes it from a `Uri`
// built off a filesystem path. Only a chain through a real
// `HttpRequest`/shelf `Request` receiver's `.uri`/`.requestedUri`/`.url`
// is exempted (see the GOOD `HttpRequest` cases above). ---

/// A bare `Uri`-typed parameter compared directly — could just as easily
/// be `File(...).uri` or `Platform.script`, so it must not be exempted.
void badBareUriParameterPath(Uri fileUri, String expectedPath) {
  // LINT: avoid_case_sensitive_path_comparison
  if (fileUri.path == expectedPath) {}
}

/// Same leak, through a `final` local — tracing back to the initializer
/// still lands on a bare `Uri` parameter, which is not sufficient.
void badBareUriParameterPathViaLocal(Uri fileUri, String expectedPath) {
  final String path = fileUri.path;
  // LINT: avoid_case_sensitive_path_comparison
  if (path == expectedPath) {}
}

// --- BAD: the HTTP-request receiver check must be library-scoped, not
// name-scoped — a user-defined class whose name merely ends with
// "Request" (or is even literally named "Request") is not a real
// `HttpRequest`/shelf `Request`. ---

/// `UploadRequest` is a user-defined class, not dart:io's `HttpRequest` or
/// shelf's `Request` — its `.uri.path` must not be exempted even though
/// the class name ends with "Request".
class UploadRequest {
  UploadRequest(this.uri);
  final Uri uri;
}

void badUploadRequestUriPath(UploadRequest r, File f) {
  // LINT: avoid_case_sensitive_path_comparison
  if (r.uri.path == f.path) {}
}

// --- Total count assertion: exactly 13 BAD sites should fire ---
// LINT_COUNT: avoid_case_sensitive_path_comparison 13

void main() {}
