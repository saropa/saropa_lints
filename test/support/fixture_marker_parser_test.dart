// Unit tests for the fixture marker parser — validates `// LINT:` and
// `// LINT_MESSAGE:` extraction from source strings without needing the
// analyzer or resolved harness.
library;

import 'package:test/test.dart';

import 'fixture_marker_parser.dart';

void main() {
  group('parseFixtureMarkers', () {
    test('parses single LINT marker without message', () {
      const source = '''
// LINT: my_rule
some_code();
''';
      final markers = parseFixtureMarkers(source);
      expect(markers, hasLength(1));
      expect(markers.first.ruleName, 'my_rule');
      // LINT on line 1, target is line 2 (the code line).
      expect(markers.first.targetLine, 2);
      expect(markers.first.messageSubstring, isNull);
    });

    test('parses LINT marker with LINT_MESSAGE', () {
      const source = '''
// LINT: my_rule
// LINT_MESSAGE: expected text
some_code();
''';
      final markers = parseFixtureMarkers(source);
      expect(markers, hasLength(1));
      expect(markers.first.ruleName, 'my_rule');
      // LINT on line 1, LINT_MESSAGE on line 2, target is line 3.
      expect(markers.first.targetLine, 3);
      expect(markers.first.messageSubstring, 'expected text');
    });

    test('parses multiple markers in one source', () {
      const source = '''
// LINT: rule_a
code_a();
// LINT: rule_b
// LINT_MESSAGE: contains this
code_b();
''';
      final markers = parseFixtureMarkers(source);
      expect(markers, hasLength(2));

      // First marker: no message, target line 2.
      expect(markers[0].ruleName, 'rule_a');
      expect(markers[0].targetLine, 2);
      expect(markers[0].messageSubstring, isNull);

      // Second marker: with message, target line 5.
      expect(markers[1].ruleName, 'rule_b');
      expect(markers[1].targetLine, 5);
      expect(markers[1].messageSubstring, 'contains this');
    });

    test('returns empty list when no markers present', () {
      const source = '''
// Just a comment
final x = 1;
''';
      final markers = parseFixtureMarkers(source);
      expect(markers, isEmpty);
    });

    test('handles LINT_MESSAGE with extra whitespace', () {
      const source = '''
// LINT: my_rule
//   LINT_MESSAGE:    lots of spaces
target();
''';
      final markers = parseFixtureMarkers(source);
      expect(markers, hasLength(1));
      // Trailing whitespace is trimmed from the substring.
      expect(markers.first.messageSubstring, 'lots of spaces');
    });

    test('non-adjacent LINT_MESSAGE is not captured', () {
      // A blank line between LINT and LINT_MESSAGE breaks the pairing.
      const source = '''
// LINT: my_rule

// LINT_MESSAGE: orphaned
target();
''';
      final markers = parseFixtureMarkers(source);
      expect(markers, hasLength(1));
      // The blank line means LINT_MESSAGE is not paired — target is line 2
      // (the blank line) and messageSubstring is null.
      expect(markers.first.targetLine, 2);
      expect(markers.first.messageSubstring, isNull);
    });

    test('LINT at end of file without target line still parses', () {
      // Edge case: LINT marker is the last line — target line is beyond EOF.
      const source = '// LINT: trailing_rule';
      final markers = parseFixtureMarkers(source);
      expect(markers, hasLength(1));
      expect(markers.first.ruleName, 'trailing_rule');
      // Target is line 2 (one past EOF), which will not match any diagnostic.
      expect(markers.first.targetLine, 2);
      expect(markers.first.messageSubstring, isNull);
    });

    test('LINT_MESSAGE captures full substring with special characters', () {
      const source = '''
// LINT: my_rule
// LINT_MESSAGE: "not a registered" saropa_lints/rule
target();
''';
      final markers = parseFixtureMarkers(source);
      expect(markers.first.messageSubstring,
          '"not a registered" saropa_lints/rule');
    });

    test('CRLF line endings parse identically to LF', () {
      // Windows-edited fixtures may have \r\n — parser must normalize.
      const source = '// LINT: my_rule\r\n// LINT_MESSAGE: found it\r\ntarget();\r\n';
      final markers = parseFixtureMarkers(source);
      expect(markers, hasLength(1));
      expect(markers.first.ruleName, 'my_rule');
      expect(markers.first.targetLine, 3);
      expect(markers.first.messageSubstring, 'found it');
    });

    test('consecutive LINT markers for same rule produce separate expectations', () {
      // Two LINT markers back to back, each targeting the line after it.
      const source = '''
// LINT: my_rule
line_a();
// LINT: my_rule
line_b();
''';
      final markers = parseFixtureMarkers(source);
      expect(markers, hasLength(2));
      expect(markers[0].targetLine, 2);
      expect(markers[1].targetLine, 4);
    });

    test('two different rules on adjacent lines produce distinct expectations', () {
      // Different rules can target the same or adjacent lines.
      const source = '''
// LINT: rule_a
// LINT: rule_b
target();
''';
      final markers = parseFixtureMarkers(source);
      expect(markers, hasLength(2));
      // rule_a's target is line 2 (the LINT: rule_b line).
      expect(markers[0].ruleName, 'rule_a');
      expect(markers[0].targetLine, 2);
      // rule_b's target is line 3 (the code line).
      expect(markers[1].ruleName, 'rule_b');
      expect(markers[1].targetLine, 3);
    });

    test('stacked LINT_MESSAGE only pairs first with LINT', () {
      // Two LINT_MESSAGE lines: only the first pairs with the LINT marker,
      // the second is treated as the target line for the first marker.
      const source = '''
// LINT: my_rule
// LINT_MESSAGE: first message
// LINT_MESSAGE: second message
target();
''';
      final markers = parseFixtureMarkers(source);
      expect(markers, hasLength(1));
      // The first LINT_MESSAGE pairs; target is line 3 (second LINT_MESSAGE).
      expect(markers.first.messageSubstring, 'first message');
      expect(markers.first.targetLine, 3);
    });

    test('marker inside string literal does not match (anchored to line start)', () {
      // Markers require `//` at line start — a string containing marker text
      // should not be parsed.
      const source = '''
final s = "// LINT: fake_rule";
final t = '// LINT_NOT: fake_rule';
''';
      expect(parseFixtureMarkers(source), isEmpty);
      expect(parseFixtureNegations(source), isEmpty);
      expect(parseFixtureCounts(source), isEmpty);
    });

    test('LINT_NOT is not parsed by parseFixtureMarkers', () {
      // LINT_NOT is handled by parseFixtureNegations, not parseFixtureMarkers.
      const source = '''
// LINT_NOT: my_rule
target();
''';
      final markers = parseFixtureMarkers(source);
      expect(markers, isEmpty);
    });

    test('toString includes rule, line, and optional message', () {
      final withMsg = FixtureExpectation(
        ruleName: 'r',
        targetLine: 5,
        messageSubstring: 'text',
      );
      expect(withMsg.toString(), 'LINT:r@5 message≈"text"');

      final withoutMsg = FixtureExpectation(
        ruleName: 'r',
        targetLine: 3,
      );
      expect(withoutMsg.toString(), 'LINT:r@3');
    });
  });

  group('parseFixtureNegations', () {
    test('parses single LINT_NOT marker', () {
      const source = '''
// LINT_NOT: my_rule
compliant_code();
''';
      final negations = parseFixtureNegations(source);
      expect(negations, hasLength(1));
      expect(negations.first.ruleName, 'my_rule');
      // LINT_NOT on line 1, target is line 2.
      expect(negations.first.targetLine, 2);
    });

    test('parses multiple LINT_NOT markers', () {
      const source = '''
// LINT_NOT: rule_a
good_a();
// LINT_NOT: rule_b
good_b();
''';
      final negations = parseFixtureNegations(source);
      expect(negations, hasLength(2));
      expect(negations[0].ruleName, 'rule_a');
      expect(negations[0].targetLine, 2);
      expect(negations[1].ruleName, 'rule_b');
      expect(negations[1].targetLine, 4);
    });

    test('returns empty list when no LINT_NOT markers present', () {
      const source = '''
// LINT: my_rule
some_code();
''';
      final negations = parseFixtureNegations(source);
      expect(negations, isEmpty);
    });

    test('CRLF line endings parse correctly', () {
      const source = '// LINT_NOT: my_rule\r\ncompliant();\r\n';
      final negations = parseFixtureNegations(source);
      expect(negations, hasLength(1));
      expect(negations.first.targetLine, 2);
    });

    test('toString includes rule and line', () {
      final neg = FixtureNegation(ruleName: 'r', targetLine: 5);
      expect(neg.toString(), 'LINT_NOT:r@5');
    });
  });

  group('parseFixtureCounts', () {
    test('parses single LINT_COUNT marker', () {
      const source = '''
// LINT_COUNT: my_rule 3
some_code();
''';
      final counts = parseFixtureCounts(source);
      expect(counts, hasLength(1));
      expect(counts.first.ruleName, 'my_rule');
      expect(counts.first.expectedCount, 3);
    });

    test('parses zero count', () {
      // Asserting zero diagnostics is valid — equivalent to a global negation.
      const source = '// LINT_COUNT: my_rule 0';
      final counts = parseFixtureCounts(source);
      expect(counts, hasLength(1));
      expect(counts.first.expectedCount, 0);
    });

    test('parses multiple LINT_COUNT markers', () {
      const source = '''
// LINT_COUNT: rule_a 2
// LINT_COUNT: rule_b 5
some_code();
''';
      final counts = parseFixtureCounts(source);
      expect(counts, hasLength(2));
      expect(counts[0].ruleName, 'rule_a');
      expect(counts[0].expectedCount, 2);
      expect(counts[1].ruleName, 'rule_b');
      expect(counts[1].expectedCount, 5);
    });

    test('returns empty list when no LINT_COUNT markers present', () {
      const source = '''
// LINT: my_rule
some_code();
''';
      final counts = parseFixtureCounts(source);
      expect(counts, isEmpty);
    });

    test('CRLF line endings parse correctly', () {
      const source = '// LINT_COUNT: my_rule 1\r\ncode();\r\n';
      final counts = parseFixtureCounts(source);
      expect(counts, hasLength(1));
      expect(counts.first.expectedCount, 1);
    });

    test('toString includes rule and count', () {
      final c = FixtureCount(ruleName: 'r', expectedCount: 4);
      expect(c.toString(), 'LINT_COUNT:r=4');
    });
  });
}
