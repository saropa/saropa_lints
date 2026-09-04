// Test fixture for: avoid_dynamic_calls
// Source: lib/src/rules/data/avoid_dynamic_calls_rules.dart

// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_typing_uninitialized_variables
// ignore_for_file: omit_local_variable_types

/// Simple concrete type used as the statically-typed near-miss case.
class Invoice {
  double total = 0;

  double calculateTotal() => 42.0;
}

dynamic dynamicInvoice = Invoice();
Invoice typedInvoice = Invoice();

// BAD: method call on a receiver whose static type is dynamic — no
// compile-time check that calculateTotal() exists.
void _badMethodCall() {
  // expect_lint: avoid_dynamic_calls
  dynamicInvoice.calculateTotal();
}

// BAD: property access on a dynamic receiver.
void _badPropertyAccess() {
  // expect_lint: avoid_dynamic_calls
  final double value = dynamicInvoice.total;
}

// BAD: index operator invoked on a dynamic receiver.
void _badIndexAccess() {
  dynamic list = <int>[1, 2, 3];
  // expect_lint: avoid_dynamic_calls
  final int first = list[0] as int;
}

// BAD: arithmetic operator resolved dynamically.
void _badOperator() {
  dynamic value = 10;
  // expect_lint: avoid_dynamic_calls
  final dynamic result = value + 1;
}

// GOOD: method call on a statically-typed receiver — verified at compile
// time, so this is not flagged even though it looks identical to the BAD
// case above.
void _goodMethodCall() {
  typedInvoice.calculateTotal();
}

// GOOD: the dynamic value is cast to a concrete type first; the cast is the
// single, visible unsafe boundary and the subsequent call is fully checked.
void _goodExplicitCast() {
  final Invoice invoice = dynamicInvoice as Invoice;
  invoice.calculateTotal();
}

// GOOD: null-aware access on a dynamic receiver — null-awareness does not
// change the target's static type, so the rule still fires on `?.`/`?[]`
// the same as it does on plain `.`/`[]`.
void _badNullAwareAccess() {
  dynamic maybeInvoice = Invoice();
  // expect_lint: avoid_dynamic_calls
  maybeInvoice?.calculateTotal();
  dynamic maybeList = <int>[1, 2, 3];
  // expect_lint: avoid_dynamic_calls
  final int? first = maybeList?[0] as int?;
}

// BAD: cascade on a dynamic receiver — the individual cascaded calls have
// no explicit target (implicit receiver), so only the CascadeExpression
// itself is checked; expect exactly one diagnostic for the whole cascade.
void _badCascade() {
  dynamic value = Invoice();
  // expect_lint: avoid_dynamic_calls
  value
    ..calculateTotal()
    ..toString();
}

// GOOD: cascade on a statically-typed receiver is fully checked.
void _goodCascade() {
  typedInvoice
    ..calculateTotal()
    ..toString();
}

// BAD: compound assignment invokes the dynamic `+` operator the same way
// `dynamicValue + 1` does.
void _badCompoundAssignment() {
  dynamic counter = 0;
  // expect_lint: avoid_dynamic_calls
  counter += 1;
}

// GOOD: plain assignment does not invoke any member on the existing
// left-hand value, so it is never flagged even on a dynamic receiver.
void _goodPlainAssignment() {
  dynamic counter = 0;
  counter = 1;
  counter ??= 2;
}

// BAD: prefix/postfix operators invoke dynamic operator methods on the
// operand, same risk class as the covered binary-operator case.
void _badPrefixPostfix() {
  dynamic counter = 0;
  // expect_lint: avoid_dynamic_calls
  counter++;
  // expect_lint: avoid_dynamic_calls
  --counter;
  dynamic flags = 0;
  // expect_lint: avoid_dynamic_calls
  final dynamic inverted = ~flags;
}

// BAD: calling a dynamic value as a function dispatches through its
// synthetic `call()` method — unchecked exactly like a named dynamic
// method call.
void _badDynamicFunctionCall() {
  dynamic fn = () => 1;
  // expect_lint: avoid_dynamic_calls
  fn();
}

// GOOD: calling a statically-typed function value is fully checked.
void _goodTypedFunctionCall() {
  int Function() fn = () => 1;
  fn();
}

/// `noSuchMethod` overrides intentionally dispatch dynamically for call
/// sites derived from the `Invocation` parameter — those are the whole
/// point of the override and are skipped. A dynamic call elsewhere in the
/// same body that does NOT touch `invocation` is unrelated to that
/// contract and must still be flagged.
class DynamicProxy {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // GOOD: `positionalArguments[0]` is dynamic (List<dynamic> element),
    // and calling `.toString()` on it derives from the `invocation`
    // parameter — this is the intentional dispatch the override exists
    // for, so it stays exempt.
    final String first = invocation.positionalArguments[0].toString();

    // BAD: an unrelated dynamic call in the same override body, not
    // derived from `invocation` — the narrowed exemption still flags this.
    dynamic fallback = 0;
    // expect_lint: avoid_dynamic_calls
    return fallback.toString();
  }
}
