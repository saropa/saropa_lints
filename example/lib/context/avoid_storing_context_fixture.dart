// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_storing_context` lint rule.

// NOTE: avoid_storing_context fires on field declarations with
// BuildContext type or assignments of context to fields.
// Requires BuildContext type resolution.
//
// BAD:
// class _Service {
//   late BuildContext _context; // stored context — stale after dispose
// }
//
// GOOD:
// Use context directly in methods, not stored in fields.

import 'package:saropa_lints_example/flutter_mocks.dart';

class FlowDelegate {}

// GOOD: render-time delegate recreated with its owning widget.
class _GoodParallaxDelegate extends FlowDelegate {
  _GoodParallaxDelegate({required this.itemContext});
  final BuildContext itemContext; // OK
}

// GOOD: final field only used behind a `.mounted` guard.
class _GoodConflictBody {
  const _GoodConflictBody({required this.parentContext});
  final BuildContext parentContext; // OK

  void ask() {
    if (!parentContext.mounted) return;
    Navigator.of(parentContext);
  }
}

// BAD: final field used without a mounted guard.
class _BadConflictBody {
  const _BadConflictBody({required this.parentContext});
  // expect_lint: avoid_storing_context
  final BuildContext parentContext;

  void ask() {
    Navigator.of(parentContext);
  }
}

void main() {}
