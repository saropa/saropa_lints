// Regression tests for `prefer_try_parse_for_dynamic_data`: inputs proven to be
// digits by a regex, in both the resolved and the unresolved scan.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/local_binding_utils.dart';
import 'package:saropa_lints/src/rules/data/json_datetime_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/syntactic_rule_harness.dart';

const String _id = 'prefer_try_parse_for_dynamic_data';

/// Records the first `catch` clause of a parsed unit.
class _CatchFinder extends RecursiveAstVisitor<void> {
  CatchClause? clause;

  @override
  void visitCatchClause(CatchClause node) => clause ??= node;
}

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

/// [body] runs after an outer `m` that is a digits-only match of `s`.
String _hidden(String body) =>
    '''
void f(String s, Object other) {
  final re = RegExp(r'^(\\d{1,4})\$');
  final m = re.firstMatch(s);
  if (m == null) return;
  $body
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
  // In each case below the inner `m` is not the outer `firstMatch` result,
  // so its text is unknown.
  'pattern declaration hiding a match': _hidden(
    '{ final (m, _) = (other, 0); int.parse((m as dynamic)[1]); }',
  ),
  'if-case variable hiding a match': _hidden(
    'if (other case final List<String> m) { int.parse(m[1]); }',
  ),
  'switch pattern hiding a match': _hidden(
    'switch (other) { case final List<String> m: int.parse(m[1]); }',
  ),
  'local function hiding a match': _hidden(
    '{ String m(int i) => s; int.parse(m(1)[1]); }',
  ),
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

  // A `catch` clause is always inside a `try` statement, and the rule skips
  // every parse inside one, so catch shadowing cannot surface as a report.
  // It is pinned on the shared binding helper, with the skip recorded here.
  test('a catch parameter hides an outer match', () {
    final String code = _hidden(
      'try {} catch (m, st) { int.parse((m as dynamic)[1]); }',
    );
    final _CatchFinder finder = _CatchFinder();
    parseString(content: code).unit.accept(finder);
    final CatchClause clause = finder.clause!;
    expect(bindsNameAt(clause, 'm'), isTrue);
    expect(bindsNameAt(clause, 'st'), isTrue);
    expect(bindsNameAt(clause, 's'), isFalse);
    expect(reportedRuleCodesSyntactic(rule(), code), isNot(contains(_id)));
  });

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
