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
