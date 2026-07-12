// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_plus_missing_permission_check` (INFO).
/// BAD: data ops with no hasPermissions/requestPermissions/autoPermissions
/// anywhere in the file.
library;

import 'package:device_calendar_plus/device_calendar_plus.dart';

// No `good()` counterpart here: this rule scans the whole file for a
// permission call, so a compliant call anywhere in the file would suppress
// the diagnostic above and defeat the fixture.
Future<void> bad() async {
  // expect_lint: device_calendar_plus_missing_permission_check
  final calendars = await DeviceCalendar.instance.listCalendars();
}

// OK: an unrelated class's same-named method is not a DeviceCalendar call —
// the rule requires the resolved receiver type to be DeviceCalendar, so this
// does not count toward (and would not itself trigger) the rule above.
class EventFactory {
  Future<String> createEvent() async => 'x';
}

Future<void> unrelatedSameNamedMethod() async {
  final factory = EventFactory();
  await factory.createEvent();
}

// OK: an unrelated local variable named autoPermissions is not
// DeviceCalendar.instance.autoPermissions — it must not suppress the
// diagnostic above (the rule checks the resolved receiver, not the bare
// identifier name).
Future<void> unrelatedAutoPermissionsVariable() async {
  final autoPermissions = true;
  if (autoPermissions) {
    // no-op: demonstrates the local flag has no effect on the rule
  }
}
