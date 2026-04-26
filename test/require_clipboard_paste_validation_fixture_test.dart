import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Registration and fixture markers for `require_clipboard_paste_validation`.
///
/// Regression: rule fired on a paste helper that delegates to a generic
/// `ValueChanged<String?>` callback whose downstream consumer owns
/// validation — see
/// `bugs/require_clipboard_paste_validation_false_positive_paste_into_text_field_via_callback.md`.
///
/// The exemption added in `_hasCallbackConsumerForClipboard`
/// (`lib/src/rules/security/security_auth_storage_rules.dart`) requires
/// resolved static-type info, so we verify the fixture's marker shape
/// rather than running the rule with parseString — the test infra here
/// has no resolved-unit API.
void main() {
  const ruleName = 'require_clipboard_paste_validation';
  const fixturePath =
      'example/lib/security/${ruleName}_fixture.dart';

  group('RequireClipboardPasteValidationRule fixtures', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('getRulesFromRegistry resolves the rule by name', () {
      final rules = getRulesFromRegistry(<String>{ruleName});
      expect(rules, hasLength(1));
      expect(rules.single.code.lowerCaseName, ruleName);
    });

    test('fixture exists and declares exactly one expect_lint marker', () {
      final file = File(fixturePath);
      expect(file.existsSync(), isTrue, reason: 'Fixture must exist');
      final content = file.readAsStringSync();
      final count = '// expect_lint: $ruleName'
          .allMatches(content)
          .length;
      expect(
        count,
        1,
        reason:
            'Only the unvalidated _bad1026_pasteApiKey case should fire. '
            'Callback-consumer cases are exempt.',
      );
    });

    test('fixture covers the callback-consumer false-positive case', () {
      final file = File(fixturePath);
      final content = file.readAsStringSync();
      expect(
        content.contains('_good1026_pasteIntoCallback('),
        isTrue,
        reason:
            'Fixture must cover the regression: clipboard text passed to '
            'a void Function(String?) callback parameter.',
      );
      expect(
        content.contains('_good1026_pasteIntoCallbackCall('),
        isTrue,
        reason:
            'Fixture must cover the explicit `?.call(...)` form on a '
            'nullable function-typed parameter.',
      );
    });
  });
}
