// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: avoid_print, prefer_final_locals
// ignore_for_file: unused_import, unnecessary_null_comparison
// ignore_for_file: avoid_dynamic_calls
// Test fixture for: prefer_reusing_assigned_local
// Source: lib/src/rules/code_quality/unnecessary_code_rules.dart

void use(Object? value) {}
void debug(String message) {}

// =========================================================================
// BAD: an identical expression is recomputed instead of reusing the local.
// =========================================================================

// Property chain already cached, then re-walked verbatim.
void badPropertyChain(dynamic contact) {
  final host = contact.websites.firstOrNull.host;
  if (host == null) {
    return;
  }
  // expect_lint: prefer_reusing_assigned_local
  use(contact.websites.firstOrNull.host);
}

// Resolver-style call already cached, then re-evaluated.
void badResolverCall(dynamic context) {
  final color = Theme.surface.from(context);
  use(color);
  // expect_lint: prefer_reusing_assigned_local
  use(Theme.surface.from(context));
}

// Method-with-argument call already cached, then recomputed in a ternary.
void badMethodWithArg(Map<String, Object?> map) {
  final givenName = JsonUtils.toStringJson(map['givenName']);
  // expect_lint: prefer_reusing_assigned_local
  final fallback = givenName ?? JsonUtils.toStringJson(map['givenName']);
  use(fallback);
}

// =========================================================================
// GOOD: each recompute is NOT redundant — must NOT trigger the rule.
// =========================================================================

// Non-deterministic call: two evaluations legitimately differ.
void goodNonDeterministic() {
  final t = DateTime.now();
  use(t);
  use(DateTime.now());
}

// Save-old-then-write: the second occurrence is a write target, not a read.
void goodSaveOldThenWrite(dynamic obj) {
  final old = obj.field;
  use(old);
  obj.field = 5;
}

// Mutation between declaration and reuse changes the value.
void goodMutationBetween(List<int> list) {
  final length = list.length;
  use(length);
  list.removeAt(0);
  use(list.length);
}

// The expression is only named inside a string literal — never evaluated.
void goodStringLiteralOnly(dynamic service) {
  final phones = service.phones;
  use(phones);
  debug('[service.phones]');
}

// Receiver reassigned: the chain now resolves against a different object.
void goodReceiverReassigned(dynamic a, dynamic other) {
  final value = a.b;
  use(value);
  a = other;
  use(a.b);
}

// Live read re-read across an `await`: a suspension point lets external state
// change between the two reads (e.g. a GlobalKey's currentContext flips
// null->mounted while the navigator boots during the delay). Reusing the local
// captured before the await would be wrong, so this must NOT lint.
Future<void> goodReReadAcrossAwait(dynamic key) async {
  final first = key.currentContext;
  use(first);
  for (int i = 0; i < 3; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    final retry = key.currentContext;
    use(retry);
  }
}

// No await and no mutation between the reads: the recompute is genuinely
// redundant and must still lint — the await barrier must not suppress this.
void badLoopNoAwait(dynamic contact) {
  final host = contact.websites.firstOrNull.host;
  use(host);
  for (int i = 0; i < 3; i++) {
    // expect_lint: prefer_reusing_assigned_local
    use(contact.websites.firstOrNull.host);
  }
}

// Correct form: the cached local is reused, no recompute.
void goodReusesLocal(dynamic contact) {
  final host = contact.websites.firstOrNull.host;
  if (host == null) {
    return;
  }
  use(host);
}

// A nested closure parameter shadows the outer `wrapper`. The inner
// `wrapper.label` has identical source text but resolves to a DIFFERENT
// element (the closure parameter), so it is not a recompute of the outer
// local — reusing the outer local would read the wrong object. Must NOT lint.
String goodShadowedNestedClosure(Wrapper wrapper) {
  final String label = wrapper.label;
  use(label);
  String Function(Wrapper) read = (Wrapper wrapper) => wrapper.label;
  return read(Wrapper());
}

// Regression guard: a nested closure that CAPTURES the same `wrapper` element
// (no shadowing) genuinely recomputes `wrapper.label`. The captured `wrapper`
// resolves to the same parameter element, so reuse is valid — must still lint.
String badCapturedSameElement(Wrapper wrapper) {
  final String label = wrapper.label;
  use(label);
  // expect_lint: prefer_reusing_assigned_local
  String Function() read = () => wrapper.label;
  return read();
}

// --- Mock helpers so the fixture parses standalone. ---

class Wrapper {
  String get label => 'label';
}

class Theme {
  static final ThemeColor surface = ThemeColor();
}

class ThemeColor {
  Object? from(dynamic context) => null;
}

class JsonUtils {
  static String? toStringJson(Object? value) => value?.toString();
}
