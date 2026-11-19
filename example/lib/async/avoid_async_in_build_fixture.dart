// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_async_in_build` lint rule.

class Widget {
  const Widget();
}

class StatefulWidget extends Widget {}

class BuildContext {}

abstract class State<T extends StatefulWidget> {
  Object build(BuildContext context);
}

// BAD: Should trigger avoid_async_in_build
class _BadBuild extends State<StatefulWidget> {
  @override
  // expect_lint: avoid_async_in_build
  Future<Widget> build(BuildContext context) async => const Widget(); // async build
}

// GOOD: non-widget class (e.g. Serverpod WidgetRoute) must NOT trigger
class WidgetRoute {}

class _ServerpodRoute extends WidgetRoute {
  Future<String> build(Object session, Object request) async => 'ok';
}

// GOOD: Should NOT trigger avoid_async_in_build
class _GoodBuild {
  void build() {} // sync build method
}

void main() {}
