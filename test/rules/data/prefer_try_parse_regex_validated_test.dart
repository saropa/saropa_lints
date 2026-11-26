// Regression tests for `prefer_try_parse_for_dynamic_data`: inputs proven to be
// digits by a regex, in both the resolved and the unresolved scan.
library;

import 'dart:io';

import 'package:saropa_lints/src/rules/data/json_datetime_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/syntactic_rule_harness.dart';

const String _id = 'prefer_try_parse_for_dynamic_data';

/// A guarded parse of [call] against `RegExp([regExp])`, declared outside the
/// loop that holds the guard.
String _guarded(String regExp, String call) =>
    '''
void f(List<String> tokens) {
  final re = RegExp($regExp);
  for (final token in tokens) {
    if (!re.hasMatch(token)) continue;
    int.parse($call);
  }
}''';

/// A parse of capture group 1 of [pattern], using a named RegExp.
String _captured(String pattern) =>
    '''
void f(String s) {
  final re = RegExp(r'$pattern');
  final m = re.firstMatch(s);
  if (m == null) return;
  int.parse(m[1]!);
}''';

final Map<String, String> _safe = <String, String>{
  'named RegExp capture group': _captured(r'^(\d{1,4})$'),
  'bounded substring': _guarded(r"r'^\d{4,8}$'", 'token.substring(4, 6)'),
  'open substring inside minimum length': _guarded(
    r"r'^\d{4,8}$'",
    'token.substring(2)',
  ),
};

final Map<String, String> _unsafe = <String, String>{
  'capture group that may be empty': _captured(r'^(\d*)$'),
  'non-digit capture group': _captured(r'^(\w+)$'),
  'unanchored guard': _guarded(r"r'\d{4}'", 'token.substring(0, 4)'),
  'multiLine guard': _guarded(
    r"r'^\d{4}$', multiLine: true",
    'token.substring(0, 4)',
  ),
  'open substring that may be empty': _guarded(
    r"r'^\d{4,8}$'",
    'token.substring(6)',
  ),
  'computed bounds': _guarded(r"r'^\d+$'", 'token.substring(token.length)'),
  'reassignable outer RegExp': r'''
void f(List<String> tokens, RegExp other) {
  var re = RegExp(r'^\d+$');
  re = other;
  for (final token in tokens) {
    if (!re.hasMatch(token)) continue;
    int.parse(token.substring(0, 1));
  }
}''',
  'parameter hiding an outer RegExp': r'''
void f() {
  final re = RegExp(r'^\d+$');
  void g(RegExp re, String token) {
    if (!re.hasMatch(token)) return;
    int.parse(token.substring(0, 1));
  }
}''',
};

void main() {
  PreferTryParseForDynamicDataRule rule() => PreferTryParseForDynamicDataRule();

  for (final MapEntry<String, String> c in _safe.entries) {
    test('NO lint: ${c.key}', () async {
      expect(await reportedRuleCodes(rule(), c.value), isNot(contains(_id)));
      expect(reportedRuleCodesSyntactic(rule(), c.value), isNot(contains(_id)));
    });
  }
  for (final MapEntry<String, String> c in _unsafe.entries) {
    test('LINT: ${c.key}', () async {
      expect(await reportedRuleCodes(rule(), c.value), contains(_id));
      expect(reportedRuleCodesSyntactic(rule(), c.value), contains(_id));
    });
  }

  // The scan integration test skips when no output is produced, so the example
  // fixture is pinned here: reported lines must equal the marked lines.
  test('example fixture reports exactly its expect_lint lines', () async {
    final String code = File(
      'example/lib/json_datetime/${_id}_fixture.dart',
    ).readAsStringSync();
    final List<String> lines = code.split('\n');
    final Set<int> expected = <int>{
      // The marker sits on the line above the violation; lines are 1-based.
      for (int i = 0; i < lines.length; i++)
        if (lines[i].contains('// expect_lint: $_id')) i + 2,
    };
    expect(expected, isNotEmpty);

    final resolved = await runRuleResolved(rule(), code);
    expect(resolved.map((d) => d.line).toSet(), expected);
    expect(runRuleSyntactic(rule(), code).map((d) => d.line).toSet(), expected);
  });
}
