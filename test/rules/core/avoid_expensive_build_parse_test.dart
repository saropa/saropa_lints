// Regression test for avoid_expensive_build: `parse`/`tryParse` were matched by
// bare method name, so cheap built-in conversions (int.parse, Uri.parse,
// DateTime.parse, double.tryParse) inside build() were flagged as "expensive" —
// a high-volume false positive. The fix skips parse/tryParse whose resolved
// result type is a cheap core primitive, while still flagging heavy parsing
// (e.g. jsonDecode). Run against resolved source via the oracle.
library;

import 'package:saropa_lints/src/rules/core/performance_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('avoid_expensive_build parse/tryParse', () {
    test(
      'does NOT flag int.parse / Uri.parse / double.tryParse in build()',
      () async {
        // A local StatelessWidget stub satisfies the name-based superclass gate
        // and resolves cleanly without a Flutter dependency.
        final codes = await reportedRuleCodes(AvoidExpensiveBuildRule(), '''
class StatelessWidget {}

class W extends StatelessWidget {
  Object build() {
    final a = int.parse('1');
    final b = Uri.parse('https://x');
    final c = double.tryParse('1.0');
    return [a, b, c];
  }
}
''');
        expect(codes, isNot(contains('avoid_expensive_build')));
      },
    );

    test('still flags jsonDecode (heavy parsing) in build()', () async {
      final codes = await reportedRuleCodes(AvoidExpensiveBuildRule(), '''
import 'dart:convert';

class StatelessWidget {}

class W extends StatelessWidget {
  Object build() {
    return jsonDecode('{}');
  }
}
''');
      expect(codes, contains('avoid_expensive_build'));
    });
  });
}
