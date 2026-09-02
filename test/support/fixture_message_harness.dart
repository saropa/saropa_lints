// Assertion helpers that validate `runRuleResolved` diagnostics against
// `// LINT:`, `// LINT_MESSAGE:`, and `// LINT_NOT:` markers parsed from
// fixture source code.
//
// Combines the fixture marker parser with the resolved-analyzer harness to
// provide declarative, in-fixture validation — no explicit test code needed
// for each message variant or false-positive guard.
library;

import 'package:saropa_lints/saropa_lints.dart' show SaropaLintRule;
import 'package:test/test.dart';

import 'fixture_marker_parser.dart';
import 'resolved_rule_harness.dart';

/// Runs [rule] against [source] via [runRuleResolved] and validates that each
/// `// LINT:` marker has a matching diagnostic on the expected line, and each
/// `// LINT_NOT:` marker has NO matching diagnostic.
///
/// When a `// LINT:` marker includes a `// LINT_MESSAGE: substring`, the
/// diagnostic's message is also checked for that substring.
///
/// Throws a [TestFailure] when:
/// - No `// LINT:` or `// LINT_NOT:` markers are found in [source].
/// - A `// LINT:` marker's target line has no matching diagnostic.
/// - A `// LINT_MESSAGE:` substring is not found in the diagnostic's message.
/// - A `// LINT_NOT:` marker's target line HAS a matching diagnostic.
Future<List<HarnessDiagnostic>> assertFixtureMarkers(
  SaropaLintRule rule,
  String source,
) async {
  final markers = parseFixtureMarkers(source);
  final negations = parseFixtureNegations(source);

  // Guard: caller passed source with no markers at all — likely a mistake.
  expect(
    markers.length + negations.length,
    greaterThan(0),
    reason: 'Source contains no // LINT: or // LINT_NOT: markers to validate',
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
      reason: '// LINT: ${marker.ruleName} expected diagnostic on line '
          '${marker.targetLine} but none found. '
          'Reported: ${diags.map((d) => '${d.ruleName}:${d.line}').join(', ')}',
    );

    // When a message substring is declared, assert it appears in the message.
    if (marker.messageSubstring != null) {
      expect(
        matching.first.message,
        contains(marker.messageSubstring),
        reason: '// LINT_MESSAGE: "${marker.messageSubstring}" not found in '
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
              d.ruleName == negation.ruleName &&
              d.line == negation.targetLine,
        )
        .toList();

    expect(
      matching,
      isEmpty,
      reason: '// LINT_NOT: ${negation.ruleName} expected NO diagnostic on '
          'line ${negation.targetLine} but found: '
          '${matching.map((d) => '${d.ruleName}:${d.line}').join(', ')}',
    );
  }

  // Return the diagnostics so callers can add extra assertions if needed.
  return diags;
}
