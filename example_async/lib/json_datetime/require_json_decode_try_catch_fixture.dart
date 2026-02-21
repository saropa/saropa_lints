// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `require_json_decode_try_catch` lint rule.

// NOTE: require_json_decode_try_catch fires on jsonDecode() calls
// not wrapped in try-catch for FormatException.
//
// BAD:
// final data = jsonDecode(response); // crash on malformed JSON
//
// GOOD:
// try {
//   final data = jsonDecode(response);
// } on FormatException catch (e) {
//   handleError(e);
// }

void main() {}
