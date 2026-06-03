// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `require_intl_date_format_locale` lint rule.

import 'package:intl/intl.dart';

void goodExamples(DateTime date, String locale) {
  // OK: named factory constructor with locale as its first argument.
  final a = DateFormat.yMMMMd(locale).format(date);
  final b = DateFormat.jm(locale).format(date);
  final c = DateFormat.yMd(locale).format(date);

  // OK: unnamed constructor with both pattern and locale.
  final d = DateFormat('yyyy-MM-dd', locale).format(date);
}

void badExamples(DateTime date) {
  // LINT: named factory constructor with no locale.
  final a = DateFormat.yMMMMd().format(date);

  // LINT: named factory constructor with no locale.
  final b = DateFormat.jm().format(date);

  // LINT: unnamed constructor with pattern but no locale.
  final c = DateFormat('yyyy-MM-dd').format(date);
}
