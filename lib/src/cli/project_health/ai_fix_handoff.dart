/// Builds copy-paste-ready AI agent prompts, one per hot spot. Each prompt is
/// self-contained — it names the exact file, the offending functions (with
/// lines and scores), dead symbols, coverage, and churn — so an agent can act
/// without re-deriving the analysis. This is the "turn data into action" output.
library;

import 'hotspot_ranking.dart';

/// Builds a Markdown document of agent task prompts for the top [limit] hot
/// spots (multi-axis only). Each prompt sits in a fenced block ready to paste.
String buildFixPrompts(
  List<Hotspot> spots, {
  required String projectPath,
  required DateTime generatedAt,
  int limit = 25,
}) {
  final buffer = StringBuffer()
    ..writeln('# AI Fix Prompts — Project Health')
    ..writeln()
    ..writeln('- Project: `$projectPath`')
    ..writeln('- Generated: ${generatedAt.toUtc().toIso8601String()}')
    ..writeln(
      '- Each block is a self-contained task. Fix one hot spot per block.',
    )
    ..writeln();

  final shown = spots.where((s) => s.fire > 0).take(limit).toList();
  if (shown.isEmpty) {
    buffer.writeln('_No multi-axis hot spots found._');
    return buffer.toString();
  }
  for (var i = 0; i < shown.length; i++) {
    buffer
      ..writeln(
        '## Task ${i + 1} — ${shown[i].file.path} '
        '${fireEmoji(shown[i].fire)}',
      )
      ..writeln()
      ..writeln('```')
      ..write(_promptBody(shown[i]))
      ..writeln('```')
      ..writeln();
  }
  return buffer.toString();
}

String _promptBody(Hotspot spot) {
  final f = spot.file;
  final lines = StringBuffer()
    ..writeln(
      'Improve the code-health hot spot in `${f.path}` '
      '(${f.loc} LOC, ${f.codeLoc} code).',
    )
    ..writeln('Targets:');
  for (final target in _targets(spot)) {
    lines.writeln('- $target');
  }
  lines
    ..writeln(
      'Constraints: preserve behavior exactly; verify with `dart test` '
      'and `dart analyze`; do NOT comment code out (delete or refactor).',
    )
    ..writeln(
      'Confidence: size/complexity/coverage are facts; dead-weight is '
      'heuristic — verify a flagged symbol/file is not an entry point, '
      'generated, or used via reflection before removing it.',
    );
  return lines.toString();
}

List<String> _targets(Hotspot spot) {
  final f = spot.file;
  final targets = <String>[];
  final c = f.complexity;
  if (c != null && c.topFunctions.isNotEmpty) {
    final fns = c.topFunctions
        .map(
          (fn) =>
              '${fn.name} (line ${fn.lineStart}, cognitive '
              '${fn.cognitive}, nesting ${fn.nesting}, ${fn.variableCount} locals)',
        )
        .join('; ');
    targets.add('Reduce complexity in: $fns.');
  }
  if (spot.reasons.contains('large')) {
    targets.add('Split the file (${f.loc} lines) into cohesive units.');
  }
  if (f.coveragePct != null && spot.reasons.contains('uncovered')) {
    targets.add(
      'Add tests: ${(f.coveragePct! * 100).toStringAsFixed(0)}% line coverage.',
    );
  }
  if (spot.reasons.contains('dead')) {
    targets.add(
      f.isUnusedFile
          ? 'No file imports this — confirm, then remove it.'
          : 'Remove ${f.deadSymbols} unreferenced symbol(s).',
    );
  }
  if (spot.reasons.contains('churning') && f.churn != null) {
    targets.add(
      'Stabilize: ${f.churn} commits — high churn with low coverage is top risk.',
    );
  }
  return targets;
}
