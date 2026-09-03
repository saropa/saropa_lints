// Shared guide-parsing logic for migration pack rule codes. Used by both
// tool/generate_migration_pack_codes.dart (regenerates
// lib/src/config/rule_pack_migration_codes.dart from the guides) and
// test/config/rule_packs_migration_guide_sync_test.dart (verifies the
// generated file hasn't drifted from the guides). Keeping the guide-file
// map and row-parsing regex in one place means the generator and its
// drift test can never disagree about how to read a guide.
library;

/// Guide filename per pack id, relative to doc/guides/migration_guides/.
/// Matches `migration_from_<suffix>.md` for every pack except
/// very_good_analysis, whose guide uses the "vga" shorthand instead of the
/// full package name.
const Map<String, String> kMigrationPackGuideFiles = {
  'migrate_dcm': 'migration_from_dcm.md',
  'migrate_flutter_skill_lints': 'migration_from_flutter_skill_lints.md',
  'migrate_many_lints': 'migration_from_many_lints.md',
  'migrate_awesome_lints': 'migration_from_awesome_lints.md',
  'migrate_dart_code_linter': 'migration_from_dart_code_linter.md',
  'migrate_dart_code_metrics_presets':
      'migration_from_dart_code_metrics_presets.md',
  'migrate_pyramid_lint': 'migration_from_pyramid_lint.md',
  'migrate_solid_lints': 'migration_from_solid_lints.md',
  'migrate_flutter_quality_lints': 'migration_from_flutter_quality_lints.md',
  'migrate_essential_lints': 'migration_from_essential_lints.md',
  'migrate_leancode_lint': 'migration_from_leancode_lint.md',
  'migrate_mad_lint': 'migration_from_mad_lint.md',
  'migrate_flutter_doctor_ai': 'migration_from_flutter_doctor_ai.md',
  'migrate_ripplearc_linter': 'migration_from_ripplearc_linter.md',
  'migrate_flutter_hooks_lint': 'migration_from_flutter_hooks_lint.md',
  'migrate_bloc_lint': 'migration_from_bloc_lint.md',
  'migrate_very_good_analysis': 'migration_from_vga.md',
  'migrate_flutter_best_practices_lints':
      'migration_from_flutter_best_practices_lints.md',
  'migrate_flutter_custom_lints': 'migration_from_flutter_custom_lints.md',
  'migrate_flutter_sane_lints': 'migration_from_flutter_sane_lints.md',
  'migrate_klin_dart': 'migration_from_klin_dart.md',
  'migrate_hardcoded_strings_lint': 'migration_from_hardcoded_strings_lint.md',
  'migrate_equatable_lint': 'migration_from_equatable_lint.md',
  'migrate_accessibility_lint': 'migration_from_accessibility_lint.md',
};

/// Packs whose guide uses `**ENHANCED**` instead of `HAVE` in its mapping
/// table's status column. very_good_analysis is a preset-only package
/// where saropa only ever supersedes a stock rule with a strictly better
/// version — every other row is `N/A (stock analyzer rule)`, never `HAVE`.
const Set<String> kMigrationPacksUsingEnhancedTag = {
  'migrate_very_good_analysis',
};

/// Packs with no per-rule mapping table in their guide at all, so their
/// code set can't be re-derived from guide text and must be carried
/// forward from the existing generated file instead. flutter_skill_lints
/// points readers at plans/GAP_ANALYSIS.md rather than enumerating its 231
/// HAVE rows inline — enumerating them requires cross-referencing the
/// source package's GitHub rule tree, not just parsing the guide.
const Set<String> kMigrationPacksWithoutGuideTable = {
  'migrate_flutter_skill_lints',
};

/// Extracts the set of saropa rule codes a guide's `HAVE`/`ENHANCED` rows
/// declare, expanding `a / b` fan-out cells (one source rule mapping to
/// multiple saropa rules) into multiple codes.
Set<String> codesFromGuideTable(String guideContent, String statusTag) {
  final rowPattern = RegExp(
    r'^\| `[A-Za-z0-9_-]+` \| '
    '\\*{0,2}$statusTag\\*{0,2}'
    r' \| (.+?) \|$',
    multiLine: true,
  );
  final codePattern = RegExp(r'`([a-zA-Z0-9_]+)`');
  final codes = <String>{};
  for (final row in rowPattern.allMatches(guideContent)) {
    final eqCell = row.group(1)!;
    for (final part in eqCell.split('/')) {
      final match = codePattern.firstMatch(part);
      if (match != null) codes.add(match.group(1)!);
    }
  }
  return codes;
}

/// Parses a guide's `Coverage: N rules — X HAVE (Y%), ...` summary line.
/// Returns null if the line is missing or doesn't match the expected shape
/// (some tiny guides phrase coverage differently — callers should fall
/// back to a generic comment in that case).
({int total, int have, int percent})? parseCoverageLine(String guideContent) {
  final match = RegExp(
    r'Coverage: (\d+) rules? — (\d+) HAVE \((\d+)%\)',
  ).firstMatch(guideContent);
  if (match == null) return null;
  return (
    total: int.parse(match.group(1)!),
    have: int.parse(match.group(2)!),
    percent: int.parse(match.group(3)!),
  );
}
