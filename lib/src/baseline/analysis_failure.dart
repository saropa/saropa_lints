/// Detection of `dart analyze` execution failures for the baseline generator.
///
/// The baseline command treats an empty violation set as "clean codebase, no
/// baseline needed". That is only safe when analysis actually completed. When
/// the analysis server (or one of its plugins) crashes, it emits no parseable
/// violation lines, so the empty result is indistinguishable from a genuinely
/// clean run unless we inspect the process exit state and output. Without this
/// guard the tool would print a false success and ship an empty baseline over
/// an unchecked codebase (issue #269).
library;

/// Signatures that only appear when the analysis server (or one of its
/// plugins) crashed rather than completing a normal analysis pass. Matched
/// case-insensitively against the combined stdout + stderr.
///
/// The canonical trigger (issue #269) is an analyzer plugin whose entry point
/// uses native build hooks: `dart compile` cannot AOT-snapshot it, so the
/// plugin manager throws and the analyzer returns an empty, invalid dataset.
const List<String> fatalAnalyzerSignatures = [
  'an error occurred while executing an analyzer plugin',
  'failed to compile',
  'to an aot snapshot',
  'does not support build hooks',
];

/// Returns a human-readable reason when a `dart analyze` invocation should be
/// treated as a hard execution failure, or `null` when analysis completed
/// normally (whether or not it found violations).
///
/// Two independent failure modes are detected:
///  1. A known fatal signature in the analyzer output — an unambiguous crash.
///  2. A non-zero exit code paired with zero parsed violations — the analyzer
///     did not exit clean (exit 0) yet produced nothing we could parse, so it
///     did not actually finish. A genuinely clean codebase exits 0 and is not
///     a failure; a codebase with real violations parses at least one line
///     even when the exit code is non-zero.
String? detectAnalysisFailure({
  required int exitCode,
  required int parsedViolationCount,
  required String stdout,
  required String stderr,
}) {
  final haystack = '$stdout\n$stderr'.toLowerCase();
  for (final signature in fatalAnalyzerSignatures) {
    if (haystack.contains(signature)) {
      return 'The analysis server reported a fatal error '
          '(matched: "$signature"). This usually means an analyzer plugin '
          'could not be compiled or loaded, so no violations were collected.';
    }
  }

  // A clean run exits 0. A run with real violations parses at least one line
  // even when the exit code is non-zero. An empty parse with a non-zero exit
  // therefore means analysis aborted before reporting anything.
  if (exitCode != 0 && parsedViolationCount == 0) {
    return 'dart analyze exited with code $exitCode and produced no parseable '
        'output. Analysis did not complete, so the empty result cannot be '
        'trusted as a clean codebase.';
  }

  return null;
}
