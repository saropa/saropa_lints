// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_context_across_async` lint rule.

// NOTE: avoid_context_across_async fires when BuildContext is used
// after an await — the context may be invalid after async gap.
// Requires BuildContext type resolution.
//
// BAD:
// Future<void> load(BuildContext context) async {
//   await fetchData();
//   Navigator.of(context).push(...); // context may be stale
// }
//
// GOOD:
// Future<void> load(BuildContext context) async {
//   await fetchData();
//   if (context.mounted) Navigator.of(context).push(...);
// }
//
// NOT FLAGGED — guarded ternary forms (rule v7+):
//
// 1. context.mounted ? context : null
//    Future<X> f(BuildContext context) async {
//      await something();
//      return foo(context.mounted ? context : null);
//    }
//
// 2. Compound nullable guard: context != null && context.mounted ? ...
//    Idiomatic safe form for BuildContext? parameters in extension methods.
//    Future<X> f(BuildContext? context) async {
//      await something();
//      return foo(context: context != null && context.mounted
//          ? context
//          : null);
//    }
//
// 3. Compound, mounted on left: context.mounted && otherCondition ? ...
//
// 4. Compound, mounted on right: otherCondition && context.mounted ? ...
//
// 5. Compound `if`-form: if (context != null && context.mounted) ctx.use()
//    Already supported via the existing `&&` recognition in
//    `checksMounted`; included here for parity with the ternary forms.

void main() {}
