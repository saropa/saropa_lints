/// Regression tests for the false positive filed in
/// `plans/history/2026.09/2026.09.05/avoid_ios_battery_drain_patterns_disposable_state_fix.md`:
/// `AvoidIosBatteryDrainPatternsRule` used to fire on every short-interval
/// `Timer.periodic`, including ones lifecycle-bound to a `State` subclass
/// and torn down in `dispose()` -- which cannot drain battery in the
/// background because they stop existing with the widget.
///
/// Uses the SYNTACTIC harness (`syntactic_rule_harness.dart`), not the
/// resolved one: `Timer.periodic` is a factory constructor in dart:async, so
/// once fully resolved the analyzer rewrites the call from `MethodInvocation`
/// to `InstanceCreationExpression` -- but this rule (like the production
/// `saropa_lints scan` default it targets) matches on
/// `context.addMethodInvocation` with `node.methodName.name == 'periodic'`.
/// That match is a genuine no-op under full resolution regardless of the
/// fix under test, so the resolved harness would silently pass every case
/// with an empty diagnostic set. The syntactic pass mirrors what "scan on
/// save" actually runs against, and what production real-world reports (see
/// the bug file's reproducer, from a `dart run saropa_lints scan` finding)
/// are based on.
library;

import 'package:saropa_lints/src/rules/platforms/ios_platform_lifecycle_rules.dart';
import 'package:test/test.dart';

import '../../support/syntactic_rule_harness.dart';

void main() {
  group('avoid_ios_battery_drain_patterns - disposable State timers', () {
    test('Timer.periodic in State, canceled in dispose() -- no lint', () {
      final codes = reportedRuleCodesSyntactic(
        AvoidIosBatteryDrainPatternsRule(),
        '''
class _S extends State<W> {
  Timer? _clockTimer;

  void start() {
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {},
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}
''',
      );

      // Lifecycle-bound and properly canceled -- must not fire.
      expect(codes, isNot(contains('avoid_ios_battery_drain_patterns')));
    });

    test('Timer.periodic in State, NOT canceled in dispose() -- lints', () {
      final codes = reportedRuleCodesSyntactic(
        AvoidIosBatteryDrainPatternsRule(),
        '''
class _S extends State<W> {
  Timer? _clockTimer;

  void start() {
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {},
    );
  }

  @override
  void dispose() {
    // No cancel() -- the real battery-drain risk this rule exists for.
    super.dispose();
  }
}
''',
      );

      // No cancellation means the timer keeps firing after the widget is
      // gone in a leak scenario -- the existing duration check must still
      // apply.
      expect(codes, contains('avoid_ios_battery_drain_patterns'));
    });

    test('Timer.periodic in ConsumerState, canceled in dispose() -- no lint',
        () {
      // ConsumerState (Riverpod) ends with 'State' and should get the same
      // lifecycle exemption as plain State<T>.
      final codes = reportedRuleCodesSyntactic(
        AvoidIosBatteryDrainPatternsRule(),
        '''
class _S extends ConsumerState<W> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
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

      // ConsumerState is a State subtype — lifecycle-bound timer must pass.
      expect(codes, isNot(contains('avoid_ios_battery_drain_patterns')));
    });

    test('Timer.periodic in a non-State service class -- lints', () {
      final codes = reportedRuleCodesSyntactic(
        AvoidIosBatteryDrainPatternsRule(),
        '''
class PollingService {
  Timer? _pollTimer;

  void start() {
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {},
    );
  }

  void stop() {
    _pollTimer?.cancel();
  }
}
''',
      );

      // Not a State subclass -- no widget lifecycle to lean on, so the rule
      // must keep flagging this regardless of the stop() cancel call.
      expect(codes, contains('avoid_ios_battery_drain_patterns'));
    });
  });
}
