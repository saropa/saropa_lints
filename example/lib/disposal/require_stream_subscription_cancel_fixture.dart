// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_stream_subscription_cancel` lint rule.

// NOTE: require_stream_subscription_cancel fires in widget/State classes.
// Requires class extending State<T> with controller fields.
//
// BAD:
// // late StreamSubscription _sub; // not canceled in dispose()
//
// GOOD:
// // @override void dispose() { _sub.cancel(); super.dispose(); }

void main() {}
