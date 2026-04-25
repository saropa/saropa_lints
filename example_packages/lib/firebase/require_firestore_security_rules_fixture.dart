// ignore_for_file: unused_local_variable

import 'package:cloud_firestore/cloud_firestore.dart';

/// Fixture for `require_firestore_security_rules`.
void openFirestoreWithoutRulesFile() {
  // LINT: Example repo root has no firestore.rules in CI fixture layout.
  final _ = FirebaseFirestore.instance;
}
