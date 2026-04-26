// ignore_for_file: unused_element
// Test fixture: require_notification_for_long_tasks — camelCase / `dbProcessAll`
// exclusions only (no foreground-skip literals from the rule in this file).

Future<bool> _isFacebookFriendsImportAllowedNow() async => true;

Future<void> dbProcessAllContactListGroupMemberships() async {}

Future<void> boundaryOnlyMustNotLint() async {
  await _isFacebookFriendsImportAllowedNow();
  await dbProcessAllContactListGroupMemberships();
}
