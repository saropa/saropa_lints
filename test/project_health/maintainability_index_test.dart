/// Tests for Halstead volume and the Maintainability Index.
import 'package:saropa_lints/src/cli/project_health/maintainability_index.dart';
import 'package:test/test.dart';

void main() {
  group('halsteadVolume', () {
    test('non-empty code has positive volume', () {
      expect(halsteadVolume('int f(int a) { return a + 1; }'), greaterThan(0));
    });

    test('empty content has zero volume', () {
      expect(halsteadVolume(''), 0);
    });
  });

  group('maintainabilityIndex', () {
    test('always within 0..100', () {
      final lo = maintainabilityIndex(
        const MaintainabilityInputs(
          halsteadVolume: 5000,
          cyclomatic: 50,
          loc: 2000,
          commentRatio: 0,
        ),
      );
      expect(lo, inInclusiveRange(0, 100));
    });

    test('raw index separates files that both clamp to 0', () {
      const worse = MaintainabilityInputs(
        halsteadVolume: 9000,
        cyclomatic: 90,
        loc: 5000,
        commentRatio: 0,
      );
      const bad = MaintainabilityInputs(
        halsteadVolume: 5000,
        cyclomatic: 50,
        loc: 3000,
        commentRatio: 0,
      );
      // Both saturate to 0 on the clamped scale...
      expect(maintainabilityIndex(worse), 0);
      expect(maintainabilityIndex(bad), 0);
      // ...but the raw scale ranks the bigger/more-complex one strictly lower.
      expect(
        maintainabilityIndexRaw(worse),
        lessThan(maintainabilityIndexRaw(bad)),
      );
    });

    test('healthier inputs score higher than worse inputs', () {
      final healthy = maintainabilityIndex(
        const MaintainabilityInputs(
          halsteadVolume: 50,
          cyclomatic: 1,
          loc: 10,
          commentRatio: 0.2,
        ),
      );
      final unhealthy = maintainabilityIndex(
        const MaintainabilityInputs(
          halsteadVolume: 5000,
          cyclomatic: 50,
          loc: 2000,
          commentRatio: 0,
        ),
      );
      expect(healthy, greaterThan(unhealthy));
    });
  });
}
