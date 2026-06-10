// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_context_in_async_static` lint rule.
///
/// The rule flags a BuildContext parameter on an async static method ONLY when
/// the body uses that context after an await without a mounted guard. Context
/// used before the first await, or only behind a mounted guard, is safe.

class BuildContext {
  bool get mounted => true;
}

Future<int> load() async => 0;

Future<bool?> showDialogStub({required BuildContext context}) async => true;

void doSomething() {}

void useContext(BuildContext context) {}

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
}

void main() {}
