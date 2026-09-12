// Regression tests for prefer_late_final's tear-off bail-out.
//
// A method that assigns a `late` field exactly once is normally safe to
// tighten to `late final`. That stops being true the moment the method is
// torn off as a callback: the callback can be invoked any number of times,
// so the "assigned once" count is a lower bound, not the truth, and taking
// the rule's advice turns the second invocation into a
// `LateInitializationError` at run time.
//
// The bail-out used to scan only method and constructor bodies for tear-offs,
// so a tear-off captured in a *field initializer* went unseen. These tests pin
// each capture site.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_variables_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('prefer_late_final tear-off bail-out', () {
    test('stays silent for a tear-off captured in a field initializer',
        () async {
      final codes = await reportedRuleCodes(PreferLateFinalRule(), '''
typedef VoidCallback = void Function();

class Loader {
  late String value;

  // `load` can run any number of times through this callback, so `value`
  // is not safely `late final`.
  late final VoidCallback retry = load;

  void load() {
    value = 'loaded';
  }
}
''');
      expect(codes, isNot(contains('prefer_late_final')));
    });

    test('stays silent for a tear-off captured in a method body', () async {
      final codes = await reportedRuleCodes(PreferLateFinalRule(), '''
typedef VoidCallback = void Function();

void register(VoidCallback callback) {}

class Loader {
  late String value;

  void wire() {
    register(load);
  }

  void load() {
    value = 'loaded';
  }
}
''');
      expect(codes, isNot(contains('prefer_late_final')));
    });

    test('still fires when the assigning method is never torn off', () async {
      final codes = await reportedRuleCodes(PreferLateFinalRule(), '''
class Loader {
  late String value;

  void load() {
    value = 'loaded';
  }
}
''');
      expect(codes, contains('prefer_late_final'));
    });
  });
}
