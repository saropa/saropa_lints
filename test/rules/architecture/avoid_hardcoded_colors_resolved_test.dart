// Resolved-analyzer tests for `avoid_hardcoded_colors` theme-definition and
// transparency exemptions (GitHub issue #398: a seed color passed to
// `ColorScheme.fromSeed` was flagged even though it defines the theme).
//
// The harness has no Flutter, so each fixture declares minimal stand-ins for
// `Color`, `Colors`, `ColorScheme`, `ThemeData` and friends; the rule matches
// by name, so the stand-ins exercise the same code paths.
library;

import 'package:saropa_lints/src/rules/architecture/structure_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _stubs = '''
class Color {
  const Color(int value);
  const Color.fromARGB(int a, int r, int g, int b);
  const Color.fromRGBO(int r, int g, int b, double opacity);
  const Color.from({required double alpha, required double red, required double green, required double blue});
}
class Colors {
  static const Color red = Color(0xFFFF0000);
  static const Color indigo = Color(0xFF3F51B5);
  static const Color transparent = Color(0x00000000);
}
class ColorScheme {
  ColorScheme.fromSeed({required Color seedColor});
  Color get primary => Color(0xFF000000);
}
class ThemeData {
  ThemeData({ColorScheme? colorScheme, AppBarThemeData? appBarTheme});
}
class AppBarThemeData {
  AppBarThemeData({Color? backgroundColor});
}
abstract class ThemeExtension<T> {}
class Container {
  Container({Color? color});
}
''';

Future<int> _count(String body) async {
  final diags = await runRuleResolved(
    AvoidHardcodedColorsRule(),
    '$_stubs\n$body',
  );
  // Ignore anything reported inside the stubs themselves.
  final stubLines = '\n'.allMatches(_stubs).length + 1;
  return diags
      .where((d) => d.ruleName == 'avoid_hardcoded_colors')
      .where((d) => d.line > stubLines)
      .length;
}

void main() {
  group('avoid_hardcoded_colors', () {
    test('issue #398: private seed constant used only in fromSeed', () async {
      expect(
        await _count('''
class AppTheme {
  static const _themeSeed = Color(0xFFB39DDB);
  static Color get seedColor =>
      ColorScheme.fromSeed(seedColor: _themeSeed).primary;
}
'''),
        0,
      );
    });

    test('colors inline in theme constructors are exempt', () async {
      expect(
        await _count('''
final theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  appBarTheme: AppBarThemeData(backgroundColor: Color(0xFF123456)),
);
'''),
        0,
      );
    });

    test('colors inside a ThemeExtension class are exempt', () async {
      expect(
        await _count('''
class Brand extends ThemeExtension<Brand> {
  final Color accent = const Color(0xFF00AA00);
}
'''),
        0,
      );
    });

    test('fully transparent colors are exempt', () async {
      expect(
        await _count('''
void f() {
  Container(color: Colors.transparent);
  Container(color: Color(0x00000000));
  Container(color: Color(0x00FF0000));
  Container(color: Color.fromARGB(0, 255, 0, 0));
  Container(color: Color.fromRGBO(255, 0, 0, 0));
  Container(color: Color.fromRGBO(255, 0, 0, 0.0));
  Container(color: Color.from(alpha: 0, red: 1, green: 0, blue: 0));
}
'''),
        0,
      );
    });

    test('still flags inline widget colors', () async {
      expect(
        await _count('''
void f() {
  Container(color: Color(0xFF000000));
  Container(color: Colors.red);
  Container(color: Color.fromARGB(255, 0, 0, 0));
  Container(color: Color.fromRGBO(0, 0, 0, 0.5));
}
'''),
        4,
      );
    });

    test('still flags a private constant also used in a widget', () async {
      expect(
        await _count('''
const _seed = Color(0xFFB39DDB);
final scheme = ColorScheme.fromSeed(seedColor: _seed);
final box = Container(color: _seed);
'''),
        1,
      );
    });

    test('still flags a public constant (may be used elsewhere)', () async {
      expect(
        await _count('''
const brandSeed = Color(0xFFB39DDB);
final scheme = ColorScheme.fromSeed(seedColor: brandSeed);
'''),
        1,
      );
    });

    test('still flags an unused private constant', () async {
      expect(await _count('const _unused = Color(0xFFB39DDB);'), 1);
    });
  });
}
