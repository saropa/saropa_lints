// Shared guide-parsing logic for migration pack rule codes. Used by both
// tool/generate_migration_pack_codes.dart (regenerates
// lib/src/config/rule_pack_migration_codes.dart from the guides) and
// test/config/rule_packs_migration_guide_sync_test.dart (verifies the
// generated file hasn't drifted from the guides). Keeping the guide-file
// map and row-parsing regex in one place means the generator and its
// drift test can never disagree about how to read a guide.
library;

import 'dart:io';

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

/// Known dedup count for flutter_skill_lints: this many source rules map
/// to a saropa rule that another source rule already claims, so the final
/// unique code count is (total - GAP - PARTIAL - knownDedupDelta). Shared
/// between the generator and the drift test so neither can silently drift.
/// As of 2026-09-02: prefer_dedicated_media_query_method and
/// prefer_sliver_prefix each have two source rules mapping to them.
const int kFlutterSkillLintsDedupDelta = 2;

/// Extracts backtick-wrapped identifiers from a guide table cell.
final _codePattern = RegExp(r'`([a-zA-Z0-9_]+)`');

/// Extracts the set of saropa rule codes a guide's `HAVE`/`ENHANCED` rows
/// declare, expanding `a / b` fan-out cells (one source rule mapping to
/// multiple saropa rules) into multiple codes.
Set<String> codesFromGuideTable(String guideContent, String statusTag) {
  // Build the full pattern dynamically because the status tag varies.
  final rowPattern = RegExp(
    r'^\| `[A-Za-z0-9_-]+` \| '
    '\\*{0,2}$statusTag\\*{0,2}'
    r' \| (.+?) \|$',
    multiLine: true,
  );
  final codes = <String>{};
  for (final row in rowPattern.allMatches(guideContent)) {
    final eqCell = row.group(1)!;
    // Split on "/" for fan-out cells (e.g. "`rule_a` / `rule_b`").
    for (final part in eqCell.split('/')) {
      final match = _codePattern.firstMatch(part);
      if (match != null) codes.add(match.group(1)!);
    }
  }
  return codes;
}

/// Matches the standard `Coverage: N rules — X HAVE (Y%)` summary line.
final _coveragePattern = RegExp(
  r'Coverage: (\d+) rules? — (\d+) HAVE \((\d+)%\)',
);

/// Parses a guide's `Coverage: N rules — X HAVE (Y%), ...` summary line.
/// Returns null if the line is missing or doesn't match the expected shape
/// (some tiny guides phrase coverage differently — callers should fall
/// back to a generic comment in that case).
({int total, int have, int percent})? parseCoverageLine(String guideContent) {
  final match = _coveragePattern.firstMatch(guideContent);
  if (match == null) return null;
  return (
    total: int.parse(match.group(1)!),
    have: int.parse(match.group(2)!),
    percent: int.parse(match.group(3)!),
  );
}

/// Builds the descriptive comment line that appears above a pack's code
/// set in the generated file, using the guide's coverage summary when
/// available.
String buildPackComment(
  String packId,
  String tag,
  Set<String> codes,
  String guideContent,
) {
  final coverage = parseCoverageLine(guideContent);
  final name = packId.replaceFirst('migrate_', '');
  if (coverage == null) return '  // $name — ${codes.length} $tag codes.';
  final fanOut = codes.length != coverage.have
      ? ' (${codes.length} unique saropa codes after fan-out)'
      : '';
  return '  // $name — ${coverage.have} $tag rules covering '
      '${coverage.percent}% of ${coverage.total} total$fanOut.';
}

/// Resolves the saropa_lints repo root by walking up from [Directory.current]
/// until a directory containing pubspec.yaml is found. Used by generator
/// tools that need absolute paths to lib/, doc/, and tiers.dart.
String findRepoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root (pubspec.yaml not found)');
    }
    dir = parent;
  }
  return dir.path;
}

/// Returns every single-quoted identifier in [content] that appears on
/// a non-comment line, so commented-out rule names (e.g.
/// `// 'old_rule' removed v4.2`) don't false-pass validation.
/// Only strips `//` line comments — tiers.dart does not use `/* */`
/// block comments (verified 2026-09-02).
Set<String> activeQuotedIdentifiers(String content) {
  final pattern = RegExp(r"'([a-zA-Z0-9_]+)'");
  return content
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .expand((line) => pattern.allMatches(line))
      .map((m) => m.group(1)!)
      .toSet();
}

/// Extracts a `const ... = { ... };` block starting at [startMarker]
/// up to and including its matching closing `};`. Uses the first `};`
/// after the marker — safe for flat map/set literals but not nested
/// blocks containing `};` on their own line.
String extractBlock(String content, String startMarker) {
  final start = content.indexOf(startMarker);
  if (start == -1) {
    throw StateError('Could not find block starting with: $startMarker');
  }
  final end = content.indexOf('\n};', start);
  if (end == -1) {
    throw StateError('Could not find end of block starting with: $startMarker');
  }
  return content.substring(start, end + 3);
}

/// Extracts the quoted rule codes inside a single `'packId': { ... },`
/// set literal from the existing generated file. Used to carry forward
/// flutter_skill_lints' code set (no guide table to re-derive from).
Set<String> extractPackCodes(String content, String packId) {
  final keyPattern = RegExp("'$packId': \\{");
  final start = keyPattern.firstMatch(content);
  if (start == null) {
    throw StateError('Could not find existing entry for $packId');
  }
  final end = content.indexOf('\n  },', start.end);
  if (end == -1) {
    throw StateError('Could not find end of entry for $packId');
  }
  final block = content.substring(start.end, end);
  return RegExp(
    r"'([a-zA-Z0-9_]+)'",
  ).allMatches(block).map((m) => m.group(1)!).toSet();
}
