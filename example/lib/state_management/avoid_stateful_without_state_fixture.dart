// ignore_for_file: unused_element, prefer_const_constructors
// ignore_for_file: override_on_non_overriding_member
// Test fixture for avoid_stateful_without_state rule

import 'package:saropa_lints_example/flutter_mocks.dart';

// =========================================================================
// BAD: StatefulWidget with no state, lifecycle methods, or setState calls
// =========================================================================

class BadStatefulWidget extends StatefulWidget {
  @override
  State<BadStatefulWidget> createState() => _BadStatefulWidgetState();
}

// expect_lint: avoid_stateful_without_state
class _BadStatefulWidgetState extends State<BadStatefulWidget> {
  @override
  Widget build(BuildContext context) => Text('Hello');
}

// =========================================================================
// GOOD: StatefulWidget with mutable state field
// =========================================================================

class GoodWithMutableField extends StatefulWidget {
  @override
  State<GoodWithMutableField> createState() => _GoodWithMutableFieldState();
}

class _GoodWithMutableFieldState extends State<GoodWithMutableField> {
  int counter = 0; // Non-final field = mutable state

  @override
  Widget build(BuildContext context) => Text('Count: $counter');
}

// =========================================================================
// GOOD: StatefulWidget with lifecycle method (initState)
// =========================================================================

class GoodWithInitState extends StatefulWidget {
  @override
  State<GoodWithInitState> createState() => _GoodWithInitStateState();
}

class _GoodWithInitStateState extends State<GoodWithInitState> {
  @override
  void initState() {
    super.initState();
    // Setup logic here
  }

  @override
  Widget build(BuildContext context) => Text('Hello');
}

// =========================================================================
// GOOD: StatefulWidget with dispose method
// =========================================================================

class GoodWithDispose extends StatefulWidget {
  @override
  State<GoodWithDispose> createState() => _GoodWithDisposeState();
}

class _GoodWithDisposeState extends State<GoodWithDispose> {
  @override
  void dispose() {
    // Cleanup logic here
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('Hello');
}

// =========================================================================
// GOOD: StatefulWidget with setState call (the fix scenario)
// =========================================================================

class GoodWithSetState extends StatefulWidget {
  @override
  State<GoodWithSetState> createState() => _GoodWithSetStateState();
}

class _GoodWithSetStateState extends State<GoodWithSetState> {
  // Note: No mutable fields, but uses setState
  final int immutableValue = 42;

  void _onTap() {
    setState(() {
      // State update logic here
    });
  }

  @override
  Widget build(BuildContext context) => Text('Value: $immutableValue');
}

// =========================================================================
// GOOD: StatefulWidget with setState in nested callback
// =========================================================================

class GoodWithNestedSetState extends StatefulWidget {
  @override
  State<GoodWithNestedSetState> createState() => _GoodWithNestedSetStateState();
}

class _GoodWithNestedSetStateState extends State<GoodWithNestedSetState> {
  void _loadData() {
    // Simulate async operation with setState in callback
    final callback = () {
      if (mounted) {
        setState(() {
          // Update after async operation
        });
      }
    };
    callback();
  }

  @override
  Widget build(BuildContext context) => Text('Loading...');
}

// =========================================================================
// Edge case: StatelessWidget should NOT trigger the rule
// =========================================================================

class ProperStatelessWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('I am stateless');
}
