// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_user_controlled_urls` lint rule.

// NOTE: avoid_user_controlled_urls fires on URLs constructed from
// user input (textController.text, user-provided variables).
//
// BAD:
// final url = Uri.parse(textController.text);
//
// GOOD:
// final url = Uri.parse('$baseUrl/api/$endpoint'); // server-controlled

void main() {}
