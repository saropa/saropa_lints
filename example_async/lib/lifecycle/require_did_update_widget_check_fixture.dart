// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_did_update_widget_check` lint rule.

// NOTE: require_did_update_widget_check fires on didUpdateWidget()
// methods without property comparison (widget-only).
//
// BAD:
// void didUpdateWidget(old) { _reload(); } // always reloads
//
// GOOD:
// void didUpdateWidget(old) {
//   if (old.id != widget.id) _reload(); // only when changed
// }

void main() {}
