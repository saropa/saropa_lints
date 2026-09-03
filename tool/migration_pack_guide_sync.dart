// Shared guide-parsing for migration pack rule codes. Used by the generator
// and drift test so they can never disagree about how to read a guide.
library;

import 'dart:io';

/// Guide filename per pack id, relative to doc/guides/migration_guides/.
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

/// Packs using `**ENHANCED**` instead of `HAVE` in their guide table.
const Set<String> kMigrationPacksUsingEnhancedTag = {
  'migrate_very_good_analysis',
};

/// Packs with no per-rule mapping table — codes carried forward.
const Set<String> kMigrationPacksWithoutGuideTable = {
  'migrate_flutter_skill_lints',
};

/// Known dedup count for flutter_skill_lints (2 source rules share targets).
const int kFlutterSkillLintsDedupDelta = 2;

final _codePattern = RegExp(r'`([a-zA-Z0-9_]+)`');

/// Extracts saropa rule codes from a guide's HAVE/ENHANCED rows.
Set<String> codesFromGuideTable(String guideContent, String statusTag) {
  final rowPattern = RegExp(
    r'^\| `[A-Za-z0-9_-]+` \| '
    '\\*{0,2}$statusTag\\*{0,2}'
    r' \| (.+?) \|$',
    multiLine: true,
  );
  final codes = <String>{};
  for (final row in rowPattern.allMatches(guideContent)) {
    // Split on "/" for fan-out cells (e.g. "`rule_a` / `rule_b`").
    for (final part in row.group(1)!.split('/')) {
      final match = _codePattern.firstMatch(part);
      if (match != null) codes.add(match.group(1)!);
    }
  }
  return codes;
}

/// Matches `Coverage: N rules — X HAVE (Y%)` summary lines.
final _coveragePattern = RegExp(
  r'Coverage: (\d+) rules? — (\d+) HAVE \((\d+)%\)',
);

/// Parses a guide's coverage summary line. Null if not found.
({int total, int have, int percent})? parseCoverageLine(String content) {
  final m = _coveragePattern.firstMatch(content);
  if (m == null) return null;
  return (
    total: int.parse(m.group(1)!),
    have: int.parse(m.group(2)!),
    percent: int.parse(m.group(3)!),
  );
}

/// Builds the comment line above a pack's code set in the generated file.
String buildPackComment(
  String packId,
  String tag,
  Set<String> codes,
  String guideContent,
) {
  final cov = parseCoverageLine(guideContent);
  final name = packId.replaceFirst('migrate_', '');
  if (cov == null) return '  // $name — ${codes.length} $tag codes.';
  final fanOut = codes.length != cov.have
      ? ' (${codes.length} unique saropa codes after fan-out)'
      : '';
  return '  // $name — ${cov.have} $tag rules covering '
      '${cov.percent}% of ${cov.total} total$fanOut.';
}

/// Walks up from cwd to find the repo root (directory with pubspec.yaml).
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

/// Returns single-quoted identifiers from active (non-comment) lines.
/// Strips both `//` line comments and `/* */` block comments.
Set<String> activeQuotedIdentifiers(String content) {
  // Strip block comments first (may span multiple lines).
  final noBlock = content.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final pattern = RegExp(r"'([a-zA-Z0-9_]+)'");
  return noBlock
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .expand((line) => pattern.allMatches(line))
      .map((m) => m.group(1)!)
      .toSet();
}

/// Extracts a top-level `const ... = { ... };` block via balanced braces.
String extractBlock(String content, String startMarker) {
  final start = content.indexOf(startMarker);
  if (start == -1) throw StateError('Block not found: $startMarker');
  final braceStart = content.indexOf('{', start);
  if (braceStart == -1) throw StateError('No brace in: $startMarker');
  // Walk forward counting braces until balanced.
  var depth = 0;
  for (var i = braceStart; i < content.length; i++) {
    if (content[i] == '{') depth++;
    if (content[i] == '}') depth--;
    if (depth == 0) {
      // Include the trailing semicolon if present.
      final end = (i + 1 < content.length && content[i + 1] == ';')
          ? i + 2
          : i + 1;
      return content.substring(start, end);
    }
  }
  throw StateError('Unbalanced braces in block: $startMarker');
}

/// Extracts quoted rule codes from a `'packId': { ... },` entry using
/// balanced braces so nested sets don't truncate the extraction.
Set<String> extractPackCodes(String content, String packId) {
  final start = RegExp("'$packId': \\{").firstMatch(content);
  if (start == null) throw StateError('No entry for $packId');
  // Walk from the opening brace until the matching close.
  var depth = 1;
  for (var i = start.end; i < content.length; i++) {
    if (content[i] == '{') depth++;
    if (content[i] == '}') depth--;
    if (depth == 0) {
      return RegExp(r"'([a-zA-Z0-9_]+)'")
          .allMatches(content.substring(start.end, i))
          .map((m) => m.group(1)!)
          .toSet();
    }
  }
  throw StateError('Unbalanced braces for $packId');
}

/// Computes per-pack added/removed codes between old generated content
/// and new entries. Returns human-readable diff lines (empty = no change).
/// Catches [StateError] from [extractPackCodes] for packs that don't
/// exist in oldContent yet (new packs) — treats them as all-additions.
List<String> diffPackEntries(
  String oldContent,
  List<({String id, Set<String> codes, String comment})> entries,
) {
  final lines = <String>[];
  for (final e in entries) {
    Set<String> oldCodes;
    try {
      oldCodes = extractPackCodes(oldContent, e.id);
    } on StateError {
      // New pack not in old file — every code is an addition.
      oldCodes = {};
    }
    final added = e.codes.difference(oldCodes);
    final removed = oldCodes.difference(e.codes);
    if (added.isEmpty && removed.isEmpty) continue;
    lines.add('  ${e.id}:');
    for (final c in added.toList()..sort()) lines.add('    + $c');
    for (final c in removed.toList()..sort()) lines.add('    - $c');
  }
  return lines;
}
