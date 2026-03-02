import 'package:saropa_lints/src/analyzer_metadata_compat_utils.dart';
import 'package:test/test.dart';

class _FakeWrapperWithAnnotations {
  const _FakeWrapperWithAnnotations(this.annotations);

  final Object annotations;
}

class _FakeDeprecatedFlags {
  const _FakeDeprecatedFlags({this.hasDeprecated, this.isDeprecated});

  final bool? hasDeprecated;
  final bool? isDeprecated;
}

void main() {
  group('analyzer_metadata_compat_utils', () {
    test(
      'readElementAnnotationsFromMetadata never throws on unknown shapes',
      () {
        expect(
          () => readElementAnnotationsFromMetadata(Object()).toList(),
          returnsNormally,
        );
        expect(
          () => readElementAnnotationsFromMetadata(const []).toList(),
          returnsNormally,
        );
        expect(
          () => readElementAnnotationsFromMetadata(
            const _FakeWrapperWithAnnotations(<int>[1, 2, 3]),
          ).toList(),
          returnsNormally,
        );
      },
    );

    test('hasDeprecatedFlag reads hasDeprecated/isDeprecated when present', () {
      expect(
        hasDeprecatedFlag(const _FakeDeprecatedFlags(hasDeprecated: true)),
        isTrue,
      );
      expect(
        hasDeprecatedFlag(const _FakeDeprecatedFlags(hasDeprecated: false)),
        isFalse,
      );
      expect(
        hasDeprecatedFlag(const _FakeDeprecatedFlags(isDeprecated: true)),
        isTrue,
      );
      expect(
        hasDeprecatedFlag(const _FakeDeprecatedFlags(isDeprecated: false)),
        isFalse,
      );
      expect(hasDeprecatedFlag(const _FakeDeprecatedFlags()), isFalse);
      expect(hasDeprecatedFlag(null), isFalse);
    });
  });
}
