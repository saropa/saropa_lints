// Regression tests for `prefer_try_parse_for_dynamic_data`: Uri.parse of an
// interpolated constant, in both the resolved and the unresolved scan.
library;

import 'package:saropa_lints/src/rules/data/json_datetime_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/syntactic_rule_harness.dart';

const String _id = 'prefer_try_parse_for_dynamic_data';

const String _prelude = '''
abstract final class Settings {
  static const String apiBase = 'https://example.com/v3';
  static String mutable = 'x';
}
const String topBase = 'https://example.com';
''';

const Map<String, String> _safe = <String, String>{
  'static const alias field with method chain': r'''
abstract final class Client {
  static const String _baseUrl = Settings.apiBase;
  static Uri a() => Uri.parse('$_baseUrl/events').replace(path: 'x');
}''',
  'qualified static const': r"Uri a() => Uri.parse('${Settings.apiBase}/e');",
  'top-level const': r"Uri a() => Uri.parse('$topBase/items');",
  'same-named parameter in a sibling method': r'''
class Client {
  static const String base = 'https://example.com';
  static Uri a() => Uri.parse('$base/x');
  static String b(String base) => base;
}''',
  'local const': r'''
Uri a() {
  const String base = 'https://example.com';
  return Uri.parse('$base/items');
}''',
};

const Map<String, String> _unsafe = <String, String>{
  'parameter': r"Uri a(String host) => Uri.parse('https://$host/x');",
  'parameter shadowing a const':
      r"Uri a(String topBase) => Uri.parse('$topBase/x');",
  'local shadowing a const': r'''
Uri a(String v) {
  final String topBase = v;
  return Uri.parse('$topBase/x');
}''',
  'non-const static field': r"Uri a() => Uri.parse('${Settings.mutable}/x');",
  'field shadowing another class const': r'''
class One { static const String base = 'x'; }
class Two {
  String base = '';
  Uri a() => Uri.parse('$base/x');
}''',
  'const of an unrelated class is not in scope': r'''
class One { static const String base = 'x'; }
class Two extends Object { Uri a() => Uri.parse('$base/x'); }''',
};

void main() {
  for (final MapEntry<String, String> c in _safe.entries) {
    test('NO lint: ${c.key}', () async {
      final String code = '$_prelude${c.value}';
      expect(
        await reportedRuleCodes(PreferTryParseForDynamicDataRule(), code),
        isNot(contains(_id)),
      );
      expect(
        reportedRuleCodesSyntactic(PreferTryParseForDynamicDataRule(), code),
        isNot(contains(_id)),
      );
    });
  }
  for (final MapEntry<String, String> c in _unsafe.entries) {
    test('LINT: ${c.key}', () async {
      final String code = '$_prelude${c.value}';
      expect(
        await reportedRuleCodes(PreferTryParseForDynamicDataRule(), code),
        contains(_id),
      );
      expect(
        reportedRuleCodesSyntactic(PreferTryParseForDynamicDataRule(), code),
        contains(_id),
      );
    });
  }
}
