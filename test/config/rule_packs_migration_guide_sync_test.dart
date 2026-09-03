// Drift guard: migration pack code sets vs the HAVE tables in their source
// migration guides. Guides are hand-authored markdown; pack code sets in
// rule_pack_migration_codes.dart are hand-derived from them. Nothing keeps
// the two in sync automatically, so this test re-derives each pack's code
// set from its guide's `| source | HAVE | saropa |` rows and fails loudly
// if a guide edit (new HAVE row, renamed saropa target, etc.) isn't mirrored
// into the pack file.
library;

import 'dart:io';

import 'package:saropa_lints/src/config/rule_pack_migration_codes.dart';
import 'package:test/test.dart';

import '../../tool/migration_pack_guide_sync.dart';

/// Packs whose guide does not carry a standard `| source | HAVE | saropa |`
/// table, so they can't be diffed row-by-row here. Combines
/// [kMigrationPacksWithoutGuideTable] (flutter_skill_lints — see
/// GAP_ANALYSIS.md instead) with very_good_analysis, whose custom-
/// equivalent rows are diffed separately below via the `ENHANCED` tag.
final Set<String> _packsWithoutHaveTable = {
  ...kMigrationPacksWithoutGuideTable,
  ...kMigrationPacksUsingEnhancedTag,
};

void main() {
  final guideDir = Directory('doc/guides/migration_guides');

  test('every migration pack has a guide file mapping', () {
    expect(
      kMigrationPackGuideFiles.keys.toSet(),
      kRulePackMigrationCodes.keys.toSet(),
      reason:
          'A pack was added/removed in rule_pack_migration_codes.dart '
          'without updating kMigrationPackGuideFiles in this test.',
    );
  });

  group('pack codes match guide HAVE tables', () {
    for (final packId in kRulePackMigrationCodes.keys) {
      if (_packsWithoutHaveTable.contains(packId)) continue;

      test(packId, () {
        final guideFile = File(
          '${guideDir.path}/${kMigrationPackGuideFiles[packId]}',
        );
        final content = guideFile.readAsStringSync();
        final guideCodes = codesFromGuideTable(content, 'HAVE');
        final packCodes = kRulePackMigrationCodes[packId]!;

        expect(
          guideCodes,
          isNotEmpty,
          reason:
              'No `| source | HAVE | saropa |` rows found in '
              '${kMigrationPackGuideFiles[packId]} — guide format may have '
              'changed, or this pack belongs in _packsWithoutHaveTable.',
        );
        expect(
          packCodes,
          guideCodes,
          reason:
              'migrate_${packId.replaceFirst('migrate_', '')} in '
              'rule_pack_migration_codes.dart has drifted from the HAVE '
              'rows in ${kMigrationPackGuideFiles[packId]}.',
        );
      });
    }
  });

  test('very_good_analysis pack codes match guide ENHANCED rows', () {
    final content = File(
      '${guideDir.path}/${kMigrationPackGuideFiles['migrate_very_good_analysis']}',
    ).readAsStringSync();
    final guideCodes = codesFromGuideTable(content, 'ENHANCED');
    expect(guideCodes, isNotEmpty);
    expect(kRulePackMigrationCodes['migrate_very_good_analysis'], guideCodes);
  });

  test(
    'flutter_skill_lints pack code count matches guide-documented dedup',
    () {
      // The guide has no per-rule HAVE table (see GAP_ANALYSIS.md instead),
      // so this checks the arithmetic recorded in the pack file's own
      // comment: 279 total - 41 GAP - 7 PARTIAL = 231 source HAVE rules,
      // 2 of which map to a saropa rule another source rule already
      // claims (prefer_dedicated_media_query_method, prefer_sliver_prefix),
      // leaving 229 unique codes. If the guide's GAP/PARTIAL counts move,
      // this recomputation moves with them.
      final content = File(
        '${guideDir.path}/migration_from_flutter_skill_lints.md',
      ).readAsStringSync();

      final gapRows = RegExp(
        r'^\| `[a-zA-Z0-9_-]+` \| TODO \|',
        multiLine: true,
      ).allMatches(content).length;
      final partialRows = RegExp(
        r'^\| `[a-zA-Z0-9_-]+` \| PARTIAL \|',
        multiLine: true,
      ).allMatches(content).length;
      final totalMatch = RegExp(
        r'\*\*Rule count\*\* \| (\d+) rules',
      ).firstMatch(content);
      expect(
        totalMatch,
        isNotNull,
        reason: 'Guide "Why Migrate?" table format changed.',
      );
      final total = int.parse(totalMatch!.group(1)!);

      const knownDedupDelta = 2;
      final expectedUniqueHave =
          total - gapRows - partialRows - knownDedupDelta;

      expect(
        kRulePackMigrationCodes['migrate_flutter_skill_lints']!.length,
        expectedUniqueHave,
        reason:
            'flutter_skill_lints total/GAP/PARTIAL counts in the guide '
            'moved but rule_pack_migration_codes.dart was not '
            're-derived from an updated source enumeration.',
      );
    },
  );
}
