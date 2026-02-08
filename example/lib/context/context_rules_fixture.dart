// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: unused_field
// ignore_for_file: prefer_const_constructors, unnecessary_import
// ignore_for_file: unused_import, avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member, annotate_overrides
// ignore_for_file: duplicate_ignore, non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: field_initializer_outside_constructor, final_not_initialized
// ignore_for_file: super_in_invalid_context, concrete_class_with_abstract_member
// ignore_for_file: type_argument_not_matching_bounds, missing_required_argument
// ignore_for_file: undefined_named_parameter, argument_type_not_assignable
// ignore_for_file: invalid_constructor_name, super_formal_parameter_without_associated_named
// ignore_for_file: undefined_annotation, creation_with_non_type
// ignore_for_file: invalid_factory_name_not_a_class, invalid_reference_to_this
// ignore_for_file: expected_class_member, body_might_complete_normally
// ignore_for_file: not_initialized_non_nullable_instance_field, unchecked_use_of_nullable_value
// ignore_for_file: return_of_invalid_type, use_of_void_result
// ignore_for_file: missing_function_body, extra_positional_arguments
// ignore_for_file: not_enough_positional_arguments, unused_label
// ignore_for_file: unused_element_parameter, non_type_as_type_argument
// ignore_for_file: expected_identifier_but_got_keyword, expected_token
// ignore_for_file: missing_identifier, unexpected_token
// ignore_for_file: duplicate_definition, override_on_non_overriding_member
// ignore_for_file: extends_non_class, no_default_super_constructor
// ignore_for_file: extra_positional_arguments_could_be_named, missing_function_parameters
// ignore_for_file: invalid_annotation, invalid_assignment
// ignore_for_file: expected_executable, named_parameter_outside_group
// ignore_for_file: obsolete_colon_for_default_value, referenced_before_declaration
// ignore_for_file: await_in_wrong_context, non_type_in_catch_clause
// ignore_for_file: could_not_infer, uri_does_not_exist
// ignore_for_file: const_method, redirect_to_non_class
// ignore_for_file: unused_catch_clause, type_test_with_undefined_name
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: undefined_super_member, extraneous_modifier
// ignore_for_file: experiment_not_enabled, missing_const_final_var_or_type
// ignore_for_file: undefined_operator, dead_code
// ignore_for_file: invalid_override, not_initialized_non_nullable_variable
// ignore_for_file: list_element_type_not_assignable, assignment_to_final
// ignore_for_file: equal_elements_in_set, prefix_shadowed_by_local_declaration
// ignore_for_file: const_initialized_with_non_constant_value, non_constant_list_element
// ignore_for_file: missing_statement, unnecessary_cast
// ignore_for_file: unnecessary_null_comparison, unnecessary_type_check
// ignore_for_file: invalid_super_formal_parameter_location, assignment_to_type
// ignore_for_file: instance_member_access_from_factory, field_initializer_not_assignable
// ignore_for_file: constant_pattern_with_non_constant_expression, undefined_identifier_await
// ignore_for_file: cast_to_non_type, read_potentially_unassigned_final
// ignore_for_file: mixin_with_non_class_superclass, instantiate_abstract_class
// ignore_for_file: dead_code_on_catch_subtype, unreachable_switch_case
// ignore_for_file: new_with_undefined_constructor, assignment_to_final_local
// ignore_for_file: late_final_local_already_assigned, missing_default_value_for_parameter
// ignore_for_file: non_bool_condition, non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type, type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression, return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor, definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member, const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference, equal_keys_in_map
// ignore_for_file: unused_catch_stack, non_constant_default_value
// ignore_for_file: not_a_type
// Test fixture for context safety rules

import '../flutter_mocks.dart';

// =========================================================================
// avoid_storing_context
// =========================================================================
// Warns when BuildContext is stored in a field.

// BAD: Storing context in a field (late)
class BadStoringContextLate extends StatefulWidget {
  const BadStoringContextLate({super.key});

  @override
  State<BadStoringContextLate> createState() => _BadStoringContextLateState();
}

class _BadStoringContextLateState extends State<BadStoringContextLate> {
  // expect_lint: avoid_storing_context
  late BuildContext _savedContext;

  @override
  void initState() {
    super.initState();
    _savedContext = context;
  }

  void doSomething() {
    Navigator.of(_savedContext).push(Container());
  }

  @override
  Widget build(BuildContext context) => Container();
}

// BAD: Storing context in a nullable field
class BadStoringContextNullable extends StatefulWidget {
  const BadStoringContextNullable({super.key});

