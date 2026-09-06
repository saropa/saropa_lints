/// Behavioral tests for false-positive guards on
/// `RequireWorkmanagerForBackgroundRule`: Timer.periodic and Stream.periodic
/// inside State subclasses with proper cleanup in dispose() must not fire,
/// while the same calls in non-State classes or without cleanup must still fire.
///
/// Uses the SYNTACTIC harness because Timer.periodic resolves to
/// InstanceCreationExpression under full resolution, and the rule matches on
/// MethodInvocation — see the equivalent note in
/// avoid_ios_battery_drain_patterns_disposable_state_test.dart.
library;

import 'package:saropa_lints/src/rules/packages/workmanager_rules.dart';
import 'package:test/test.dart';

import '../../support/syntactic_rule_harness.dart';

void main() {
  group('require_workmanager_for_background - lifecycle guards', () {
    test('Timer.periodic in State, canceled in dispose() — no lint', () {
      final codes = reportedRuleCodesSyntactic(
        RequireWorkmanagerForBackgroundRule(),
        '''
class _ClockState extends State<Clock> {
  Timer? _tick;

  void start() {
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}
''',
      );

      // Lifecycle-bound timer — must not fire.
      expect(codes, isNot(contains('require_workmanager_for_background')));
    });

    test(
      'Timer.periodic in ConsumerState, canceled in dispose() — no lint',
      () {
        // ConsumerState (Riverpod) endsWith('State') and should get the
        // same lifecycle exemption as plain State<T>.
        final codes = reportedRuleCodesSyntactic(
          RequireWorkmanagerForBackgroundRule(),
          '''
class _DashState extends ConsumerState<Dashboard> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
''',
        );

        // ConsumerState is a State subtype — lifecycle-bound timer must pass.
        expect(codes, isNot(contains('require_workmanager_for_background')));
      },
    );

    test('Timer.periodic in State, NOT canceled — lints', () {
      final codes = reportedRuleCodesSyntactic(
        RequireWorkmanagerForBackgroundRule(),
        '''
class _S extends State<W> {
  Timer? _t;

  void start() {
    _t = Timer.periodic(const Duration(seconds: 1), (_) {});
  }

  @override
  void dispose() {
    super.dispose();
  }
}
''',
      );

      // No cancellation — the real risk this rule warns about.
      expect(codes, contains('require_workmanager_for_background'));
    });

    test('Timer.periodic in a non-State service class — lints', () {
      final codes = reportedRuleCodesSyntactic(
        RequireWorkmanagerForBackgroundRule(),
        '''
class SyncService {
  Timer? _syncTimer;

  void start() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {});
  }

  void stop() {
    _syncTimer?.cancel();
  }
}
''',
      );

      // Not a State subclass — no framework lifecycle guarantee.
      expect(codes, contains('require_workmanager_for_background'));
    });

    test('Stream.periodic in a service class — lints', () {
      // Stream.periodic is the same anti-pattern as Timer.periodic:
      // a repeating background task that dies when the app backgrounds.
      final codes = reportedRuleCodesSyntactic(
        RequireWorkmanagerForBackgroundRule(),
        '''
class PollingService {
  StreamSubscription? _sub;

  void start() {
    _sub = Stream.periodic(const Duration(minutes: 5), (_) => fetchData())
        .listen((_) {});
  }

  void stop() {
    _sub?.cancel();
  }
}
''',
      );

      // Not a State — must fire.
      expect(codes, contains('require_workmanager_for_background'));
    });

    test('Stream.periodic in State, closed in dispose() — no lint', () {
      final codes = reportedRuleCodesSyntactic(
        RequireWorkmanagerForBackgroundRule(),
        '''
class _PollState extends State<PollWidget> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Stream.periodic(const Duration(seconds: 10), (_) => refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
''',
      );

      // Lifecycle-bound stream — must not fire.
      expect(codes, isNot(contains('require_workmanager_for_background')));
    });

    test('skips file that already uses Workmanager', () {
      // The rule early-returns when the file already references Workmanager,
      // so Timer.periodic in the same file is presumably a UI ticker.
      final codes = reportedRuleCodesSyntactic(
        RequireWorkmanagerForBackgroundRule(),
        '''
import 'package:workmanager/workmanager.dart';

class _S extends State<W> {
  Timer? _t;

  void start() {
    _t = Timer.periodic(const Duration(seconds: 1), (_) {});
    Workmanager().registerPeriodicTask('id', 'task');
  }
}
''',
      );

      // File uses Workmanager — entire rule skipped.
      expect(codes, isNot(contains('require_workmanager_for_background')));
    });
  });
}
