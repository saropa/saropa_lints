/// Natural-language exec summary + "what-if" cleanup simulator. Both turn the
/// raw aggregates into a sentence a human (or an AI) can act on immediately.
library;

import 'health_aggregator.dart';

/// A one-paragraph plain-language health summary. Degrades gracefully when a
/// section did not run (coverage/dead-weight optional).
String buildExecSummary(HealthAggregator agg, {String? topHotspot}) {
  final parts = <String>[
    'This project is ${_n(agg.totalLoc)} lines across ${_n(agg.fileCount)} files '
        '(${_bytes(agg.totalBytes)} on disk; ${_n(agg.totalCodeLoc)} code, '
        '${_n(agg.totalCommentLoc)} comment).',
  ];
  if (agg.maxCognitiveSeen > 0) {
    parts.add(
      'Worst function cognitive complexity is ${agg.maxCognitiveSeen}.',
    );
  }
  final cov = agg.averageCoverage;
  if (cov != null) {
    parts.add('Average line coverage is ${(cov * 100).toStringAsFixed(0)}%.');
  }
  final doc = agg.averageDocCoverage;
  if (doc != null) {
    parts.add('Public API is ${(doc * 100).toStringAsFixed(0)}% documented.');
  }
  if (agg.deadFileCount > 0) {
    parts.add(
      '${agg.deadFileCount} unused file(s) (${_pct(agg.deadLocTotal, agg.totalLoc)} '
      'of lines) look like dead weight.',
    );
  }
  if (topHotspot != null) {
    parts.add('Top refactoring priority: $topHotspot.');
  }
  return parts.join(' ');
}

/// Quantifies the payoff of removing the detected dead files. Returns null when
/// the dead-weight section did not run or found nothing.
String? buildWhatIf(HealthAggregator agg) {
  if (agg.deadFileCount == 0) return null;
  return 'Removing the ${agg.deadFileCount} unused file(s) would delete '
      '${_n(agg.deadLocTotal)} lines (${_pct(agg.deadLocTotal, agg.totalLoc)} of the '
      'codebase) and ${_bytes(agg.deadBytesTotal)} — verify each is truly unused first.';
}

String _n(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

String _pct(int part, int whole) =>
    whole == 0 ? '0%' : '${(part / whole * 100).toStringAsFixed(1)}%';

String _bytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
}
