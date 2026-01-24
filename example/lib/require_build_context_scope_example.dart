// ignore_for_file: unused_local_variable, avoid_print, avoid_context_across_async
// ignore_for_file: avoid_dialog_context_after_async, require_dialog_barrier_dismissible
// ignore_for_file: avoid_commented_out_code, prefer_explicit_type_arguments

import 'package:flutter/material.dart';

/// Test fixture for require_build_context_scope rule.
///
/// This rule flags BuildContext used AFTER await completes,
/// but NOT BuildContext used as an argument TO the awaited call.

class RequireBuildContextScopeExample {
  // ============================================
  // SAFE CASES - Should NOT trigger the rule
  // ============================================

  /// Safe: Context used as argument to awaited function.
  Future<void> safeShowDialog(BuildContext context) async {
    // OK: context is used synchronously as the await begins
    await showDialog(
      context: context,
      builder: (ctx) => const AlertDialog(title: Text('Hello')),
    );
  }

  /// Safe: Context used as named argument to awaited function.
  Future<bool?> safeShowDialogWithReturn(BuildContext context) async {
    // OK: context is passed before the await suspends
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  /// Safe: Arrow function with awaited call using context.
  void safeArrowFunction(BuildContext context) {
    // This pattern is common in button callbacks
    final onPressed = () async => await showDialog(
          context: context, // OK: context used as argument
          builder: (_) => const AlertDialog(title: Text('Arrow')),
        );
  }

  /// Safe: Multiple awaits, context only used as argument.
  Future<void> safeMultipleAwaits(BuildContext context) async {
    // OK: context used as argument to first await
    await showDialog(
      context: context,
      builder: (_) => const AlertDialog(title: Text('First')),
    );
    // OK: context used as argument to second await
    await showDialog(
      context: context,
      builder: (_) => const AlertDialog(title: Text('Second')),
    );
  }

  /// Safe: Context cached before await.
  Future<void> safeCachedNavigator(BuildContext context) async {
    // OK: Cache context-dependent value before await
    final navigator = Navigator.of(context);
    await Future.delayed(const Duration(seconds: 1));
    navigator.pop(); // Using cached navigator, not context
  }

  /// Safe: Context used in nested await expression.
  Future<void> safeNestedAwait(BuildContext context) async {
    // OK: context used as argument, even in complex expressions
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const AlertDialog(title: Text('Nested')),
    );
    print(result);
  }

  // ============================================
  // UNSAFE CASES - Should trigger the rule
  // ============================================

  /// Unsafe: Context used after await completes.
  Future<void> unsafeContextAfterAwait(BuildContext context) async {
    await Future.delayed(const Duration(seconds: 1));
    // expect_lint: require_build_context_scope
    Navigator.of(context).pop();
  }

  /// Unsafe: Context used after async operation.
  Future<void> unsafeContextAfterAsyncOp(BuildContext context) async {
    await someAsyncOperation();
    // expect_lint: require_build_context_scope
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Done')),
    );
  }

  /// Unsafe: Context used after multiple awaits.
  Future<void> unsafeAfterMultipleAwaits(BuildContext context) async {
    await firstOperation();
    await secondOperation();
    // expect_lint: require_build_context_scope
    Theme.of(context).primaryColor;
  }

  /// Unsafe: Mixed usage - one safe, one unsafe.
  Future<void> unsafeMixedUsage(BuildContext context) async {
    // OK: context as argument to await
    await showDialog(
      context: context,
      builder: (_) => const AlertDialog(title: Text('First')),
    );
    await someAsyncOperation();
    // expect_lint: require_build_context_scope
    Navigator.of(context).pushNamed('/home');
  }

  // ============================================
  // NOTE: GUARDED CASES
  // ============================================
  // This rule does NOT detect mounted guards.
  // For guard detection, use `avoid_context_across_async` (Essential tier).
  // The following cases WILL trigger this rule (false positives vs smarter rule):
  //
  // Future<void> guardedCase(BuildContext context) async {
  //   await someOp();
  //   if (context.mounted) {
  //     Navigator.of(context).pop(); // This rule flags it, smarter rule doesn't
  //   }
  // }
}

// Helper functions for examples
Future<void> someAsyncOperation() async {
  await Future.delayed(const Duration(milliseconds: 100));
}

Future<void> firstOperation() async {
  await Future.delayed(const Duration(milliseconds: 50));
}

Future<void> secondOperation() async {
  await Future.delayed(const Duration(milliseconds: 50));
}
