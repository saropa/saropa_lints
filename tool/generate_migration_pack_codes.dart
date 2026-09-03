// Regenerates lib/src/config/rule_pack_migration_codes.dart from the HAVE/
// ENHANCED rows in doc/guides/migration_guides/*.md, so a guide edit (new
// HAVE row, renamed saropa target, corrected mapping) flows into the pack
// file without a hand-sync step. Run after editing any migration guide:
//
//   dart run tool/generate_migration_pack_codes.dart
//
// Two things can't be derived from guide text and are carried forward
// unchanged from the current file:
//   - kRulePackMigrationPubspecMarkers (the pub.dev package name(s) that
//     trigger each pack — not guide content, doesn't change with rules).
//   - migrate_flutter_skill_lints' code set (its guide has no per-rule
//     table; see kMigrationPacksWithoutGuideTable in migration_pack_guide_sync.dart).
//
// Every other pack's code set is fully re-derived from its guide and
// validated against lib/src/tiers.dart, so a typo'd or renamed saropa rule
// in a guide fails the generation run instead of shipping silently.
library;

import 'dart:io';

import 'migration_pack_guide_sync.dart';

const _generatedHeader = '''
// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Produced by tool/generate_migration_pack_codes.dart from the HAVE/
// ENHANCED rows in doc/guides/migration_guides/*.md. To change a pack's
// rule set, edit the guide's mapping table and re-run the generator:
//
//   dart run tool/generate_migration_pack_codes.dart
//
// The two exceptions below are documented in tool/migration_pack_guide_sync.dart.
//
// Spread into [kRulePackRuleCodes] in rule_packs.dart so the canonical registry
// includes migration packs alongside generated and SDK packs.
// ignore_for_file: always_specify_types
''';

void main() {
  final repoRoot = _findRepoRoot();
  final targetFile = File(
    '$repoRoot/lib/src/config/rule_pack_migration_codes.dart',
  );
  final tiersFile = File('$repoRoot/lib/src/tiers.dart');
  final guideDir = Directory('$repoRoot/doc/guides/migration_guides');

  final knownRuleCodes = _allQuotedIdentifiers(tiersFile.readAsStringSync());
  final oldContent = targetFile.readAsStringSync();
  final preservedMarkersBlock = _extractBlock(
    oldContent,
    'const Map<String, Set<String>> kRulePackMigrationPubspecMarkers = {',
  );
  final preservedSkillLintsCodes = _extractPackCodes(
    oldContent,
    'migrate_flutter_skill_lints',
  );

  final entries = <_PackEntry>[];
  final errors = <String>[];

  for (final packId in kMigrationPackGuideFiles.keys) {
    final guideFile = File(
      '${guideDir.path}/${kMigrationPackGuideFiles[packId]}',
    );
    final guideContent = guideFile.readAsStringSync();

    late final Set<String> codes;
    late final String comment;

    if (kMigrationPacksWithoutGuideTable.contains(packId)) {
      codes = preservedSkillLintsCodes;
      comment =
          '  // flutter_skill_lints — ${codes.length} codes carried forward '
          'from the previous generation (no per-rule guide table; see '
          'plans/GAP_ANALYSIS.md). Verify manually after a guide update.';
    } else {
      final statusTag = kMigrationPacksUsingEnhancedTag.contains(packId)
          ? 'ENHANCED'
          : 'HAVE';
      codes = codesFromGuideTable(guideContent, statusTag);
      if (codes.isEmpty) {
        errors.add(
          '$packId: no $statusTag rows found in '
          '${kMigrationPackGuideFiles[packId]}',
        );
        continue;
      }

      final unknown = codes.difference(knownRuleCodes);
      if (unknown.isNotEmpty) {
        errors.add(
          '$packId: guide references unknown saropa rule(s), not found in '
          'tiers.dart: ${unknown.join(', ')}',
        );
        continue;
      }

      final coverage = parseCoverageLine(guideContent);
      final packageName = packId.replaceFirst('migrate_', '');
      comment = coverage != null
          ? '  // $packageName — ${coverage.have} $statusTag rules covering '
                '${coverage.percent}% of ${coverage.total} total'
                '${codes.length != coverage.have ? ' (${codes.length} unique saropa codes after fan-out)' : ''}.'
          : '  // $packageName — ${codes.length} $statusTag rule codes.';
    }

    entries.add(_PackEntry(packId, codes, comment));
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Migration pack generation failed:\n');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exitCode = 1;
    return;
  }

  // Largest packs first (mirrors the previous hand-authored "ship the
  // highest-coverage packs first" ordering) so the file stays scannable.
  entries.sort((a, b) {
    final byCoverage = b.codes.length.compareTo(a.codes.length);
    return byCoverage != 0 ? byCoverage : a.packId.compareTo(b.packId);
  });

  final buffer = StringBuffer()
    ..writeln(_generatedHeader)
    ..writeln(
      '/// Migration pack rule codes, keyed by `migrate_<package>` pack id.',
    )
    ..writeln('///')
    ..writeln(
      '/// Each set contains saropa rule codes that cover functionality from the named',
    )
    ..writeln(
      '/// alternative lint package. Enabling a migration pack opts the user into these',
    )
    ..writeln(
      '/// rules on top of their tier floor, replacing the source package\'s coverage.',
    )
    ..writeln('const Map<String, Set<String>> kRulePackMigrationCodes = {');

  for (final entry in entries) {
    buffer.writeln(entry.comment);
    buffer.writeln("  '${entry.packId}': {");
    for (final code in entry.codes.toList()..sort()) {
      buffer.writeln("    '$code',");
    }
    buffer.writeln('  },');
    buffer.writeln();
  }
  buffer.writeln('};');
  buffer.writeln();
  buffer.writeln(
    '/// Pubspec dependency markers for migration packs. Each migration pack fires',
  );
  buffer.writeln(
    '/// when the source package is still present in pubspec.yaml (any version).',
  );
  buffer.writeln(preservedMarkersBlock);

  targetFile.writeAsStringSync(buffer.toString());

  final format = Process.runSync('dart', [
    'format',
    targetFile.path,
  ], workingDirectory: repoRoot);
  if (format.exitCode != 0) {
    stderr.writeln('dart format failed:\n${format.stderr}');
    exitCode = 1;
    return;
  }

  stdout.writeln('Regenerated ${targetFile.path}: ${entries.length} packs.');
  for (final entry in entries) {
    stdout.writeln('  ${entry.packId}: ${entry.codes.length} codes');
  }
}

class _PackEntry {
  _PackEntry(this.packId, this.codes, this.comment);

  final String packId;
  final Set<String> codes;
  final String comment;
}

Set<String> _allQuotedIdentifiers(String content) {
  return RegExp(
    r"'([a-zA-Z0-9_]+)'",
  ).allMatches(content).map((m) => m.group(1)!).toSet();
}

/// Extracts a `const ... = { ... };` block starting at [startMarker] up to
/// and including its matching closing `};`.
String _extractBlock(String content, String startMarker) {
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

/// Extracts the quoted rule codes inside a single `'packId': { ... },` set
/// literal from the existing generated file.
Set<String> _extractPackCodes(String content, String packId) {
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

String _findRepoRoot() {
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
