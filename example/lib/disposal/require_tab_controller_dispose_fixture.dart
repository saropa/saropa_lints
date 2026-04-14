// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_tab_controller_dispose` lint rule.

// NOTE: require_tab_controller_dispose fires in widget/State classes.
// Requires class extending State<T> with controller fields.
//
// BAD:
// // late TabController _ctrl; // not disposed in dispose()
//
// GOOD:
// // @override void dispose() { _ctrl.dispose(); super.dispose(); }

void main() {}
