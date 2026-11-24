// Resolved-analyzer tests for `prefer_number_format` bounded-integer
// exemption: DateTime components (day, hour, minute...) are < 1000 so locale
// grouping/decimal separators cannot apply. Real numbers must still report.
//
// The harness has no Flutter, so a `Text` stand-in is declared; the rule
// matches the widget by name.
library;

import 'package:saropa_lints/src/rules/ui/internationalization_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _stubs = '''
class Text {
  const Text(String data);
}
''';

Future<int> _count(String body) async {
  final diags = await runRuleResolved(
    PreferNumberFormatRule(),
    '$_stubs\n$body',
  );
  // Ignore anything reported inside the stubs themselves.
  final stubLines = '\n'.allMatches(_stubs).length + 1;
  return diags
      .where((d) => d.ruleName == 'prefer_number_format')
      .where((d) => d.line > stubLines)
      .length;
}

void main() {
  group('prefer_number_format', () {
    test('DateTime.day / hour / minute interpolation is not flagged', () async {
      expect(
        await _count(r'''
Text a(DateTime due) => Text('${due.day}');
Text b(DateTime due) => Text('${due.hour}:${due.minute}');
Text c() => Text('${DateTime.now().month}');
'''),
        0,
      );
    });

    test('plain int interpolation still reports (true positive)', () async {
      expect(
        await _count(r'''
Text a(int count) => Text('$count items');
Text b(DateTime due) => Text('${due.year + count}');
int count = 0;
'''),
        2,
      );
    });

    test('non-DateTime class with a day getter still reports', () async {
      expect(
        await _count(r'''
class Odometer { int get day => 123456; }
Text a(Odometer o) => Text('${o.day}');
'''),
        1,
      );
    });
  });
}
