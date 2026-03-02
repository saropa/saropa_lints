// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_auto_route_path_params_simple` lint rule.

// BAD: Complex path params instead of simple
// expect_lint: prefer_auto_route_path_params_simple
const badPath = '/user/:id/posts/:postId/comments/:commentId';

// GOOD: Simple path params
const goodPath = '/user/:id';

void main() {}
