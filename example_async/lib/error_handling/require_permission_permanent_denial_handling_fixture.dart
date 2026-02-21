// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_permission_permanent_denial_handling` lint rule.

// NOTE: require_permission_permanent_denial_handling fires on
// permission request checks missing isPermanentlyDenied handling.
// Requires Permission package method call patterns.
//
// BAD:
// final status = await Permission.camera.request();
// if (status.isDenied) { ... } // missing isPermanentlyDenied
//
// GOOD:
// final status = await Permission.camera.request();
// if (status.isPermanentlyDenied) { openAppSettings(); }

void main() {}
