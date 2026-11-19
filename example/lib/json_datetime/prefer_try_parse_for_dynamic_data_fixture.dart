// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_try_parse_for_dynamic_data` lint rule.

void badDynamicInput(String userInput) {
  // expect_lint: prefer_try_parse_for_dynamic_data
  final age = int.parse(userInput);
}

void badInvalidLiteral() {
  // expect_lint: prefer_try_parse_for_dynamic_data
  final age = int.parse('abc');
}

void goodValidLiteral() {
  final age = int.parse('42');
}

void goodRegexCaptureGroup(String token) {
  final withSep = RegExp(r'^(\d{1,4})([\s/\\_.-])(\d{1,2})\2(\d{1,4})$');
  final rx = withSep.firstMatch(token);
  if (rx == null) return;

  final a = int.parse(rx[1]!);
  final b = int.parse(rx.group(3)!);
  final c = int.parse(rx[4]!);
}

void goodRegexGuardedSubstring(String password) {
  final noSep = RegExp(r'^\d{4,8}$');
  for (int i = 0; i <= password.length - 4; i++) {
    for (int j = i + 3; j <= i + 7 && j < password.length; j++) {
      final token = password.substring(i, j + 1);
      if (!noSep.hasMatch(token)) continue;

      final year = int.parse(token.substring(0, 4));
      final month = int.parse(token.substring(4, 6));
      final day = int.parse(token.substring(6));
    }
  }
}

int goodInlineRegexDigitGroups(String trimmed) {
  final RegExpMatch? m = RegExp(r'^--(\d{2})-?(\d{2})$').firstMatch(trimmed);
  if (m == null) return 0;
  final int month = int.parse(m.group(1)!);
  final int day = int.parse(m.group(2)!);
  return month * 100 + day;
}

const String _apiBase = 'https://example.com/api';

// GOOD: constants and percent-encoded parts cannot make the URI malformed.
Uri goodConstBaseUri() => Uri.parse('$_apiBase/items');
Uri goodEncodedQueryUri(String v) =>
    Uri.parse('app:///co?q=${Uri.encodeComponent(v)}');
