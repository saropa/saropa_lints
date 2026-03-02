// ignore_for_file: avoid_print, depend_on_referenced_packages, unused_element
// Fixture for roadmap detail 9 rules: bad/good and false-positive examples.
// Use with analysis_options that enable these rules for testing.

import 'package:http/http.dart' as http;

// -----------------------------------------------------------------------------
// banned_identifier_usage — requires config in analysis_options_custom.yaml:
//   banned_usage:
//     entries:
//       - identifier: 'print'
//         reason: 'Use Logger instead'
// With that config, the following triggers:
void bannedUsageBad() {
  print('hello'); // LINT: banned_identifier_usage when print is in config
}

void bannedUsageGood() {
  // Logger.debug('hello'); // OK
}

// -----------------------------------------------------------------------------
// prefer_csrf_protection — web/http project, state-changing + Cookie, no CSRF
void preferCsrfBad(String sessionCookie) {
  http.post(
    Uri.parse('https://api.example.com/transfer'),
    headers: {'Cookie': sessionCookie}, // LINT: no CSRF or Bearer
    body: '{}',
  );
}

void preferCsrfGood(String sessionCookie, String csrfToken) {
  http.post(
    Uri.parse('https://api.example.com/transfer'),
    headers: {
      'Cookie': sessionCookie,
      'X-CSRF-Token': csrfToken,
    },
    body: '{}',
  );
}

// -----------------------------------------------------------------------------
// prefer_semver_version — checked on pubspec.yaml; no inline example
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// prefer_sqflite_encryption — sqflite + sensitive path, no sqlcipher
Future<void> preferSqfliteEncryptionBad(dynamic openDatabase, dynamic join,
    dynamic getDatabasesPath, String createTable) async {
  await openDatabase(
    join(await getDatabasesPath(), 'user_accounts.db'), // LINT: sensitive name
    version: 1,
    onCreate: (db, version) => db.execute(createTable),
  );
}

// -----------------------------------------------------------------------------
// require_conflict_resolution_strategy — sync method overwrites without check
Future<void> requireConflictResolutionBad(
    dynamic api, dynamic box, List<dynamic> remote) async {
  await api.put('/items/1', {}); // LINT: no updatedAt/version check
}

Future<void> requireConflictResolutionGood(
    dynamic api, dynamic localItem, dynamic remoteItem) async {
  if (localItem.updatedAt.isAfter(remoteItem.updatedAt)) {
    await api.put('/items/${localItem.id}', localItem.toJson());
  }
}

// -----------------------------------------------------------------------------
// require_connectivity_timeout — http/dio without .timeout()
Future<void> requireConnectivityTimeoutBad() async {
  final response = await http.get(Uri.parse('https://example.com')); // LINT
  print(response.statusCode);
}

Future<void> requireConnectivityTimeoutGood() async {
  final response = await http
      .get(Uri.parse('https://example.com'))
      .timeout(const Duration(seconds: 30));
  print(response.statusCode);
}

// -----------------------------------------------------------------------------
// require_init_state_idempotent — addListener in initState without remove in dispose
// (Flutter State class required; simplified here as pattern only)
// class _BadState extends State<BadWidget> {
//   @override
//   void initState() {
//     super.initState();
//     eventBus.addListener('auth', _onAuth); // LINT
//   }
//   @override
//   void dispose() { super.dispose(); } // missing removeListener
// }

// -----------------------------------------------------------------------------
// require_input_validation — .text in API body without trim/validate
Future<void> requireInputValidationBad(
    dynamic api, dynamic nameController) async {
  await api.post('/users', body: {'name': nameController.text}); // LINT
}

Future<void> requireInputValidationGood(
    dynamic api, dynamic nameController) async {
  final name = nameController.text.trim();
  if (name.isEmpty) return;
  await api.post('/users', body: {'name': name});
}
