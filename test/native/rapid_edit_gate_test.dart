/// Tests the in-flux rapid-edit gate on [SaropaLintRule].
///
/// While the interactive analysis server rapidly re-analyzes a file being
/// edited (3+ passes within 2s), the gate defers ALL saropa_lints rules until
/// edits settle. It stays inert in batch/CLI runs so those report every rule at
/// full fidelity.
///
/// Bug: plans/history/2026.07/2026.07.10/infra_native_plugin_full_tier_runs_on_files_in_flux.md
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

void main() {
  group('SaropaLintRule.deferForRapidEdit', () {
    setUp(() {
      // Simulate the interactive server, which arms the gate in Plugin.start().
      SaropaLintRule.isAnalysisServer = true;
    });

    tearDown(() {
      // Reset the shared flag so it never leaks into other test files.
      SaropaLintRule.isAnalysisServer = false;
    });

    // Distinct unit ids stand in for distinct analysis passes: each new id
    // records one edit timestamp (dedup is keyed on the id), so three distinct
    // ids in one synchronous test are three passes inside the 2s window.
    String uniquePath(String tag) =>
        '/tmp/rapid_$tag${DateTime.now().microsecondsSinceEpoch}.dart';

    test('defers only after the rapid threshold (3 passes in 2s)', () {
      final path = uniquePath('defer_');

      // Passes 1 and 2 are below the 3-in-2s threshold — nothing deferred yet.
      expect(SaropaLintRule.deferForRapidEdit(path, 1), isFalse);
      expect(SaropaLintRule.deferForRapidEdit(path, 2), isFalse);

      // Pass 3 within the window trips rapid mode: every rule is deferred (the
      // gate is rule-independent — no essential carve-out).
      expect(SaropaLintRule.deferForRapidEdit(path, 3), isTrue);
    });

    test('inert in batch/CLI runs (isAnalysisServer false) — full fidelity', () {
      SaropaLintRule.isAnalysisServer = false;
      final path = uniquePath('batch_');

      // Even far past the threshold, batch runs never defer a rule.
      for (var pass = 0; pass < 10; pass++) {
        expect(SaropaLintRule.deferForRapidEdit(path, pass), isFalse);
      }
    });

    test('empty path never defers (no resolvable file)', () {
      expect(SaropaLintRule.deferForRapidEdit('', 1), isFalse);
    });
  });
}
