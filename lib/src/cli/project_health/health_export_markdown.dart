/// Markdown "AI-fix worklist" export: a prioritized, checkbox list of hot spots
/// with the metrics that justify each and concrete suggested actions.
///
/// Designed to be handed to an AI agent as a finite, ordered queue ("fix these
/// in order") — bounded to the top [limit] so an agent never gets 50k items.
library;

import 'hotspot_ranking.dart';

/// Builds the worklist markdown from ranked [spots].
String buildHealthMarkdown(
  List<Hotspot> spots, {
  required String projectPath,
  required DateTime generatedAt,
  int limit = 25,
}) {
  final buffer = StringBuffer()
    ..writeln('# Project Health — Hot Spots')
    ..writeln()
    ..writeln('- Project: `$projectPath`')
    ..writeln('- Generated: ${generatedAt.toUtc().toIso8601String()}')
    ..writeln(
      '- Confidence: facts (size, complexity, maintainability) — no '
      'deletions implied',
    )
    ..writeln();

  final shown = spots.take(limit).where((s) => s.fire > 0).toList();
  if (shown.isEmpty) {
    buffer.writeln('_No multi-axis hot spots found._');
    return buffer.toString();
  }

  // Honesty caveat: dead-weight is a heuristic (dynamic refs, entry points,
  // generated code can look unused), so flag it explicitly when present.
  if (shown.any((s) => s.reasons.contains('dead'))) {
    buffer
      ..writeln(
        '> Dead-weight is heuristic — verify each flagged item is not '
        'an entry point, generated, or used via reflection before deleting.',
      )
      ..writeln();
  }

  for (final spot in shown) {
    buffer
      ..writeln('### ${fireEmoji(spot.fire)} ${spot.file.path}')
      ..writeln()
      ..writeln('${_metricsLine(spot)}')
      ..writeln();
    for (final action in _actions(spot)) {
      buffer.writeln('- [ ] $action');
    }
    buffer.writeln();
  }
  return buffer.toString();
}

String _metricsLine(Hotspot spot) {
  final f = spot.file;
  final parts = <String>['${f.loc} LOC', '${f.codeLoc} code'];
  final c = f.complexity;
  if (c != null) parts.add('cognitive ${c.maxCognitive}');
  if (f.maintainability != null) {
    parts.add('maintainability ${f.maintainability!.toStringAsFixed(0)}/100');
  }
  return parts.join(' · ');
}

List<String> _actions(Hotspot spot) {
  final actions = <String>[];
  final c = spot.file.complexity;
  if (spot.reasons.contains('large')) {
    actions.add(
      'Split: ${spot.file.loc} lines — extract cohesive groups into separate files.',
    );
  }
  if (spot.reasons.contains('complex') && c != null) {
    final worst = c.topFunctions
        .map(
          (f) => '`${f.name}` (line ${f.lineStart}, cognitive ${f.cognitive})',
        )
        .join('; ');
    actions.add(
      'Reduce complexity in ${worst.isEmpty ? 'the worst functions' : worst} '
      '— simplify or decompose.',
    );
  }
  if (spot.reasons.contains('low-maintainability')) {
    actions.add(
      'Refactor for maintainability: low Maintainability Index — reduce size '
      'and complexity, raise comment coverage.',
    );
  }
  if (spot.reasons.contains('dead')) {
    final f = spot.file;
    final what = f.isUnusedFile
        ? 'No file imports this — verify it is not an entry point/generated, then remove.'
        : '${f.deadSymbols} unreferenced symbol(s) — verify (not reflection/generated), then remove.';
    actions.add('Remove dead weight: $what');
  }
  if (spot.reasons.contains('churning')) {
    actions.add(
      'High churn (${spot.file.churn} commits): stabilize the interface and add '
      'tests — frequently-changed code with low coverage is the top risk.',
    );
  }
  if (spot.reasons.contains('uncovered')) {
    final pct = ((spot.file.coveragePct ?? 0) * 100).toStringAsFixed(0);
    actions.add('Add tests: $pct% line coverage.');
  }
  return actions;
}
