// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: unused_field
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
  State<GoodAsyncInstanceMethod> createState() => _GoodAsyncInstanceMethodState();
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
