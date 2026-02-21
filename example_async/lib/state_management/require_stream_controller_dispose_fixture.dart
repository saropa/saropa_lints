// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_stream_controller_dispose` lint rule.

// NOTE: require_stream_controller_dispose fires on StreamController
// fields not closed in dispose().
//
// BAD:
// class _State extends State<W> {
//   final _ctrl = StreamController<int>(); // never closed
// }
//
// GOOD:
// @override void dispose() { _ctrl.close(); super.dispose(); }

void main() {}
