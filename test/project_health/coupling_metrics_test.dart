/// Tests the instability calculation (fan-in/fan-out).
import 'package:saropa_lints/src/cli/project_health/coupling_metrics.dart';
import 'package:test/test.dart';

void main() {
  group('Coupling.instability', () {
    test(
      'all efferent (depends on many, nothing depends on it) is unstable',
      () {
        expect(const Coupling(0, 5).instability, 1.0);
      },
    );

    test('all afferent (many depend on it) is stable', () {
      expect(const Coupling(5, 0).instability, 0.0);
    });

    test('balanced is 0.5', () {
      expect(const Coupling(3, 3).instability, closeTo(0.5, 0.001));
    });

    test('isolated file is 0', () {
      expect(const Coupling(0, 0).instability, 0.0);
    });
  });
}
