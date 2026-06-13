// Regression test for avoid_drift_unsafe_web_storage: the rule flagged any
// `WebDatabase(...)` constructor or any method named `unsafeIndexedDb`, with no
// drift-import guard (every sibling drift rule has one). A project that defines
// its own `WebDatabase` or `unsafeIndexedDb()` and never uses drift was flagged.
// The fix gates both visitors on a drift import. Verified via the oracle: a
// file with no drift import no longer fires.
library;

import 'package:saropa_lints/src/rules/packages/drift_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('avoid_drift_unsafe_web_storage', () {
    test('does NOT fire on WebDatabase in a file with no drift import', () async {
      final codes = await reportedRuleCodes(AvoidDriftUnsafeWebStorageRule(), '''
class WebDatabase {
  WebDatabase(String name);
}

WebDatabase open() => WebDatabase('app.db');
''');
      expect(codes, isNot(contains('avoid_drift_unsafe_web_storage')));
    });

    test('does NOT fire on an unrelated unsafeIndexedDb() with no drift import', () async {
      final codes = await reportedRuleCodes(AvoidDriftUnsafeWebStorageRule(), '''
class Storage {
  void unsafeIndexedDb() {}
}

void main() {
  Storage().unsafeIndexedDb();
}
''');
      expect(codes, isNot(contains('avoid_drift_unsafe_web_storage')));
    });
  });
}
