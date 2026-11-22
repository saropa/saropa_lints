/// Resource-pressure model for parallel scans.
///
/// Pure logic (no I/O, no isolates) so it can be unit-tested exhaustively:
/// [evaluatePressure] classifies one machine sample, and [ThrottleController]
/// turns a stream of samples into a "how many workers may run right now"
/// decision with hysteresis, so a scan that starts to crowd the machine backs
/// off promptly and only ramps up again after a sustained calm period.
library;

/// How stressed the machine is, from a single sample.
enum PressureLevel {
  /// Plenty of headroom.
  ok,

  /// Getting tight: shed one worker.
  high,

  /// About to hurt the machine: shed down to one worker immediately.
  critical,
}

/// One observation of the machine and this process.
class PressureSample {
  const PressureSample({required this.rssMb, this.availableMb});

  /// Resident memory of the scanning process (all worker isolates) in MB.
  final int rssMb;

  /// Memory available to the whole machine/container in MB, if known.
  final int? availableMb;
}

/// Limits that define each pressure level.
class PressureLimits {
  const PressureLimits({
    required this.maxMemoryMb,
    required this.reserveMb,
    this.highFraction = 0.8,
  });

  /// RSS budget for the whole scan process. Above it → critical; above
  /// [highFraction] of it → high.
  final int maxMemoryMb;

  /// Free system memory to always leave for the rest of the machine. Below it
  /// → critical; below twice it → high.
  final int reserveMb;

  /// Fraction of [maxMemoryMb] at which pressure becomes [PressureLevel.high].
  final double highFraction;

  /// Derives [reserveMb] from total memory: 10% of RAM, between 512 MB and
  /// 2 GB — enough that the OS and an IDE keep breathing.
  static int defaultReserveMb(int? totalMemoryMb) {
    if (totalMemoryMb == null) return 768;
    final tenth = totalMemoryMb ~/ 10;
    return tenth < 512 ? 512 : (tenth > 2048 ? 2048 : tenth);
  }
}

/// Why a level was assigned (for user-facing messages).
class PressureVerdict {
  const PressureVerdict(this.level, this.reason);
  final PressureLevel level;

  /// Short human-readable reason, e.g. "free memory 640 MB is below the
  /// 1024 MB reserve". Empty for [PressureLevel.ok].
  final String reason;
}

/// Classifies [sample] against [limits]. Critical conditions win over high.
PressureVerdict evaluatePressure(PressureSample sample, PressureLimits limits) {
  final avail = sample.availableMb;
  if (sample.rssMb > limits.maxMemoryMb) {
    return PressureVerdict(
      PressureLevel.critical,
      'scan memory ${sample.rssMb} MB exceeds the ${limits.maxMemoryMb} MB '
      'budget',
    );
  }
  if (avail != null && avail < limits.reserveMb) {
    return PressureVerdict(
      PressureLevel.critical,
      'free memory $avail MB is below the ${limits.reserveMb} MB reserve',
    );
  }
  if (sample.rssMb > limits.maxMemoryMb * limits.highFraction) {
    return PressureVerdict(
      PressureLevel.high,
      'scan memory ${sample.rssMb} MB is near the ${limits.maxMemoryMb} MB '
      'budget',
    );
  }
  if (avail != null && avail < limits.reserveMb * 2) {
    return PressureVerdict(
      PressureLevel.high,
      'free memory $avail MB is getting low (reserve ${limits.reserveMb} MB)',
    );
  }
  return const PressureVerdict(PressureLevel.ok, '');
}

/// What the controller decided for one sample.
class ThrottleDecision {
  const ThrottleDecision({
    required this.allowedWorkers,
    required this.changed,
    required this.verdict,
    this.shouldAbort = false,
  });

  /// How many workers may be busy right now (1..maxWorkers).
  final int allowedWorkers;

  /// True when [allowedWorkers] differs from the previous decision.
  final bool changed;

  /// The classification that drove the decision.
  final PressureVerdict verdict;

  /// True when pressure is critical with a single worker and the RSS budget
  /// itself is exceeded: nothing left to shed, so the scan should stop early
  /// with partial results rather than risk the machine.
  final bool shouldAbort;
}

/// Hysteresis state machine mapping pressure samples to a worker allowance.
///
/// Rules:
///  * `critical` → drop to 1 worker immediately (no cooldown).
///  * `high` → drop one worker, at most once per [shedCooldown] ticks.
///  * `ok` for [rampUpAfterCalmTicks] consecutive ticks → add one worker back,
///    never above [maxWorkers].
///  * Abort only when critical *because of the RSS budget* while already at
///    one worker for [abortAfterCriticalTicks] consecutive ticks.
class ThrottleController {
  ThrottleController({
    required this.maxWorkers,
    required this.limits,
    this.shedCooldown = 2,
    this.rampUpAfterCalmTicks = 20,
    this.abortAfterCriticalTicks = 6,
  }) : _allowed = maxWorkers;

  /// Workers the scan was started with (the ceiling for ramp-up).
  final int maxWorkers;
  final PressureLimits limits;
  final int shedCooldown;
  final int rampUpAfterCalmTicks;
  final int abortAfterCriticalTicks;

  int _allowed;
  int _sinceChange = 1 << 20;
  int _calmTicks = 0;
  int _criticalAtOneTicks = 0;

  /// Current allowance.
  int get allowedWorkers => _allowed;

  /// Feeds one sample; returns the (possibly unchanged) decision.
  ThrottleDecision step(PressureSample sample) {
    final verdict = evaluatePressure(sample, limits);
    final before = _allowed;
    _sinceChange++;
    var abort = false;

    switch (verdict.level) {
      case PressureLevel.critical:
        _calmTicks = 0;
        if (_allowed > 1) {
          _allowed = 1;
          _sinceChange = 0;
        }
        if (_allowed == 1 && sample.rssMb > limits.maxMemoryMb) {
          _criticalAtOneTicks++;
          if (_criticalAtOneTicks >= abortAfterCriticalTicks) abort = true;
        } else {
          _criticalAtOneTicks = 0;
        }
      case PressureLevel.high:
        _calmTicks = 0;
        _criticalAtOneTicks = 0;
        if (_allowed > 1 && _sinceChange >= shedCooldown) {
          _allowed -= 1;
          _sinceChange = 0;
        }
      case PressureLevel.ok:
        _criticalAtOneTicks = 0;
        _calmTicks++;
        if (_calmTicks >= rampUpAfterCalmTicks && _allowed < maxWorkers) {
          _allowed += 1;
          _calmTicks = 0;
          _sinceChange = 0;
        }
    }
    return ThrottleDecision(
      allowedWorkers: _allowed,
      changed: _allowed != before,
      verdict: verdict,
      shouldAbort: abort,
    );
  }
}
