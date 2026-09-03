// Regenerates lib/src/config/rule_pack_migration_codes.dart from the HAVE/
// ENHANCED rows in doc/guides/migration_guides/*.md:
//   dart run tool/generate_migration_pack_codes.dart
//   dart run tool/generate_migration_pack_codes.dart --check
// Exceptions carried forward unchanged — see migration_pack_guide_sync.dart.
library;

import 'dart:io';

import 'migration_pack_guide_sync.dart';

const _generatedHeader =
    '// GENERATED FILE — DO NOT EDIT BY HAND.\n//\n'
    '// Produced by tool/generate_migration_pack_codes.dart from the HAVE/\n'
    '// ENHANCED rows in doc/guides/migration_guides/*.md. Re-run after edits:\n'
    '//   dart run tool/generate_migration_pack_codes.dart\n//\n'
    '// Exceptions: see tool/migration_pack_guide_sync.dart.\n'
    '// Spread into [kRulePackRuleCodes] in rule_packs.dart.\n'
    '// ignore_for_file: always_specify_types\n';

void main(List<String> args) {
  final checkOnly = args.contains('--check');
  final repoRoot = findRepoRoot();
  final targetFile = File(
    '$repoRoot/lib/src/config/rule_pack_migration_codes.dart',
  );
  final tiersContent = File('$repoRoot/lib/src/tiers.dart').readAsStringSync();
  final guideDir = Directory('$repoRoot/doc/guides/migration_guides');
  // Strip comment lines so commented-out rule names don't false-pass.
  final knownRuleCodes = activeQuotedIdentifiers(tiersContent);
  final oldContent = targetFile.readAsStringSync();

  final entries = _buildPackEntries(
    guideDir: guideDir,
    knownRuleCodes: knownRuleCodes,
    oldContent: oldContent,
  );
  if (entries == null) return;

  final generated = _assembleSource(entries, oldContent);
  final formatted = _formatSource(generated, repoRoot);
  if (formatted == null) return;
  // Per-pack code additions/removals vs the current file.
  final diff = diffPackEntries(oldContent, entries);

  if (checkOnly) {
    _reportCheckResult(targetFile, oldContent, formatted, diff);
    return;
  }
  targetFile.writeAsStringSync(formatted);
  stdout.writeln('Regenerated ${targetFile.path}: ${entries.length} packs.');
  if (diff.isNotEmpty) {
    stdout.writeln('Changes:');
    for (final l in diff) stdout.writeln(l);
  } else {
    stdout.writeln('No code changes (formatting/comments only).');
  }
}

/// Reports --check result: up-to-date or drifted with per-code diff.
void _reportCheckResult(
  File target,
  String oldContent,
  String formatted,
  List<String> diff,
) {
  if (oldContent == formatted) {
    stdout.writeln('OK: ${target.path} is up to date.');
    return;
  }
  stderr.writeln('DRIFT: ${target.path} is out of date.');
  if (diff.isNotEmpty) {
    stderr.writeln('Drifted codes:');
    for (final l in diff) stderr.writeln(l);
  }
  stderr.writeln('Re-run: dart run tool/generate_migration_pack_codes.dart');
  exitCode = 1;
}

/// Derives one pack entry per migration pack from the guides. Returns
/// null and prints errors if any pack has unknown rule codes.
List<({String id, Set<String> codes, String comment})>? _buildPackEntries({
  required Directory guideDir,
  required Set<String> knownRuleCodes,
  required String oldContent,
}) {
  final entries = <({String id, Set<String> codes, String comment})>[];
  final errors = <String>[];
  for (final packId in kMigrationPackGuideFiles.keys) {
    final guideFile = File(
      '${guideDir.path}/${kMigrationPackGuideFiles[packId]}',
    );
    final guideContent = guideFile.readAsStringSync();
    late final Set<String> codes;
    late final String comment;
    if (kMigrationPacksWithoutGuideTable.contains(packId)) {
      // Carry forward from previously-generated file, then validate.
      codes = extractPackCodes(oldContent, packId);
      final unknown = codes.difference(knownRuleCodes);
      if (unknown.isNotEmpty) {
        errors.add('$packId (carried forward): ${unknown.join(', ')}');
        continue;
      }
      comment =
          '  // flutter_skill_lints — ${codes.length} codes carried '
          'forward (no per-rule guide table; see plans/GAP_ANALYSIS.md).';
    } else {
      // Standard packs — fully re-derive from the guide table.
      final tag = kMigrationPacksUsingEnhancedTag.contains(packId)
          ? 'ENHANCED'
          : 'HAVE';
      codes = codesFromGuideTable(guideContent, tag);
      if (codes.isEmpty) {
        errors.add('$packId: no $tag rows in guide');
        continue;
      }
      final unknown = codes.difference(knownRuleCodes);
      if (unknown.isNotEmpty) {
        errors.add('$packId: unknown rules: ${unknown.join(', ')}');
        continue;
      }
      comment = buildPackComment(packId, tag, codes, guideContent);
    }
    entries.add((id: packId, codes: codes, comment: comment));
  }
  if (errors.isNotEmpty) {
    stderr.writeln('Migration pack generation failed:\n');
    for (final e in errors) stderr.writeln('  - $e');
    exitCode = 1;
    return null;
  }
  // Largest packs first so the file stays scannable.
  entries.sort((a, b) {
    final byCoverage = b.codes.length.compareTo(a.codes.length);
    return byCoverage != 0 ? byCoverage : a.id.compareTo(b.id);
  });
  return entries;
}

/// Builds the complete Dart source as a string, without writing it.
String _assembleSource(
  List<({String id, Set<String> codes, String comment})> entries,
  String oldContent,
) {
  final markers = extractBlock(
    oldContent,
    'const Map<String, Set<String>> kRulePackMigrationPubspecMarkers = {',
  );
  final buf = StringBuffer()
    ..writeln(_generatedHeader)
    ..writeln(
      '/// Migration pack rule codes, keyed by `migrate_<package>` pack id.\n'
      '/// Each set contains saropa rule codes that cover functionality from\n'
      '/// the named alternative lint package, replacing its coverage.',
    )
    ..writeln('const Map<String, Set<String>> kRulePackMigrationCodes = {');
  for (final e in entries) {
    buf
      ..writeln(e.comment)
      ..writeln("  '${e.id}': {");
    for (final code in e.codes.toList()..sort()) {
      buf.writeln("    '$code',");
    }
    buf
      ..writeln('  },')
      ..writeln();
  }
  buf
    ..writeln('};')
    ..writeln()
    ..writeln(
      '/// Pubspec dependency markers for migration packs. Each migration\n'
      '/// pack fires when the source package is still present in\n'
      '/// pubspec.yaml (any version).',
    )
    ..writeln(markers);
  return buf.toString();
}

/// Formats [source] via a temp file. Returns formatted string or null.
String? _formatSource(String source, String repoRoot) {
  final tmp = File('$repoRoot/.dart_tool/migration_gen_tmp.dart');
  try {
    // Ensure .dart_tool/ exists (may be absent in fresh checkouts).
    tmp.parent.createSync(recursive: true);
    tmp.writeAsStringSync(source);
    final fmt = Process.runSync('dart', [
      'format',
      tmp.path,
    ], workingDirectory: repoRoot);
    if (fmt.exitCode != 0) {
      stderr.writeln('dart format failed:\n${fmt.stderr}');
      exitCode = 1;
      return null;
    }
    return tmp.readAsStringSync();
  } finally {
    if (tmp.existsSync()) tmp.deleteSync();
  }
}
