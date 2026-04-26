// ignore_for_file: unused_element
// Test fixture: require_notification_for_long_tasks — must not report.
//
// Covers camelCase boundary false positives (`ImportAllowed` vs `importAll`),
// `dbProcessAll…` DB helpers, and file-level skip via in-app progress signals.
//
/// Doc mentions CircularProgressIndicator so the file matches foreground UI skip.

Future<bool> _isFacebookFriendsImportAllowedNow() async => true;

Future<void> dbProcessAllContactListGroupMemberships() async {}

Future<void> importAllEventsWithStats({
  void Function(String)? onStatusUpdate,
}) async {}

Future<void> goodNoLintForegroundAndBoundaries() async {
  await _isFacebookFriendsImportAllowedNow();
  await dbProcessAllContactListGroupMemberships();
  await importAllEventsWithStats(onStatusUpdate: (_) {});
}
