import 'package:saropa_lints/src/target_matcher_utils.dart';
import 'package:test/test.dart';

void main() {
  group('isFieldCleanedUpInSource - cascade support', () {
    test('plain dot call', () {
      expect(
        isFieldCleanedUpInSource('_ctrl', 'dispose', '_ctrl.dispose();'),
        isTrue,
      );
    });

    test('null-aware call', () {
      expect(
        isFieldCleanedUpInSource('_ctrl', 'dispose', '_ctrl?.dispose();'),
        isTrue,
      );
    });

    test('cascade call', () {
      expect(
        isFieldCleanedUpInSource(
          '_ctrl',
          'dispose',
          '_ctrl..removeListener(f)..dispose();',
        ),
        isTrue,
      );
    });

    test('cascade without target method returns false', () {
      expect(
        isFieldCleanedUpInSource(
          '_ctrl',
          'dispose',
          '_ctrl..removeListener(f);',
        ),
        isFalse,
      );
    });

    test('cascade close', () {
      expect(
        isFieldCleanedUpInSource(
          '_sub',
          'cancel',
          '_sub..pause()..cancel();',
        ),
        isTrue,
      );
    });

    test('different field name returns false', () {
      expect(
        isFieldCleanedUpInSource(
          '_other',
          'dispose',
          '_ctrl..dispose();',
        ),
        isFalse,
      );
    });

    test('does not match across statement boundaries', () {
      expect(
        isFieldCleanedUpInSource(
          '_ctrl',
          'dispose',
          '_ctrl..removeListener(f); _other..dispose();',
        ),
        isFalse,
      );
    });

    test('single cascade section', () {
      expect(
        isFieldCleanedUpInSource('_ctrl', 'dispose', '_ctrl..dispose();'),
        isTrue,
      );
    });

    test('three cascade sections', () {
      expect(
        isFieldCleanedUpInSource(
          '_ctrl',
          'dispose',
          '_ctrl..removeListener(a)..removeListener(b)..dispose();',
        ),
        isTrue,
      );
    });
  });
}
