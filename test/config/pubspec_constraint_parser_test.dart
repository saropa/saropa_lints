/// Pure-function tests for the pubspec version-constraint parser.
///
/// The five constraint-reviewer rules in `pubspec_constraint_rules.dart` are
/// thin wrappers over [parseConstraint] / [parsePubspecConstraints], so testing
/// the parser directly exercises the real decision logic (the rules themselves
/// can only be checked through the scan CLI, since custom_lint analyzes `.dart`,
/// not `.yaml`). Both positive (violating) and negative (compliant) shapes are
/// covered so the parser cannot regress to a defensive empty-result stub.
import 'package:saropa_lints/src/config/pubspec_constraint_parser.dart';
import 'package:test/test.dart';

void main() {
  group('parseConstraint', () {
    test('caret constraint has both bounds and a synthesized upper', () {
      final c = parseConstraint('^1.2.3');
      expect(c.isCaret, isTrue);
      expect(c.hasLower, isTrue);
      expect(c.hasUpper, isTrue);
      expect(c.lower?.major, 1);
      expect(c.upper?.major, 2);
      expect(c.upper?.minor, 0);
      expect(c.majorSpan, 1);
    });

    test('0.x caret stops at the next minor, not the next major', () {
      final c = parseConstraint('^0.2.3');
      expect(c.upper?.major, 0);
      expect(c.upper?.minor, 3);
      expect(c.majorSpan, 0);
    });

    test('explicit range parses both bounds', () {
      final c = parseConstraint('>=1.0.0 <2.0.0');
      expect(c.hasLower, isTrue);
      expect(c.hasUpper, isTrue);
      expect(c.lower?.major, 1);
      expect(c.upper?.major, 2);
      expect(c.majorSpan, 1);
    });

    test('lower-only range has no upper bound', () {
      final c = parseConstraint('>=3.0.0');
      expect(c.hasLower, isTrue);
      expect(c.hasUpper, isFalse);
      expect(c.majorSpan, isNull);
    });

    test('upper-only range has no lower bound', () {
      final c = parseConstraint('<2.0.0');
      expect(c.hasLower, isFalse);
      expect(c.hasUpper, isTrue);
    });

    test('any constraint is flagged as unbounded', () {
      final c = parseConstraint('any');
      expect(c.isAny, isTrue);
      expect(c.hasLower, isFalse);
      expect(c.hasUpper, isFalse);
    });

    test('exact pin bounds both ends at the same version', () {
      final c = parseConstraint('1.2.3');
      expect(c.hasLower, isTrue);
      expect(c.hasUpper, isTrue);
      expect(c.lower?.patch, 3);
      expect(c.upper?.patch, 3);
    });

    test('empty value is treated as a block (git/path/sdk follows)', () {
      final c = parseConstraint('');
      expect(c.isBlock, isTrue);
    });

    test('quotes and trailing comments are stripped', () {
      final c = parseConstraint('">=1.0.0 <2.0.0"  # pinned for CI');
      expect(c.lower?.major, 1);
      expect(c.upper?.major, 2);
    });

    test('caret-equivalent range is detected for 1.x', () {
      expect(parseConstraint('>=1.2.3 <2.0.0').isCaretEquivalentRange, isTrue);
      expect(parseConstraint('>=1.2.3 <3.0.0').isCaretEquivalentRange, isFalse);
      // A real caret is not "equivalent to a caret" — it already is one.
      expect(parseConstraint('^1.2.3').isCaretEquivalentRange, isFalse);
    });

    test('caret-equivalent range is detected for 0.x', () {
      expect(parseConstraint('>=0.2.3 <0.3.0').isCaretEquivalentRange, isTrue);
      expect(parseConstraint('>=0.2.3 <0.4.0').isCaretEquivalentRange, isFalse);
    });

    test('wide range spanning multiple majors reports a large span', () {
      expect(parseConstraint('>=1.0.0 <4.0.0').majorSpan, 3);
      expect(parseConstraint('>=1.0.0 <3.0.0').majorSpan, 2);
    });
  });

  group('parsePubspecConstraints', () {
    const appPubspec = '''
name: my_app
publish_to: none

environment:
  sdk: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
  http: any
  collection: ">=1.0.0 <4.0.0"
  args: ">=2.0.0 <3.0.0"
  meta: "<2.0.0"

dev_dependencies:
  test: ^1.24.0
''';

    test('detects an application from publish_to: none', () {
      expect(parsePubspecConstraints(appPubspec).isApp, isTrue);
    });

    test('a published package (no publish_to) is not an app', () {
      const pkg = 'name: my_pkg\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n';
      expect(parsePubspecConstraints(pkg).isApp, isFalse);
    });

    test('captures the SDK constraint and its missing upper bound', () {
      final sdk = parsePubspecConstraints(appPubspec).sdkConstraint;
      expect(sdk, isNotNull);
      expect(sdk!.hasLower, isTrue);
      expect(sdk.hasUpper, isFalse);
    });

    test('skips block dependencies and the flutter SDK marker', () {
      final deps = parsePubspecConstraints(appPubspec).dependencies;
      final names = deps.map((d) => d.name).toList();
      expect(names, isNot(contains('flutter')));
      expect(
        names,
        containsAll(<String>['http', 'collection', 'args', 'meta']),
      );
    });

    test('collects inline constraints across dependency sections', () {
      final deps = parsePubspecConstraints(appPubspec).dependencies;
      final names = deps.map((d) => d.name).toList();
      // dev_dependencies entries are included alongside dependencies.
      expect(names, contains('test'));
    });

    test('finds the unbounded, wide, and upper-only offenders', () {
      final deps = parsePubspecConstraints(appPubspec).dependencies;
      final byName = {for (final d in deps) d.name: d.constraint};
      expect(byName['http']!.isAny, isTrue);
      expect(byName['collection']!.majorSpan, 3);
      expect(byName['meta']!.hasLower, isFalse);
      expect(byName['meta']!.hasUpper, isTrue);
      // A normal caret-equivalent range that is not over-wide.
      expect(byName['args']!.isCaretEquivalentRange, isTrue);
    });

    test('a clean package pubspec yields no offenders', () {
      const clean = '''
name: clean_pkg
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  http: ^1.2.0
  collection: ^1.19.0
''';
      final parsed = parsePubspecConstraints(clean);
      expect(parsed.sdkConstraint!.hasUpper, isTrue);
      expect(parsed.dependencies.every((d) => !d.constraint.isAny), isTrue);
      expect(
        parsed.dependencies.every((d) => (d.constraint.majorSpan ?? 0) < 2),
        isTrue,
      );
    });
  });
}
