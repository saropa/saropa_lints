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

// =========================================================================
// avoid_context_in_static_methods
// =========================================================================
// Warns when BuildContext is used in static methods.

// BAD: BuildContext parameter in static method
class BadContextInStaticMethod {
  // expect_lint: avoid_context_in_static_methods
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar();
  }

  // expect_lint: avoid_context_in_static_methods
  static Future<void> navigate(BuildContext context) async {
    Navigator.of(context).push(Container());
  }
}

// BAD: Multiple BuildContext parameters in static method
class BadMultipleContextParams {
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
