// Fixture for `new_instance_cascade`: two or more immediately-consecutive
// statements that each configure the same freshly-constructed local
// variable should be flagged; a single configuring statement, a broken
// chain, a reassigned receiver, control-flow-split calls, and an
// already-cascaded initializer should all stay silent.

import 'package:flutter/material.dart';

/// BAD: two consecutive property assignments on a freshly-constructed
/// `TextEditingController` repeat the receiver name for no new information.
void buildBadPropertyAssignments() {
  final controller = TextEditingController();
  // expect_lint: new_instance_cascade
  controller.text = 'hello';
  controller.selection = const TextSelection.collapsed(offset: 5);
}

/// BAD: two consecutive method calls on a freshly-constructed
/// `ScrollController` — cascade groups the configuration calls.
void buildBadMethodCalls() {
  final controller = ScrollController();
  // expect_lint: new_instance_cascade
  controller.addListener(() {});
  controller.jumpTo(0);
}

/// GOOD: cascade notation already groups the configuration calls.
void buildGoodCascade() {
  final controller = TextEditingController()
    ..text = 'hello'
    ..selection = const TextSelection.collapsed(offset: 5);
  debugPrint(controller.text);
}

/// GOOD: only one statement configures the receiver after construction —
/// cascade adds no value for a single call.
void buildGoodSingleCall() {
  final controller = TextEditingController();
  controller.text = 'hello';
  debugPrint(controller.text);
}

/// GOOD: a statement that reads the receiver's value (not just writes to
/// one of its members) breaks the run, so the two configuring statements
/// on either side of it are not consecutive.
void buildGoodBrokenChain() {
  final controller = TextEditingController();
  controller.text = 'hello';
  final length = controller.text.length;
  debugPrint('length: $length');
  controller.selection = const TextSelection.collapsed(offset: 0);
}

/// GOOD: the receiver is reassigned instead of configured, so it is no
/// longer a fresh-instance cascade opportunity.
void buildGoodReassigned() {
  var controller = TextEditingController();
  controller = TextEditingController(text: 'reset');
  controller.text = 'hello';
}

/// GOOD: the second configuring call is inside an `if` block — cascade
/// notation cannot cross a control-flow boundary.
void buildGoodControlFlowSplit(bool flag) {
  final controller = TextEditingController();
  controller.text = 'hello';
  if (flag) {
    controller.selection = const TextSelection.collapsed(offset: 0);
  }
}
