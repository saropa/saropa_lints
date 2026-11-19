/// Tests for `audit`'s exit code under `--baseline`.
///
/// With a loaded baseline only new findings fail the run, which is what lets
/// a CI gate accept a known backlog (the composite action's `baseline`
/// input). Without one, every finding counts, so a missing or mistyped
/// baseline cannot quietly pass a gate.
library;

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../../bin/audit.dart' show auditExitCode;

void main() {
  test('no baseline: any finding fails', () {
    expect(auditExitCode(findings: 0), 0);
    expect(auditExitCode(findings: 3), 1);
  });

  test('baseline loaded: only new findings fail', () {
    expect(auditExitCode(findings: 12, newSinceBaseline: 0), 0);
    expect(auditExitCode(findings: 12, newSinceBaseline: 1), 1);
    expect(auditExitCode(findings: 0, newSinceBaseline: 0), 0);
  });
}
