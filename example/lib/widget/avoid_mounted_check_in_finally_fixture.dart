// ignore_for_file: unused_element, unused_field

import 'package:flutter/material.dart';

/// Fixtures for avoid_mounted_check_in_finally.
library;

// =============================================================================
// BAD: `mounted` guard placed inside `finally`, after an `await` — the
// unconditional `_controller.dispose()` above it still runs regardless of
// disposal state, so the guard gives a false sense of safety.
// =============================================================================

class _SubmitFormState extends State<StatefulWidget> {
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      _controller.dispose(); // Runs unconditionally, even if unmounted
      // expect_lint: avoid_mounted_check_in_finally
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// =============================================================================
// BAD: `if (!mounted) return;` inside `finally`, guarding a Navigator call.
// =============================================================================

class _NavigateAfterSaveState extends State<StatefulWidget> {
  Future<void> _save() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      // expect_lint: avoid_mounted_check_in_finally
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }
}

// =============================================================================
// GOOD: mounted checked immediately after the await, outside the finally
// block — the point-of-use guard the rule pushes developers toward.
// =============================================================================

class _SubmitFormGoodState extends State<StatefulWidget> {
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      _controller.dispose();
    }
    if (!mounted) return; // OK — checked at point of use, not in finally
    setState(() => _isLoading = false);
  }
}

// =============================================================================
// GOOD near-miss: `mounted` check in `finally`, but it only guards a
// diagnostic log — no setState/navigation, so this is not the unsafe
// widget-tree-operation risk the rule targets.
// =============================================================================

class _LogOnlyState extends State<StatefulWidget> {
  Future<void> _refresh() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      if (mounted) {
        debugPrint('refresh finished while still mounted');
      }
    }
  }
}

// =============================================================================
// GOOD near-miss: `try`/`finally` with no `await` in the try body — there is
// no async gap for `mounted` to guard against.
// =============================================================================

class _NoAwaitState extends State<StatefulWidget> {
  bool _busy = false;

  void _run() {
    try {
      _busy = true;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

// =============================================================================
// GOOD near-miss: `mounted` checked in the `try`/`catch` body, not `finally`.
// =============================================================================

class _CheckInTryState extends State<StatefulWidget> {
  Future<void> _load() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (mounted) {
        setState(() {});
      }
    } finally {
      debugPrint('load attempted');
    }
  }
}

// =============================================================================
// BAD: the async gap is opened by an `await` in the `catch` clause, not the
// `try` body — the recovery path still falls into the same `finally`, so the
// `mounted` guard there is just as stale as the try-body case.
// =============================================================================

class _AwaitInCatchState extends State<StatefulWidget> {
  Future<void> _save() async {
    try {
      _syncOp();
    } catch (e) {
      await _recover();
    } finally {
      // expect_lint: avoid_mounted_check_in_finally
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _syncOp() {}

  Future<void> _recover() async {}
}

// =============================================================================
// BAD: `ScaffoldMessenger` (not just `Navigator`) is one of the unsafe
// targets — showing a snack bar after disposal is the same class of bug.
// =============================================================================

class _ShowSnackBarState extends State<StatefulWidget> {
  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      // expect_lint: avoid_mounted_check_in_finally
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Done')),
        );
      }
    }
  }
}

// =============================================================================
// GOOD near-miss: a compound condition (`mounted && x`) is intentionally out
// of scope — the rule only matches the exact `mounted` / `!mounted` shapes,
// not arbitrary boolean expressions that happen to reference `mounted`.
// =============================================================================

class _CompoundConditionState extends State<StatefulWidget> {
  bool _shouldUpdate = true;

  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      if (mounted && _shouldUpdate) {
        setState(() {});
      }
    }
  }
}

// =============================================================================
// GOOD near-miss: the `mounted` check lives inside a nested closure created
// within `finally`, not directly in the `finally` block's own statement
// list — that closure has its own, unrelated execution context.
// =============================================================================

class _NestedClosureState extends State<StatefulWidget> {
  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      Future<void>(() async {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }
}
