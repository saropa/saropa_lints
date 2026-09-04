// Fixture for the `mutable_tearoff` lint rule.
//
// A method tear-off captures the receiver's CURRENT value at the moment
// it is taken, not a live binding to "whatever the receiver holds now".
// This rule flags tear-offs whose receiver is a non-final field, local
// variable, or parameter, since reassigning that receiver later silently
// orphans the already-stored tear-off.

typedef VoidCallback = void Function();

class Handler {
  void handleTap() {}
  VoidCallback onTapField = () {};
}

/// BAD: tear-off from a mutable (non-final) instance field, stored in a
/// field initializer.
class MutableFieldController {
  Handler handler = Handler(); // mutable field

  // expect_lint: mutable_tearoff
  late final VoidCallback onTap = handler.handleTap;

  void swapHandler(Handler next) {
    handler = next; // onTap still calls the OLD handler's handleTap
  }
}

/// BAD: tear-off from a mutable field, stored via a plain assignment
/// (rather than a field initializer).
class ReassignedTearoffController {
  Handler handler = Handler();
  VoidCallback? cachedCallback;

  void bind() {
    // expect_lint: mutable_tearoff
    cachedCallback = handler.handleTap;
  }
}

/// BAD: tear-off from a mutable local variable.
void localVariableTearoff() {
  Handler handler = Handler();
  // expect_lint: mutable_tearoff
  final VoidCallback callback = handler.handleTap;
  callback();
}

/// BAD: tear-off from a mutable (non-`final`) parameter.
void parameterTearoff(Handler handler) {
  // expect_lint: mutable_tearoff
  final VoidCallback cb = handler.handleTap;
  cb();
}

/// GOOD: final receiver — the tear-off stays bound to the same object for
/// the receiver's whole lifetime, so it can never go stale.
class FinalFieldController {
  final Handler handler = Handler();
  late final VoidCallback onTap = handler.handleTap;
}

/// GOOD: `this` can never be reassigned, even though the class has mutable
/// state — `this.bump` parses as a property access on `this`, not a
/// mutable-receiver tear-off.
class ThisBoundController {
  int counter = 0;

  void bump() {
    counter++;
  }

  late final VoidCallback onBump = this.bump;
}

/// GOOD: a `final` parameter — declared immutable, so its tear-off is safe.
void finalParameterTearoff(final Handler handler) {
  final VoidCallback cb = handler.handleTap;
  cb();
}

/// GOOD: immediately invoked — this is a normal method call, not a stored
/// tear-off, even though the receiver is mutable.
void immediateInvocation() {
  Handler handler = Handler();
  handler.handleTap();
}

/// GOOD: tear-off used only as a one-shot call argument, never retained
/// past the call — not a staleness risk (see proposal's "Alternatives
/// Considered").
void oneShotArgument(List<VoidCallback> sink) {
  Handler handler = Handler();
  sink.add(handler.handleTap);
}

/// GOOD: a field/getter read (not a method tear-off) — re-reads the
/// receiver's current field value on every access, so the receiver's own
/// mutability is a separate concern from this rule.
void storeFieldValue(Handler handler) {
  final VoidCallback cb = handler.onTapField;
  cb();
}
