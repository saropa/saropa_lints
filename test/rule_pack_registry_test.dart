import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:test/test.dart';

void main() {
  group('generated registry + composite packs', () {
    test('avoid_isar_import_with_drift is in both drift and isar packs', () {
      expect(
        ruleCodesForPack('drift'),
        contains('avoid_isar_import_with_drift'),
      );
      expect(
        ruleCodesForPack('isar'),
        contains('avoid_isar_import_with_drift'),
      );
    });

    test('collection_compat is merged on top of generated map', () {
      expect(
        ruleCodesForPack('collection_compat'),
        equals({'avoid_collection_methods_with_unrelated_types'}),
      );
      expect(knownRulePackIds, contains('collection_compat'));
    });
  });
}
