// ignore_for_file: unused_local_variable, unused_element, undefined_class
// ignore_for_file: non_constant_identifier_names, undefined_identifier

/// Fixture for `avoid_go_router_legacy_redirect` lint rule.
///
/// go_router 6.0 changed the redirect callback to `(context, state)`. The rule
/// flags a single-parameter redirect closure. Gated to the `go_router_6` pack.
library;

import 'package:go_router/go_router.dart';

bool get isLoggedIn => false;

// BAD: pre-6.0 single-argument redirect closure.
final badRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/home',
      redirect: (state) => isLoggedIn ? null : '/login',
      // LINT: redirect now takes (BuildContext context, GoRouterState state)
    ),
  ],
);

// GOOD: go_router 6.0+ two-argument redirect.
final goodRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/home',
      redirect: (context, state) => isLoggedIn ? null : '/login',
    ),
  ],
);
