// ignore_for_file: unused_element, unused_field

import 'package:flutter/material.dart';

/// Fixtures for avoid_mounted_check_in_finally (v2 premise).
///
/// The rule targets an ORDERING bug inside a `finally` block: an unguarded
/// widget-tree call followed by a `mounted`-guarded one in the same block.
/// A `mounted` guard inside `finally` is CORRECT — `finally` runs on both the
/// success and the exception path, and code placed after the try/finally never
/// runs when the try body throws (verified against the Dart VM; the analyzer
/// reports such a trailing statement as `dead_code`). So every "guard lives in
/// finally" shape below is a GOOD case, not a violation.
library;

// =============================================================================
// BAD: unguarded `setState` runs first, then a `mounted`-guarded Navigator
// call in the same block. The guard proves the author knew the widget could
// be disposed — the earlier setState therefore crashes on that path.
// =============================================================================

class _OrderingBugState extends State<StatefulWidget> {
  bool _isLoading = false;

  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      // expect_lint: avoid_mounted_check_in_finally
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

// =============================================================================
// BAD: same ordering bug expressed with an early-return guard clause — the
// `Navigator` call above `if (!mounted) return;` is unprotected.
// =============================================================================

class _EarlyReturnOrderingBugState extends State<StatefulWidget> {
  Future<void> _save() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      // expect_lint: avoid_mounted_check_in_finally
      Navigator.of(context).pop();
      if (!mounted) return;
      setState(() {});
    }
  }
}

// =============================================================================
// BAD (nested try): the inner `finally`'s guard protects against the OUTER
// try's `await`. The inner try contains no await of its own, which v1 missed
// entirely — the unguarded setState above the guard is still a real crash.
// =============================================================================

class _NestedTryOrderingBugState extends State<StatefulWidget> {
  Future<void> _save() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      try {
        _syncOp();
      } finally {
        // expect_lint: avoid_mounted_check_in_finally
        setState(() {});
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } finally {
      _cleanup();
    }
  }

  void _syncOp() {}

  void _cleanup() {}
}

// =============================================================================
// GOOD: the canonical error-resilient shape — plain cleanup, then a guarded
// state reset, all inside `finally` so it runs on the exception path too.
// This is the pattern v1 wrongly flagged; it must stay silent.
// =============================================================================

class _CorrectGuardInFinallyState extends State<StatefulWidget> {
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      _controller.dispose(); // Plain cleanup — safe when unmounted
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// =============================================================================
// GOOD: every widget-tree operation sits inside the single guard — nothing
// unguarded precedes it.
// =============================================================================

class _AllInsideGuardState extends State<StatefulWidget> {
  bool _isLoading = false;

  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
      }
    }
  }
}

// =============================================================================
// GOOD: the early-return guard comes FIRST, so every call below it is
// protected — correct ordering, the fix this rule asks for.
// =============================================================================

class _EarlyReturnFirstState extends State<StatefulWidget> {
  bool _isLoading = false;

  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).pop();
    }
  }
}

// =============================================================================
// GOOD near-miss: no `await` anywhere before the finally block — no async gap
// means no disposal risk, so the unguarded call is fine.
// =============================================================================

class _NoAwaitState extends State<StatefulWidget> {
  bool _busy = false;

  void _run() {
    try {
      _busy = true;
    } finally {
      setState(() => _busy = false);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

// =============================================================================
// GOOD near-miss: the outer `await` happens AFTER the inner try/finally, so
// it cannot have opened an async gap before that finally block ran.
// =============================================================================

class _AwaitAfterInnerTryState extends State<StatefulWidget> {
  Future<void> _save() async {
    try {
      try {
        _syncOp();
      } finally {
        setState(() {});
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      _cleanup();
    }
  }

  void _syncOp() {}

  void _cleanup() {}
}

// =============================================================================
// GOOD near-miss: the guard only logs — no evidence the author was reasoning
// about disposal, so it cannot convict the statement above it.
// =============================================================================

class _LogOnlyGuardState extends State<StatefulWidget> {
  Future<void> _refresh() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      setState(() {});
      if (mounted) {
        debugPrint('refresh finished while still mounted');
      }
    }
  }
}

// =============================================================================
// GOOD near-miss: a compound condition (`mounted && x`) is intentionally out
// of scope — only the exact `mounted` / `!mounted` shapes are matched.
// =============================================================================

class _CompoundConditionState extends State<StatefulWidget> {
  bool _shouldUpdate = true;

  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      setState(() {});
      if (mounted && _shouldUpdate) {
        Navigator.of(context).pop();
      }
    }
  }
}

// =============================================================================
// GOOD near-miss: the guard lives inside a nested closure created within
// `finally`, not in the block's own statement list — its execution order
// relative to the surrounding statements is not lexical.
// =============================================================================

class _NestedClosureState extends State<StatefulWidget> {
  Future<void> _submit() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } finally {
      setState(() {});
      Future<void>(() async {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }
}
