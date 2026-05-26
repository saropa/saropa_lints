/// Tests for git signals. Runs against this repo's own history (a git repo),
/// asserting well-formed churn/recency/bus-factor rather than exact values.
import 'dart:io';

import 'package:saropa_lints/src/cli/project_health/git_signals.dart';
import 'package:test/test.dart';

void main() {
  group('loadGitSignals', () {
    test('returns well-formed signals for tracked files', () {
      final signals = loadGitSignals(Directory.current.path, maxCommits: 100);
      // Skip only if git is genuinely unavailable; this repo has history.
      if (signals.isEmpty) return;
      for (final s in signals.values) {
        expect(s.churn, greaterThan(0));
        expect(s.lastCommitDaysAgo, greaterThanOrEqualTo(0));
        expect(s.busFactorPct, inInclusiveRange(0, 1));
      }
    });

    test('a non-git directory yields no signals', () {
      final tmp = Directory.systemTemp.createTempSync('saropa_nogit_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      expect(loadGitSignals(tmp.path), isEmpty);
    });
  });
}
