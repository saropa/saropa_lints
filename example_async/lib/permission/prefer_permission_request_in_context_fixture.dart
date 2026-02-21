// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_permission_request_in_context` lint rule.

// NOTE: prefer_permission_request_in_context fires on permission
// requests in startup functions (main, initState) without context.
//
// BAD:
// void main() { Permission.camera.request(); } // no user context
//
// GOOD:
// void onCameraButtonTap() { Permission.camera.request(); }

void main() {}