  @override
  State<BadStoringContextNullable> createState() =>
      _BadStoringContextNullableState();
}

class _BadStoringContextNullableState extends State<BadStoringContextNullable> {
  // expect_lint: avoid_storing_context
  BuildContext? _myContext;

  void captureContext() {
    _myContext = context;
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using context directly with mounted check
class GoodUsingContextDirectly extends StatefulWidget {
  const GoodUsingContextDirectly({super.key});

  @override
  State<GoodUsingContextDirectly> createState() =>
      _GoodUsingContextDirectlyState();
}

class _GoodUsingContextDirectlyState extends State<GoodUsingContextDirectly> {
  void doSomething() {
    if (!mounted) return;
    Navigator.of(context).push(Container()); // Using context directly
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Function type with BuildContext parameter is NOT storing context
// This is a callback signature, not an actual stored context instance
class GoodFunctionTypeWithContext extends StatelessWidget {
  const GoodFunctionTypeWithContext({
    required this.onShowDialog,
    required this.onAction,
    super.key,
  });

  // These should NOT trigger avoid_storing_context - they are function signatures
  final void Function(BuildContext context, String message) onShowDialog;
  final void Function(BuildContext ctx) onAction;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onShowDialog(context, 'Hello'),
      child: Container(),
    );
  }
}

// GOOD: Function type with NAMED BuildContext parameter is NOT storing context
// This is a builder callback signature, not an actual stored context instance.
// Regression test for: named-parameter function types were falsely flagged
// because toSource() on GenericFunctionType with named params may not contain
// the literal 'Function' keyword, bypassing the _isContextType string check.
class GoodFunctionTypeWithNamedContext extends StatelessWidget {
  const GoodFunctionTypeWithNamedContext({
    required this.builder,
    required this.builderWithValue,
    this.optionalCallback,
    super.key,
  });

  // These should NOT trigger avoid_storing_context - they are function
  // signatures with named (not positional) BuildContext parameters
  final Widget Function({required BuildContext context}) builder;
  final Widget Function({
    required BuildContext context,
    required bool value,
  }) builderWithValue;
  final void Function({BuildContext? context})? optionalCallback;

  @override
  Widget build(BuildContext context) {
    return builder(context: context);
  }
}

// =========================================================================
// avoid_context_across_async
// =========================================================================
// Warns when BuildContext is used after an await.

// BAD: Using context after await without mounted check
class BadContextAfterAwait extends StatefulWidget {
  const BadContextAfterAwait({super.key});

  @override
  State<BadContextAfterAwait> createState() => _BadContextAfterAwaitState();
}

class _BadContextAfterAwaitState extends State<BadContextAfterAwait> {
  Future<void> loadData() async {
    final data = await Future.value('data');
    // expect_lint: avoid_context_across_async
    Navigator.of(context).push(Container()); // Context may be invalid!
  }

  @override
  Widget build(BuildContext context) => Container();
}

// BAD: Using context after await in a lambda
class BadContextAfterAwaitLambda extends StatefulWidget {
  const BadContextAfterAwaitLambda({super.key});

  @override
  State<BadContextAfterAwaitLambda> createState() =>
      _BadContextAfterAwaitLambdaState();
}

class _BadContextAfterAwaitLambdaState
    extends State<BadContextAfterAwaitLambda> {
  void setupCallback() {
    final callback = () async {
      await Future.value('data');
      // expect_lint: avoid_context_across_async
      ScaffoldMessenger.of(context).showSnackBar();
    };
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using context after await WITH mounted check (if statement)
class GoodContextAfterAwaitWithMounted extends StatefulWidget {
  const GoodContextAfterAwaitWithMounted({super.key});

  @override
  State<GoodContextAfterAwaitWithMounted> createState() =>
      _GoodContextAfterAwaitWithMountedState();
}

class _GoodContextAfterAwaitWithMountedState
    extends State<GoodContextAfterAwaitWithMounted> {
  Future<void> loadData() async {
    final data = await Future.value('data');
    if (!mounted) return;
    Navigator.of(context).push(Container()); // Protected by mounted check
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using context after await WITH if (mounted) block
class GoodContextAfterAwaitWithMountedBlock extends StatefulWidget {
  const GoodContextAfterAwaitWithMountedBlock({super.key});

  @override
  State<GoodContextAfterAwaitWithMountedBlock> createState() =>
      _GoodContextAfterAwaitWithMountedBlockState();
}

class _GoodContextAfterAwaitWithMountedBlockState
    extends State<GoodContextAfterAwaitWithMountedBlock> {
  Future<void> loadData() async {
    final data = await Future.value('data');
    if (mounted) {
      Navigator.of(context).push(Container()); // Inside mounted block
    }
  }

  @override
  Widget build(BuildContext context) => Container();
}

// BAD: Context in else-branch of if (mounted) is NOT protected
class BadContextInElseBranch extends StatefulWidget {
  const BadContextInElseBranch({super.key});

  @override
  State<BadContextInElseBranch> createState() => _BadContextInElseBranchState();
}

class _BadContextInElseBranchState extends State<BadContextInElseBranch> {
  Future<void> loadData() async {
    final data = await Future.value('data');
    if (mounted) {
      Navigator.of(context).push(Container()); // Safe inside then-branch
    } else {
      // expect_lint: avoid_context_across_async
      Navigator.of(context).pop(); // NOT safe in else-branch!
    }
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: context.mounted check (Flutter 3.7+ style)
class GoodContextMountedCheck extends StatefulWidget {
  const GoodContextMountedCheck({super.key});

  @override
  State<GoodContextMountedCheck> createState() =>
      _GoodContextMountedCheckState();
}

class _GoodContextMountedCheckState extends State<GoodContextMountedCheck> {
  Future<void> loadData() async {
    final data = await Future.value('data');
    if (!context.mounted) return;
    Navigator.of(context).push(Container()); // Protected by context.mounted
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using context.mounted guard (single-line if statement)
class GoodContextMountedInlineGuard extends StatefulWidget {
  const GoodContextMountedInlineGuard({super.key});

  @override
  State<GoodContextMountedInlineGuard> createState() =>
      _GoodContextMountedInlineGuardState();
}

class _GoodContextMountedInlineGuardState
    extends State<GoodContextMountedInlineGuard> {
  Future<void> handleAction() async {
    await Future.value('data');
    // This should NOT trigger avoid_context_across_async
    // because context.mounted IS the recommended guard pattern
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using context.mounted guard (block if statement)
class GoodContextMountedBlockGuard extends StatefulWidget {
  const GoodContextMountedBlockGuard({super.key});

  @override
  State<GoodContextMountedBlockGuard> createState() =>
      _GoodContextMountedBlockGuardState();
}

class _GoodContextMountedBlockGuardState
    extends State<GoodContextMountedBlockGuard> {
  Future<void> handleAction() async {
    await Future.value('data');
    // This should NOT trigger avoid_context_across_async
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using negated context.mounted guard with early return
class GoodContextMountedNegatedGuard extends StatefulWidget {
  const GoodContextMountedNegatedGuard({super.key});

  @override
  State<GoodContextMountedNegatedGuard> createState() =>
      _GoodContextMountedNegatedGuardState();
}

class _GoodContextMountedNegatedGuardState
    extends State<GoodContextMountedNegatedGuard> {
  Future<void> handleAction() async {
    await Future.value('data');
    // This should NOT trigger avoid_context_across_async
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Nested if with context.mounted (matches user's reported case)
class GoodNestedContextMountedCheck extends StatefulWidget {
  const GoodNestedContextMountedCheck({super.key});
  final bool isCloseAfterSubmit = true;

  @override
  State<GoodNestedContextMountedCheck> createState() =>
      _GoodNestedContextMountedCheckState();
}

class _GoodNestedContextMountedCheckState
    extends State<GoodNestedContextMountedCheck> {
  Future<void> handlePressed() async {
    await Future.value('showScreenContactDetailView');

    // This nested pattern should NOT trigger avoid_context_across_async
    if (widget.isCloseAfterSubmit) {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Mounted-guarded ternary pattern (context.mounted ? context : null)
class GoodMountedTernaryInInstanceMethod extends StatefulWidget {
  const GoodMountedTernaryInInstanceMethod({super.key});

  @override
  State<GoodMountedTernaryInInstanceMethod> createState() =>
      _GoodMountedTernaryInInstanceMethodState();
}

class _GoodMountedTernaryInInstanceMethodState
    extends State<GoodMountedTernaryInInstanceMethod> {
  Future<void> handleError() async {
    try {
      await Future.value('data');
    } catch (e) {
      // This ternary pattern should NOT trigger avoid_context_across_async
      // context.mounted ? context : null is a safe guard pattern
      debugException(e, context: context.mounted ? context : null);
    }
  }

  Future<void> doSomething() async {
    await Future.value('data');
    // Another common pattern: using ternary inline
    final ctx = context.mounted ? context : null;
    if (ctx != null) Navigator.of(ctx).pop();
  }

  Future<void> passToFunction() async {
    await Future.value('data');
    // Safe: context only used if mounted
    someHelper(context: context.mounted ? context : null);
  }

  @override
  Widget build(BuildContext context) => Container();
}

void someHelper({BuildContext? context}) {}

// =========================================================================
// avoid_context_after_await_in_static (Essential/ERROR)
// =========================================================================
// Warns when BuildContext is used AFTER await in async static methods.
// This is the truly dangerous case - context may be invalid after async gap.

// BAD: Context used after await in async static method - CRASH RISK!
class BadContextAfterAwaitInStatic {
  // expect_lint: avoid_context_after_await_in_static
  static Future<void> fetchAndShow(BuildContext context) async {
    final data = await Future.value('data');
    // This is dangerous - widget may be disposed during await
    ScaffoldMessenger.of(context).showSnackBar();
  }

  // expect_lint: avoid_context_after_await_in_static
  static Future<void> multipleAwaits(BuildContext ctx) async {
    await Future.value('first');
    await Future.value('second');
    Navigator.of(ctx).pop(); // Context used after multiple awaits
  }
}

// NOTE: Callback-based mounted check pattern.
// The lint doesn't recognize isMounted() callbacks as valid guards.
// This is a valid pattern but requires an ignore comment for now.
class MountedCallbackPattern {
  static Future<void> fetchAndShow(
    BuildContext context,
    bool Function() isMounted,
  ) async {
    final data = await Future.value('data');
    if (!isMounted()) return;
    // ignore: avoid_context_across_async, avoid_context_after_await_in_static
    ScaffoldMessenger.of(context).showSnackBar(); // Safe with callback check
  }
}

// GOOD: Use context BEFORE await (no lint triggered)
class GoodContextBeforeAwait {
  static Future<void> captureTheme(BuildContext context) async {
    // Using context before await is OK - widget is still mounted
    final theme = Theme.of(context);
    await Future.value('data');
    // Don't use context here!
  }
}

// GOOD: Context as argument TO the await call (not after it)
class GoodContextInAwaitCall {
  static Future<bool> showMyDialog(BuildContext context) async {
    // Context is passed as argument to the awaited call - this is SAFE
    // The context is used during the await, not after it completes
    return await showDialog(context: context) ?? false;
  }

  static Future<void> showAndReturn(BuildContext context) async {
    // Same pattern - context is argument to await, not used after
    final result = await Navigator.of(context).push(Container());
  }
}

// GOOD: Context used with mounted ternary guard
class GoodContextWithMountedTernary {
  static Future<void> logError(BuildContext context) async {
    try {
      await Future.value('data');
    } catch (e) {
      // context.mounted ? context : null is a safe pattern
      // The ternary ensures context is only used when mounted
      debugException(e, context: context.mounted ? context : null);
    }
  }
}

// GOOD: Guarded context after await inside try-catch (mounted guard + ternary)
class GoodContextInTryCatchGuarded {
  // ignore: avoid_context_in_async_static
  static Future<void> fetchData(BuildContext context) async {
    try {
      await Future.value('data');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar();
    } catch (e) {
      debugException(e, context: context.mounted ? context : null);
    }
  }
}

// GOOD: Nested if-block with mounted guard inside try-catch
class GoodContextInNestedTryCatch {
  // ignore: avoid_context_in_async_static
  static Future<void> restoreData(BuildContext context) async {
    try {
      final data = await Future.value(<int>[1, 2]);
      if (data.isNotEmpty) {
        await Future.value('processed');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar();
      }
    } catch (e) {
      debugException(e, context: context.mounted ? context : null);
    }
  }
}

// GOOD: Nullable-safe mounted check in static method (Bug Report Case 2)
// Tests that context?.mounted ?? false pattern is recognized
class GoodNullableSafeMountedCheck {
  static Future<bool> apiFetchContactVideos({
    required ContactModel contact,
    BuildContext? context,
  }) async {
    try {
      await Future.value('data');
      return true;
    } on Object catch (error, stack) {
      // This nullable-safe pattern should NOT trigger lint
      // context?.mounted ?? false ? context : null is functionally equivalent to
      // context.mounted ? context : null for nullable context
      debugException(error, stack,
          context: context?.mounted ?? false ? context : null);
      return false;
    }
  }
}

// GOOD: Ternary guard in catch block with named parameters (Bug Report Case 1)
// Tests that ternary guards work in catch blocks with complex parameter passing
class GoodTernaryInCatchBlockNamedParams extends StatefulWidget {
  const GoodTernaryInCatchBlockNamedParams({super.key});

  @override
  State<GoodTernaryInCatchBlockNamedParams> createState() =>
      _GoodTernaryInCatchBlockNamedParamsState();
}

class _GoodTernaryInCatchBlockNamedParamsState
    extends State<GoodTernaryInCatchBlockNamedParams> {
  Future<bool> showDialogAddContact({
    FamilyGroupModel? familyGroup,
  }) async {
    try {
      return await showDialogCommon(
        context: context,
        child: Container(),
      );
    } on Object catch (error, stack) {
      // This ternary pattern in catch block should NOT trigger lint
      // Even when passed as named argument in function call
      debugException(error, stack,
          contact: this, context: context.mounted ? context : null);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => Container();
}

// BAD: Unguarded context after await inside try-catch
class BadContextInTryCatchUnguarded {
  // ignore: avoid_context_in_async_static
  // expect_lint: avoid_context_after_await_in_static
  static Future<void> fetchData(BuildContext context) async {
    try {
      await Future.value('data');
      ScaffoldMessenger.of(context).showSnackBar();
    } catch (e) {
      rethrow;
    }
  }
}

// Helper for test
void debugException(
  Object e, {
  StackTrace? stack,
  dynamic contact,
  BuildContext? context,
}) {}

// =========================================================================
// avoid_context_in_async_static (Recommended/WARNING)
// =========================================================================
// Warns when ANY async static method has BuildContext parameter.
// Even if context is used before await, the pattern is risky.

// BAD: Async static method with BuildContext - risky pattern
class BadAsyncStaticWithContext {
  // expect_lint: avoid_context_in_async_static
  static Future<void> showConfirmation(BuildContext context) async {
    final confirmed = await Future.value(true);
    // Even if context is used carefully, this pattern is risky
  }

  // expect_lint: avoid_context_in_async_static
  static Future<String?> pickOption(BuildContext ctx) async {
    return await Future.value('option');
  }
}

// GOOD: Non-async static method with context (handled by different rule)
class GoodSyncStaticWithContext {
  // This triggers avoid_context_in_static_methods (INFO) not the async rule
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar();
  }
}

// GOOD: Async instance method with context (can check mounted)
class GoodAsyncInstanceMethod extends StatefulWidget {
  const GoodAsyncInstanceMethod({super.key});

  @override
  State<GoodAsyncInstanceMethod> createState() =>
      _GoodAsyncInstanceMethodState();
}

class _GoodAsyncInstanceMethodState extends State<GoodAsyncInstanceMethod> {
  Future<void> loadData() async {
    await Future.value('data');
    if (!mounted) return;
    Navigator.of(context).pop(); // Instance method can check mounted
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// avoid_context_in_static_methods (Comprehensive/INFO)
// =========================================================================
// Warns when BuildContext is used in SYNC static methods.
// Sync methods are generally safe but the pattern is discouraged.
// NOTE: Async static methods are handled by more specific rules above.

// BAD: BuildContext parameter in sync static method (discouraged)
class BadContextInSyncStaticMethod {
  // expect_lint: avoid_context_in_static_methods
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar();
  }

  // expect_lint: avoid_context_in_static_methods
  static ThemeData getTheme(BuildContext ctx) {
    return Theme.of(ctx);
  }
}

// BAD: Multiple BuildContext parameters in sync static method
class BadMultipleContextParams {
  // expect_lint: avoid_context_in_static_methods
  // expect_lint: avoid_context_in_static_methods
  static void compareContexts(BuildContext ctx1, BuildContext ctx2) {
    // Bad practice - comparing contexts
  }
}

// GOOD: Instance method with context access
class GoodInstanceMethod extends StatefulWidget {
  const GoodInstanceMethod({super.key});

  @override
  State<GoodInstanceMethod> createState() => _GoodInstanceMethodState();
}

class _GoodInstanceMethodState extends State<GoodInstanceMethod> {
  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(); // Instance method can check mounted
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using navigator key instead of context
class GoodNavigatorKey {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static void navigate(Widget page) {
    navigatorKey.currentState?.push(page); // No context needed
  }
}

// Helper class for GlobalKey mock
class GlobalKey<T extends State> {
  T? currentState;
}

class NavigatorState extends State {
  void push(Widget page) {}

  @override
  Widget build(BuildContext context) => Container();
}

// Helper classes for bug report test cases
class ContactModel {}

class FamilyGroupModel {}

Future<bool> showDialogCommon({
  required BuildContext context,
  required Widget child,
}) async {
  return true;
}
