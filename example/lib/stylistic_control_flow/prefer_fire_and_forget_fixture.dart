// ignore_for_file: unused_element
// Fixture for prefer_fire_and_forget: await when result unused.

Future<void> logEvent() async {}

// LINT: await but result unused
void bad() async {
  await logEvent();
}

// OK: result used or unawaited
void good() async {
  final f = logEvent();
  await f;
}
