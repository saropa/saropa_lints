import 'package:analyzer/dart/element/element.dart';
import 'package:saropa_lints/src/analyzer_metadata_compat_utils.dart';
import 'package:test/test.dart';

/// Simulates analyzer 9+ MetadataImpl: has .annotations but is not Iterable.
/// Used to ensure we use the dynamic .annotations path (version-safe).
class _MetadataImplLike {
  const _MetadataImplLike(this.annotations);

  final List<ElementAnnotation> annotations;
}

class _FakeWrapperWithAnnotations {
  const _FakeWrapperWithAnnotations(this.annotations);

  final Object annotations;
}

/// Simulates a hostile/broken host object: .annotations throws (e.g. Error).
class _ThrowingAnnotations {
  Object get annotations => throw StateError('host object throws');
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

    test('readElementAnnotationsFromMetadata uses .annotations when present (MetadataImpl-like)', () {
      // Object is not Iterable; only .annotations is available (like MetadataImpl).
      final wrapper = _MetadataImplLike(<ElementAnnotation>[]);
      final result = readElementAnnotationsFromMetadata(wrapper);
      expect(result, isEmpty);
    });

    test('readElementAnnotationsFromMetadata never throws when .annotations throws (fatal-crash prevention)', () {
      // Simulates hostile or broken host object: .annotations getter throws.
      final hostile = _ThrowingAnnotations();
      expect(
        () => readElementAnnotationsFromMetadata(hostile),
        returnsNormally,
      );
      expect(readElementAnnotationsFromMetadata(hostile), isEmpty);
    });

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
