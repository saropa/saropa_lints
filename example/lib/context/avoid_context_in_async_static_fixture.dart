// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_context_in_async_static` lint rule.
///
/// The rule flags a BuildContext parameter on an async static method ONLY when
/// the body uses that context after an await without a mounted guard. Context
/// used before the first await, or only behind a mounted guard, is safe.
/// Context passed solely as an argument to the awaited call is also safe — the
/// callee receives it synchronously before any suspension point.

class BuildContext {
  bool get mounted => true;
}

Future<int> load() async => 0;

Future<bool?> showDialogStub({required BuildContext context}) async => true;

Future<void> showDialogCommon({
  required BuildContext context,
  String? title,
}) async {}

void doSomething() {}

void useContext(BuildContext context) {}

void debugException(Object error, StackTrace stack) {}

class ShowHelper {
  // GOOD: context used only after a mounted guard — no lint.
  static Future<void> showThing(BuildContext context) async {
    final data = await load();
    if (!context.mounted) {
      return;
    }
    useContext(context);
  }

  // GOOD: context used only before the first await — no async gap yet, no lint.
  static Future<void> showPrompt(BuildContext context) async {
    final result = await showDialogStub(context: context);
    if (result == true) {
      doSomething();
    }
  }

  // GOOD: positive-block mounted guard around the post-await use — no lint.
  static Future<void> showBlock(BuildContext context) async {
    await load();
    if (context.mounted) {
      useContext(context);
    }
  }

  // BAD: context used after await with no guard — LINT on the parameter.
  // expect_lint: avoid_context_in_async_static
  static Future<void> showUnguarded(BuildContext context) async {
    await load();
    useContext(context);
  }

  // GOOD: context passed only as arg to the awaited call — consumed
  // synchronously before suspension. No post-await context read.
  static Future<void> showDialogForward(BuildContext context) async {
    await showDialogCommon(context: context, title: 'Hello');
  }

  // GOOD: context passed as arg to awaited call inside try-catch — same
  // safe pattern, the try wrapper does not change the synchronous
  // consumption of context.
  static Future<void> showDialogInTryCatch(BuildContext context) async {
    try {
      await showDialogCommon(context: context);
    } on Object catch (error, stack) {
      debugException(error, stack);
    }
  }

  // BAD: context passed to the awaited call AND read after the await — the
  // post-await read is the violation, not the arg to the awaited call.
  // expect_lint: avoid_context_in_async_static
  static Future<void> showAndRead(BuildContext context) async {
    await showDialogCommon(context: context);
    useContext(context);
  }

  // GOOD: multiple awaits but context only appears as arg to the first —
  // no post-await context reads.
  static Future<void> multipleAwaitsContextOnlyFirst(
    BuildContext context,
  ) async {
    await showDialogCommon(context: context);
    await load();
    doSomething();
  }

  // GOOD: context as positional arg to awaited call — same safe pattern.
  static Future<void> showDialogPositionalArg(BuildContext context) async {
    await useContextAsync(context);
  }
}

Future<void> useContextAsync(BuildContext context) async {}

void main() {}
