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

/// BAD: tear-off stored as an element of a list literal — retained as
/// long as the list itself, same staleness risk as a direct assignment.
void collectionLiteralTearoff(Handler handler) {
  // expect_lint: mutable_tearoff
  final List<VoidCallback> callbacks = [handler.handleTap];
  callbacks.first();
}

/// GOOD: the mainstream private-field + public-getter encapsulation idiom.
/// `handler` is a hand-written (non-synthetic) getter over a `final` field,
/// with no setter, so the tear-off can never go stale. The analyzer models
/// a real getter's `variable` as a synthetic stand-in whose `isFinal` is
/// always false, so unwrapping it would report every read-only getter —
/// the rule therefore skips non-synthetic accessors entirely.
class GetterBackedController {
  final Handler _handler = Handler();

  Handler get handler => _handler;

  late final VoidCallback onTap = handler.handleTap;
}

/// GOOD (deliberate under-report): a getter over a MUTABLE backing field is
/// also skipped. The rule cannot see through an arbitrary getter body to
/// prove the returned object is stable, so its "skip when uncertain"
/// doctrine takes precedence over catching this narrower case.
class MutableGetterBackedController {
  Handler _handler = Handler();

  Handler get handler => _handler;

  late final VoidCallback onTap = handler.handleTap;

  void swapHandler(Handler next) {
    _handler = next;
  }
}

/// BAD: tear-off stored as the KEY of a map literal — the map retains it
/// for its whole lifetime just as a value would, and hashes it by identity,
/// so a stale key silently stops matching.
void mapKeyTearoff(Handler handler) {
  // expect_lint: mutable_tearoff
  final Map<VoidCallback, String> labels = {handler.handleTap: 'tap'};
  labels.keys.first();
}

/// BAD: tear-off handed back to the caller via an arrow-bodied function —
/// the caller is free to store it, so the staleness risk travels with it.
VoidCallback getCallback(Handler handler) =>
    // expect_lint: mutable_tearoff
    handler.handleTap;

/// BAD: tear-off stored via a constructor initializer-list assignment.
/// `handlerParam` is a plain (non-`final`) constructor parameter, so the
/// tear-off it produces is just as stale-prone as one from a mutable
/// field or local variable.
class InitializerListController {
  final VoidCallback onTap;

  // expect_lint: mutable_tearoff
  InitializerListController(Handler handlerParam)
    : onTap = handlerParam.handleTap;
}
