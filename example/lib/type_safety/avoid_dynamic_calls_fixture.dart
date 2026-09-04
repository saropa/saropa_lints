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

/// GOOD: `noSuchMethod` overrides intentionally dispatch dynamically — the
/// call on the dynamic-typed local below is the whole point of the
/// override, so the rule skips this call site.
class DynamicProxy {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    dynamic fallback = 0;
    return fallback.toString();
  }
}
