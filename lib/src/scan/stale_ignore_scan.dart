/// Runs the scan the stale-ignore modes need: every finding reported (none
/// hidden by a comment, baseline or cap) plus a record of what was covered.
library;

import 'scan_diagnostic.dart';
import 'scan_runner.dart';
import 'stale_ignore_probe.dart';

/// Diagnostics and coverage from [runStaleIgnoreScan].
class StaleIgnoreScan {
  const StaleIgnoreScan(this.diagnostics, this.coverage);

  /// Every finding, including ones a `// ignore:` would normally hide.
  final List<ScanDiagnostic> diagnostics;

  /// What the scan positively covered; pass to `detectStaleIgnores`.
  final StaleIgnoreCoverage coverage;
}

/// Scans with [runner] in this process with the [StaleIgnoreProbe] armed.
///
/// Always in-process: the probe and the coverage records are process-wide,
/// and worker isolates would not share them. [resolve] defaults to true, the
/// same reason `--check-accepted` resolves: a type-based rule does not fire
/// in a syntactic scan, so every comment for it would look stale. Returns
/// null under the same conditions as [ScanRunner.run] (no config, bad tier).
Future<StaleIgnoreScan?> runStaleIgnoreScan(
  ScanRunner runner, {
  bool resolve = true,
}) async {
  StaleIgnoreProbe.start();
  try {
    final diagnostics = resolve ? await runner.runResolved() : runner.run();
    if (diagnostics == null) return null;
    final records = StaleIgnoreProbe.snapshot();
    return StaleIgnoreScan(
      diagnostics,
      StaleIgnoreCoverage(
        rulesRun: runner.registeredRuleNames,
        filesWalked: runner.walkedFiles,
        ruleFileFailures: runner.ruleFileFailures,
        commentHidden: records.hidden,
        unlocatedRules: records.unlocated,
      ),
    );
  } finally {
    // Never leave the reporter in report-everything mode for a later scan
    // in the same process (daemon, tests).
    StaleIgnoreProbe.stop();
  }
}
