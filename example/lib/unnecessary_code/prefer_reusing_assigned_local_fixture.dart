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

// Correct form: the cached local is reused, no recompute.
void goodReusesLocal(dynamic contact) {
  final host = contact.websites.firstOrNull.host;
  if (host == null) {
    return;
  }
  use(host);
}

// --- Mock helpers so the fixture parses standalone. ---

class Theme {
  static final ThemeColor surface = ThemeColor();
}

class ThemeColor {
  Object? from(dynamic context) => null;
}

class JsonUtils {
  static String? toStringJson(Object? value) => value?.toString();
}
