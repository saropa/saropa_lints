// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages

/// Fixture for `prefer_go_router_builder` lint rule.

// BAD: Manual route config instead of GoRouter builder
// expect_lint: prefer_go_router_builder
final routes = {'/': (context) => HomeScreen()};

// GOOD: GoRouter with builder
// final goRouter = GoRouter(routes: [...], builder: (context, state) => ...);

void main() {}
