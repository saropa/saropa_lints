/// Integrity tests for the two-lane split
/// (`plans/PLAN_two_lane_daemon_architecture.md`).
///
/// The light lane is the set of rules allowed to run INSIDE the Dart analysis
/// server. Its whole reason to exist is memory: a rule that never touches the
/// element model cannot trigger the analyzer's lazy cross-library resolution,
/// whose retained model is what drove the server to multi-GB RSS. These tests
/// defend the two properties that keeps true:
///
/// 1. Membership is derived from real rule metadata and stays small.
/// 2. No member secretly touches the element model despite declaring
///    `usesTypeResolution => false` — the audit the plan calls for, since that
///    declaration is a hand-written override the compiler cannot check.
library;

import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Element/static-type APIs whose presence in a rule body means the rule can
/// force cross-library element resolution.
///
/// Matched as whole identifiers so `element` does not also match `elements` or
/// a local named `elementCount`. `declaredFragment` is included because the
/// analyzer's newer fragment API reaches the same element model.
///
/// **Deliberately NOT listed: `thisOrAncestorOfType`.** It reads like an
/// element API but is pure AST navigation — every call site in this package
/// parameterizes it with a syntax type (`ClassDeclaration`, `FunctionBody`,
/// `Statement`, …) and it only walks the parent chain of nodes the parser
/// already built. Including it flagged 7 correctly-declared rules as false
/// positives. Do not re-add it.
final RegExp _elementApiPattern = RegExp(
  r'\b('
  r'staticType|staticElement|staticInvokeType|staticParameterElement'
  r'|declaredElement|declaredFragment|element2'
  r'|elementFromAstIdentifier|typeSystem|typeProvider'
  r')\b',
);

/// Source of every rule file, keyed by the rule class names it declares.
/// Built once — reading ~200 files per test would dominate the run.
final Map<String, String> _sourceByRuleClass = _indexRuleSources();

Map<String, String> _indexRuleSources() {
  final index = <String, String>{};
  final rulesDir = Directory('lib/src/rules');
  if (!rulesDir.existsSync()) return index;
  final classPattern = RegExp(r'^class\s+(\w+)\s+extends\s+', multiLine: true);
  for (final entity in rulesDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    for (final match in classPattern.allMatches(source)) {
      final className = match.group(1);
      if (className != null) index[className] = source;
    }
  }
  return index;
}

/// Extracts the body of [className] from [source] — from its declaration up to
/// the next top-level `class`/`mixin`/`extension`, so one rule's element usage
/// is not blamed on its neighbor in the same file.
String? _classBody(String source, String className) {
  final start = source.indexOf(RegExp('^class\\s+$className\\s', multiLine: true));
  if (start < 0) return null;
  final rest = source.substring(start);
  final next = RegExp(
    r'^(class|mixin|extension)\s',
    multiLine: true,
  ).allMatches(rest).where((m) => m.start > 0).firstOrNull;

  return next == null ? rest : rest.substring(0, next.start);
}

