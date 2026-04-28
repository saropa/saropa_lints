import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

void main() {
  group('Rule relationship metadata integrity', () {
    final rules = allSaropaRules;
    final knownRuleNames = rules
        .map((rule) => rule.code.lowerCaseName)
        .where((name) => name.isNotEmpty)
        .toSet();

    void expectValidReferences({
      required String label,
      required Iterable<String> Function(SaropaLintRule rule) referencesOf,
    }) {
      for (final rule in rules) {
        final source = rule.code.lowerCaseName;
        if (source.isEmpty) continue;

        final seen = <String>{};
        for (final rawRef in referencesOf(rule)) {
          final ref = rawRef.trim();
          expect(
            ref,
            isNotEmpty,
            reason: '"$source" declares an empty $label rule reference.',
          );
          expect(
            ref,
            isNot(source),
            reason: '"$source" must not reference itself in $label rules.',
          );
          expect(
            seen.add(ref),
            isTrue,
            reason:
                '"$source" contains duplicate $label rule reference "$ref".',
          );
          expect(
            knownRuleNames.contains(ref),
            isTrue,
            reason:
                '"$source" references unknown $label rule "$ref". '
                'Rename/remove stale metadata or register the target rule.',
          );
        }
      }
    }

    test('relatedRules only reference known rules', () {
      expectValidReferences(
        label: 'related',
        referencesOf: (rule) => rule.relatedRules,
      );
    });

    test('conflictingRules only reference known rules', () {
      expectValidReferences(
        label: 'conflicting',
        referencesOf: (rule) => rule.conflictingRules,
      );
    });

    test('supersedesRules only reference known rules', () {
      expectValidReferences(
        label: 'supersedes',
        referencesOf: (rule) => rule.supersedesRules,
      );
    });
  });
}
