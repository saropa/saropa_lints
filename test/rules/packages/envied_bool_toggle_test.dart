/// Behavior tests for the `bool` exemption of `require_envied_obfuscation`.
library;

import 'package:saropa_lints/src/rules/packages/envied_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/syntactic_rule_harness.dart';

// Envied is not a dependency of the example package, so the annotations are
// declared inline; the rule matches them by name.
const String _stubs = '''
class Envied { const Envied({bool? obfuscate, String? path}); }
class EnviedField {
  const EnviedField({String? varName, bool? obfuscate, Object? defaultValue});
}
class _Env {
  static const bool flag = false;
  static const String key = '';
  static const int pin = 0;
}
''';

/// Line numbers (1-based, relative to [body]) reported by the resolved run.
Future<List<int>> _lines(String body) async {
  final offset = '\n'.allMatches(_stubs).length;
  final diags = await runRuleResolved(
    RequireEnviedObfuscationRule(),
    '$_stubs$body',
  );
  return [for (final d in diags) d.line - offset];
}

void main() {
  group('require_envied_obfuscation bool fields', () {
    test('bool toggles are not reported, with or without obfuscate', () async {
      expect(
        await _lines('''
@Envied(path: '.env')
abstract class Toggles {
  @EnviedField(obfuscate: false, defaultValue: false)
  static const bool demo = _Env.flag;
  @EnviedField()
  static const bool? optional = _Env.flag;
  @EnviedField()
  static const inferred = _Env.flag;
}
'''),
        isEmpty,
      );
    });

    test('String and int secrets beside a bool are still reported', () async {
      // Class annotation (line 1) stays reported because a secret field made
      // no obfuscation decision; lines 5 and 7 are the secret fields.
      expect(
        await _lines('''
@Envied()
abstract class Env {
  @EnviedField()
  static const bool demo = _Env.flag;
  @EnviedField()
  static const String apiKey = _Env.key;
  @EnviedField(obfuscate: false)
  static const int pin = _Env.pin;
}
'''),
        unorderedEquals(<int>[1, 5, 7]),
      );
    });

    test('explicit bool is exempt in the syntactic scan too', () {
      final diags = runRuleSyntactic(RequireEnviedObfuscationRule(), '''
abstract class Toggles {
  @EnviedField(obfuscate: false)
  static const bool demo = _Env.flag;
  @EnviedField(obfuscate: false)
  static const String apiKey = _Env.key;
}
''');
      expect([for (final d in diags) d.line], <int>[4]);
    });
  });
}