void main() {
  // Priming the registry publishes light-lane membership as a side effect;
  // every test below depends on that having happened.
  setUpAll(ensureRuleRegistryBuilt);

  group('light lane membership', () {
    test('is non-empty and published by the registry build', () {
      expect(
        lightLaneRuleNames,
        isNotEmpty,
        reason:
            'Membership is published from _buildRuleFactoriesMap. Empty here '
            'means that wiring broke, which silently turns the lane gate into '
            'a no-op (it fails open by design).',
      );
    });

    test('stays a small fraction of the catalog', () {
      // The lane exists to keep in-process rule count low. A change that
      // balloons it (e.g. widening the cost band, or a bulk severity edit)
      // invalidates the memory premise and must be a deliberate decision with
      // a fresh RSS measurement — not something that slips in unnoticed.
      final all = getAllDefinedRules().length;
      expect(
        lightLaneRuleNames.length,
        lessThan(all * 0.15),
        reason:
            'Light lane is ${lightLaneRuleNames.length}/$all rules. It was '
            'sized at ~200 (<10%). Re-measure analysis-server RSS before '
            'accepting a larger lane.',
      );
    });

    test('contains only ERROR/WARNING, cheap, resolution-free rules', () {
      final members = getRulesFromRegistry(lightLaneRuleNames);
      expect(members, isNotEmpty);
      for (final rule in members) {
        expect(
          isLightLaneRule(rule),
          isTrue,
          reason:
              '${rule.code.lowerCaseName} is in the lane but fails the '
              'predicate — membership and predicate have diverged.',
        );
      }
    });

    test('excludes every INFO-severity rule', () {
      // INFO is the bulk of the catalog and the least urgent; admitting it
      // would defeat the size budget above.
      final members = getRulesFromRegistry(lightLaneRuleNames);
      final info = members
          .where((r) => !kLightLaneSeverities.contains(r.code.severity))
          .map((r) => r.code.lowerCaseName)
          .toList();
      expect(info, isEmpty);
    });
  });

  group('lane gating', () {
    tearDown(resetRuleLaneForTest);

    test('full lane allows every rule', () {
      ensureRuleRegistryBuilt();
      setActiveRuleLane(RuleLane.full);
      expect(ruleAllowedByLane('some_rule_not_in_the_light_lane'), isTrue);
    });

    test('light lane allows members and blocks non-members', () {
      ensureRuleRegistryBuilt();
      setActiveRuleLane(RuleLane.light);
      final member = lightLaneRuleNames.first;
      expect(ruleAllowedByLane(member), isTrue);
      expect(ruleAllowedByLane('definitely_not_a_real_rule_name'), isFalse);
    });

    test('fails open when membership has not been published', () {
      // The register-time gating incident (every rule silently killed for
      // file-picker users) is exactly this failure mode. A lane whose set is
      // not populated must allow rules, never block them.
      //
      // Membership is process-global and cannot be rebuilt (lazy final), so
      // snapshot and restore it rather than relying on the reset hook.
      final saved = Set<String>.from(lightLaneRuleNames);
      addTearDown(() => setLightLaneRuleNames(saved));
      setLightLaneRuleNames(const <String>{});
      setActiveRuleLane(RuleLane.light);
      expect(ruleAllowedByLane('anything_at_all'), isTrue);
    });

    test('parseRuleLane defaults to light when absent, full on a typo', () {
      expect(parseRuleLane(null), RuleLane.light);
      expect(parseRuleLane(''), RuleLane.light);
      expect(parseRuleLane('nonsense'), RuleLane.full);
      expect(parseRuleLane('light'), RuleLane.light);
      expect(parseRuleLane(' LIGHT '), RuleLane.light);
      expect(parseRuleLane('full'), RuleLane.full);
    });

    test('excludeLightLaneRules removes exactly the lane members', () {
      ensureRuleRegistryBuilt();
      final member = lightLaneRuleNames.first;
      final input = <String>{member, 'avoid_print_not_a_lane_member'};
      final result = excludeLightLaneRules(input);
      expect(result.contains(member), isFalse);
      expect(result.contains('avoid_print_not_a_lane_member'), isTrue);
    });
  });

  group('usesTypeResolution audit', () {
    test('no light-lane rule touches the element model', () {
      // The load-bearing audit. `usesTypeResolution` is a hand-written
      // override that defaults to false; a rule that touches elements while
      // declaring false would run in-process and defeat the entire lane. A
      // failure here is a defect in the RULE (fix its override so it drops
      // out of the lane), never a reason to special-case the predicate.
      final offenders = <String>[];
      for (final rule in getRulesFromRegistry(lightLaneRuleNames)) {
        final className = rule.runtimeType.toString();
        final source = _sourceByRuleClass[className];
        if (source == null) continue; // class not found; covered by other tests
        final body = _classBody(source, className);
        if (body == null) continue;
        if (_elementApiPattern.hasMatch(body)) {
          offenders.add('${rule.code.lowerCaseName} ($className)');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These light-lane rules reference element/static-type APIs while '
            'declaring usesTypeResolution => false. Set that override to true '
            'on each (which removes it from the lane), or remove the element '
            'usage:\n  ${offenders.join('\n  ')}',
      );
    });
  });
}
