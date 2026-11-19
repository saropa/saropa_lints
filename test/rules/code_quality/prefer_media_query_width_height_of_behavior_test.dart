// Behavior tests for prefer_media_query_width_height_of, run against resolved
// source with a local MediaQuery class standing in for Flutter's.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_prefer_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _ruleName = 'prefer_media_query_width_height_of';

/// A MediaQuery stand-in. [withWidthOf] mirrors Flutter 3.35+.
String _source(String body, {bool withWidthOf = true}) =>
    '''
class BuildContext {}

class Size {
  double get width => 0;
  double get height => 0;
}

class _Data {
  Size get size => Size();
}

class MediaQuery {
  static _Data of(BuildContext c) => _Data();
  static Size sizeOf(BuildContext c) => Size();
  static Size? maybeSizeOf(BuildContext c) => null;
${withWidthOf ? '''
  static double widthOf(BuildContext c) => 0;
  static double heightOf(BuildContext c) => 0;
''' : ''}
}

void f(BuildContext c) {
$body
}
''';

Future<List<int>> _lines(String body, {bool withWidthOf = true}) async {
  final diags = await runRuleResolved(
    PreferMediaQueryWidthHeightOfRule(),
    _source(body, withWidthOf: withWidthOf),
  );
  return diags
      .where((d) => d.ruleName == _ruleName)
      .map((d) => d.line)
      .toList();
}

void main() {
  group('prefer_media_query_width_height_of', () {
    test('fires on sizeOf(c).width', () async {
      expect(await _lines('  MediaQuery.sizeOf(c).width;'), hasLength(1));
    });

    test('fires on maybeSizeOf(c)?.height', () async {
      expect(
        await _lines('  MediaQuery.maybeSizeOf(c)?.height;'),
        hasLength(1),
      );
    });

    test('fires on of(c).size.width', () async {
      expect(await _lines('  MediaQuery.of(c).size.width;'), hasLength(1));
    });

    test('silent when one sizeOf result is read for both dimensions', () async {
      expect(
        await _lines('''
  final size = MediaQuery.sizeOf(c);
  size.width;
  size.height;'''),
        isEmpty,
      );
    });

    test(
      'silent on maybeSizeOf(c)?.width.toInt() (fix would not compile)',
      () async {
        expect(
          await _lines('  MediaQuery.maybeSizeOf(c)?.width.toInt();'),
          isEmpty,
        );
      },
    );

    test(
      'silent when MediaQuery has no widthOf (Flutter before 3.35)',
      () async {
        expect(
          await _lines('  MediaQuery.sizeOf(c).width;', withWidthOf: false),
          isEmpty,
        );
      },
    );
  });
}
