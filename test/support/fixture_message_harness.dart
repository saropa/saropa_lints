// Assertion helpers that validate `runRuleResolved` diagnostics against
// `// LINT:`, `// LINT_MESSAGE:`, `// LINT_NOT:`, and `// LINT_COUNT:` markers
// parsed from fixture source code.
//
// Combines the fixture marker parser with the resolved-analyzer harness to
// provide declarative, in-fixture validation — no explicit test code needed
// for each message variant, false-positive guard, or count assertion.
library;

import 'package:saropa_lints/saropa_lints.dart' show SaropaLintRule;
import 'package:test/test.dart';

import 'fixture_marker_parser.dart';
import 'resolved_rule_harness.dart';

/// Runs [rule] against [source] via [runRuleResolved] and validates all
/// fixture markers:
///
/// - `// LINT:` — diagnostic MUST fire on the target line.
/// - `// LINT_MESSAGE:` — diagnostic message must contain the substring.
/// - `// LINT_NOT:` — diagnostic must NOT fire on the target line.
/// - `// LINT_COUNT: rule N` — exactly N diagnostics from `rule` in total.
///
/// At least one marker of any kind must be present (guard against silent
/// no-op test sources).
Future<List<HarnessDiagnostic>> assertFixtureMarkers(
  SaropaLintRule rule,
  String source,
) async {
  final markers = parseFixtureMarkers(source);
  final negations = parseFixtureNegations(source);
  final counts = parseFixtureCounts(source);

  // Guard: caller passed source with no markers at all — likely a mistake.
  expect(
    markers.length + negations.length + counts.length,
    greaterThan(0),
    reason: 'Source contains no fixture markers to validate',
  );

  final diags = await runRuleResolved(rule, source);

  // Validate positive expectations: diagnostic MUST fire on the target line.
  for (final marker in markers) {
    final matching = diags
        .where(
          (d) => d.ruleName == marker.ruleName && d.line == marker.targetLine,
        )
        .toList();

    expect(
      matching,
      isNotEmpty,
      reason:
          '// LINT: ${marker.ruleName} expected diagnostic on line '
          '${marker.targetLine} but none found. '
          'Reported: ${diags.map((d) => '${d.ruleName}:${d.line}').join(', ')}',
    );

    // When a message substring is declared, assert it appears in the message.
    if (marker.messageSubstring != null) {
      expect(
        matching.first.message,
        contains(marker.messageSubstring),
        reason:
            '// LINT_MESSAGE: "${marker.messageSubstring}" not found in '
            'diagnostic message on line ${marker.targetLine}:\n'
            '"${matching.first.message}"',
      );
    }
  }

  // Validate negative expectations: diagnostic must NOT fire on the target line.
  for (final negation in negations) {
    final matching = diags
        .where(
          (d) =>
              d.ruleName == negation.ruleName && d.line == negation.targetLine,
        )
        .toList();

    expect(
      matching,
      isEmpty,
      reason:
          '// LINT_NOT: ${negation.ruleName} expected NO diagnostic on '
          'line ${negation.targetLine} but found: '
          '${matching.map((d) => '${d.ruleName}:${d.line}').join(', ')}',
    );
  }

  // Validate count expectations: exact number of diagnostics from the rule.
  for (final countMarker in counts) {
    final ruleCount = diags
        .where((d) => d.ruleName == countMarker.ruleName)
        .length;

    expect(
      ruleCount,
      countMarker.expectedCount,
      reason:
          '// LINT_COUNT: ${countMarker.ruleName} '
          '${countMarker.expectedCount} — got $ruleCount diagnostic(s)',
    );
  }

  // Return diagnostics so callers can add extra assertions if needed.
  return diags;
}
