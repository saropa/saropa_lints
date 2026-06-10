// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_const_declarations

/// Fixture for `avoid_manual_date_formatting` lint rule.
///
/// The rule flags a string interpolation that reads two or more DateTime
/// date properties for display. It must NOT flag: non-DateTime custom types
/// (HebrewDate, CalendarEvent) whose getters happen to share names, or
/// interpolations that build an internal key (named local, key-builder
/// function), where locale formatting does not apply.

// A project-specific calendar type — NOT a DateTime. Its .month/.day getters
// are plain ints; locale date formatting does not apply.
class HebrewDate {
  int get month => 1;
  int get day => 1;
  int get year => 5786;
}

class CalendarEvent {
  int get month => 1;
  int get day => 1;
}

// BAD: real DateTime formatted for display — LINT.
String displayDate(DateTime d) {
  return '${d.year}/${d.month}/${d.day}'; // manual date formatting for display
}

// BAD: toIso8601String + substring manual pattern — LINT.
String isoDate(DateTime d) {
  return d.toIso8601String().substring(0, 10);
}

// GOOD: HebrewDate is not a DateTime — no locale API applies. No lint.
String hebrewLabel(HebrewDate hd) {
  return '${hd.month}/${hd.day}';
}

// GOOD: internal dedup key returned from a key-builder function. Non-display
// context — locale formatting irrelevant. No lint.
String buildEventDedupKey(String label, CalendarEvent event) {
  return '$label|${event.month}|${event.day}';
}

// GOOD: assigned to a key-named local. No lint.
String cacheKeyFor(DateTime dt) {
  final cacheKey = '${dt.year}-${dt.month}-${dt.day}';
  return cacheKey;
}

// GOOD: real DateTime, but the enclosing function builds a cache key. No lint.
String cacheKey(DateTime dt) {
  return '${dt.year}-${dt.month}-${dt.day}';
}

// GOOD: map subscript (IndexExpression) is an internal lookup. No lint.
String? lookup(Map<String, String> map, DateTime d) {
  return map['${d.year}-${d.month}'];
}

void main() {}
