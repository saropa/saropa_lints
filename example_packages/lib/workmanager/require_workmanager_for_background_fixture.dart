// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unused_import
// ignore_for_file: annotate_overrides
// ignore_for_file: non_abstract_class_inherits_abstract_member
// ignore_for_file: unused_field

/// Fixture for `require_workmanager_for_background` lint rule.
///
/// Covers the false-positive fix
/// (plans/history/2026.09/2026.09.05/require_workmanager_for_background_false_positive_ui_timer.md):
/// a `Timer.periodic` scoped to a widget's `State` and canceled in
/// `dispose()` is a UI-lifecycle ticker, not a background-task candidate,
/// and must NOT fire. Every other shape (State without cancellation, a
/// non-State class, and top-level code) keeps firing.

import 'package:saropa_lints_example/flutter_mocks.dart';

// GOOD: Timer.periodic lives inside a State and is canceled in dispose() --
// a clock-tick display bound to widget lifecycle. Must NOT lint.
class _WorldClockState extends State<MyWidget> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}

// GOOD: same shape, a typewriter animation effect. Must NOT lint.
class _SearchBarState extends State<MyWidget> {
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();
    _typewriterTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _advanceTypewriter(),
    );
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  void _advanceTypewriter() {}
}

// BAD: Timer.periodic inside a State whose dispose() exists but never
// cancels the timer -- the leak this rule exists to catch. Must still lint.
// expect_lint: require_workmanager_for_background
class _LeakyPollingState extends State<MyWidget> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pollServer(),
    );
  }

  @override
  void dispose() {
    // Missing `_pollTimer?.cancel()` -- leaks a background poller.
    super.dispose();
  }

  void _pollServer() {}
}

// BAD: Timer.periodic in a plain (non-State) service class. No framework
// teardown point exists, so this is a genuine background-task candidate.
// Must lint.
// expect_lint: require_workmanager_for_background
class SyncService {
  void scheduleSync() {
    Timer.periodic(const Duration(hours: 1), (_) => _syncData());
  }

  void _syncData() {}
}

// BAD: Timer.periodic at top level, no enclosing class at all. Must lint.
// expect_lint: require_workmanager_for_background
void scheduleTopLevelSync() {
  Timer.periodic(const Duration(hours: 6), (_) => _topLevelSync());
}

void _topLevelSync() {}

void main() {}
