// Regression test for a false-positive report claiming `no_magic_string`
// fired on a string literal inside a `//`-commented-out `debugPrint(...)`
// call (see bugs/no_magic_string_false_positive_commented_out_code.md).
//
// Investigation found this is structurally impossible: comment trivia is
// never lexed into a `SimpleStringLiteral` AST node, and the rule (plus its
// four gating helpers in literal_context_utils.dart) is 100% AST-callback
// driven with no raw-text/regex scanning. The report was closed as a
// diagnostic-staleness artifact rather than a rule defect. This test pins
// the AST-only behavior as a permanent regression guard against any future
// change that might reintroduce a text-scanning code path.
library;

import 'package:saropa_lints/src/rules/data/numeric_literal_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('no_magic_string', () {
    test('does NOT flag a string literal inside a // line comment', () async {
      final codes = await reportedRuleCodes(NoMagicStringRule(), '''
void main() {
  // debugPrint('[startup-trace] BEGIN main / writeMarker');
  doStartupWork();
  // debugPrint('[startup-trace] OK writeMarker / BEGIN Firebase.initializeApp');
}

void doStartupWork() {}
''');
      expect(codes, isNot(contains('no_magic_string')));
    });

    test('DOES flag the same literal once uncommented', () async {
      final codes = await reportedRuleCodes(NoMagicStringRule(), '''
void main() {
  debugPrint('[startup-trace] BEGIN main / writeMarker');
}

void debugPrint(String message) {}
''');
      expect(codes, contains('no_magic_string'));
    });
  });
}
