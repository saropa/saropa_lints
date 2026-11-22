/// Tests pressure classification and the throttle hysteresis.
library;

import 'package:saropa_lints/src/scan/scan_pressure.dart';
import 'package:test/test.dart';

void main() {
  const limits = PressureLimits(maxMemoryMb: 1000, reserveMb: 500);

  group('evaluatePressure', () {
    test('ok with headroom', () {
      final v = evaluatePressure(
        const PressureSample(rssMb: 300, availableMb: 8000),
        limits,
      );
      expect(v.level, PressureLevel.ok);
    });
    test('high near the RSS budget', () {
      final v = evaluatePressure(const PressureSample(rssMb: 850), limits);
      expect(v.level, PressureLevel.high);
      expect(v.reason, contains('budget'));
    });
    test('critical over the RSS budget', () {
      expect(
        evaluatePressure(const PressureSample(rssMb: 1001), limits).level,
        PressureLevel.critical,
      );
    });
    test('high when free memory is within twice the reserve', () {
      expect(
        evaluatePressure(
          const PressureSample(rssMb: 100, availableMb: 900),
          limits,
        ).level,
        PressureLevel.high,
      );
    });
    test('critical when free memory is below the reserve', () {
      final v = evaluatePressure(
        const PressureSample(rssMb: 100, availableMb: 400),
        limits,
      );
      expect(v.level, PressureLevel.critical);
      expect(v.reason, contains('reserve'));
    });
    test('unknown free memory never triggers memory-reserve pressure', () {
      expect(
        evaluatePressure(const PressureSample(rssMb: 100), limits).level,
        PressureLevel.ok,
      );
    });
  });

  group('PressureLimits.defaultReserveMb', () {
    test('10% of RAM bounded to 512..2048', () {
      expect(PressureLimits.defaultReserveMb(null), 768);
      expect(PressureLimits.defaultReserveMb(2000), 512);
      expect(PressureLimits.defaultReserveMb(16000), 1600);
      expect(PressureLimits.defaultReserveMb(64000), 2048);
    });
  });

  group('ThrottleController', () {
    PressureSample ok() => const PressureSample(rssMb: 100, availableMb: 9000);
    PressureSample high() => const PressureSample(rssMb: 100, availableMb: 900);
    PressureSample critical() =>
        const PressureSample(rssMb: 100, availableMb: 100);

    test('critical sheds to one worker immediately', () {
      final c = ThrottleController(maxWorkers: 6, limits: limits);
      final d = c.step(critical());
      expect(d.allowedWorkers, 1);
      expect(d.changed, isTrue);
    });

    test('high sheds one worker at a time, respecting the cooldown', () {
      final c = ThrottleController(maxWorkers: 4, limits: limits);
      expect(c.step(high()).allowedWorkers, 3);
      expect(c.step(high()).allowedWorkers, 3); // cooling down
      expect(c.step(high()).allowedWorkers, 2);
    });

    test('never goes below one worker', () {
      final c = ThrottleController(maxWorkers: 2, limits: limits);
      for (var i = 0; i < 20; i++) {
        c.step(high());
      }
      expect(c.allowedWorkers, 1);
    });

    test('ramps up one worker only after sustained calm', () {
      final c = ThrottleController(
        maxWorkers: 3,
        limits: limits,
        rampUpAfterCalmTicks: 5,
      );
      c.step(critical());
      for (var i = 0; i < 4; i++) {
        expect(c.step(ok()).allowedWorkers, 1);
      }
      expect(c.step(ok()).allowedWorkers, 2);
      for (var i = 0; i < 4; i++) {
        c.step(ok());
      }
      expect(c.step(ok()).allowedWorkers, 3);
      for (var i = 0; i < 30; i++) {
        c.step(ok());
      }
      expect(c.allowedWorkers, 3); // never above the start count
    });

    test('a pressure blip resets the calm counter', () {
      final c = ThrottleController(
        maxWorkers: 3,
        limits: limits,
        rampUpAfterCalmTicks: 4,
      );
      c.step(critical());
      c.step(ok());
      c.step(ok());
      c.step(ok());
      c.step(high());
      c.step(ok());
      c.step(ok());
      c.step(ok());
      expect(c.allowedWorkers, 1);
      expect(c.step(ok()).allowedWorkers, 2);
    });

    test('aborts only when the RSS budget is exceeded at one worker', () {
      final c = ThrottleController(
        maxWorkers: 1,
        limits: limits,
        abortAfterCriticalTicks: 3,
      );
      const over = PressureSample(rssMb: 1500, availableMb: 9000);
      expect(c.step(over).shouldAbort, isFalse);
      expect(c.step(over).shouldAbort, isFalse);
      expect(c.step(over).shouldAbort, isTrue);
    });

    test('low free memory alone never aborts', () {
      final c = ThrottleController(
        maxWorkers: 1,
        limits: limits,
        abortAfterCriticalTicks: 2,
      );
      for (var i = 0; i < 10; i++) {
        expect(c.step(critical()).shouldAbort, isFalse);
      }
    });
  });
}
