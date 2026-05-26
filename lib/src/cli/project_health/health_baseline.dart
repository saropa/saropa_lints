/// Project-health baseline: a small snapshot of exact, unambiguous regression
/// signals. Compared run-to-run so the dashboard becomes a workflow (and a CI
/// gate) rather than a one-shot number — answers "is it getting worse?".
library;

import 'health_aggregator.dart';

/// A captured snapshot. Only exact aggregates (not top-N-bounded) live here, so
/// comparisons are precise.
class HealthBaseline {
  const HealthBaseline({
    required this.fileCount,
    required this.totalLoc,
    required this.maxCognitive,
    required this.deadFiles,
    required this.deadSymbols,
    required this.averageCoverage,
  });

  final int fileCount;
  final int totalLoc;
  final int maxCognitive;
  final int deadFiles;
  final int deadSymbols;
  final double? averageCoverage;

  factory HealthBaseline.from(HealthAggregator agg) => HealthBaseline(
    fileCount: agg.fileCount,
    totalLoc: agg.totalLoc,
    maxCognitive: agg.maxCognitiveSeen,
    deadFiles: agg.deadFileCount,
    deadSymbols: agg.deadSymbolTotal,
    averageCoverage: agg.averageCoverage,
  );

  Map<String, Object?> toJson() => {
    'fileCount': fileCount,
    'totalLoc': totalLoc,
    'maxCognitive': maxCognitive,
    'deadFiles': deadFiles,
    'deadSymbols': deadSymbols,
    'averageCoverage': averageCoverage,
  };

  factory HealthBaseline.fromJson(Map<String, Object?> json) => HealthBaseline(
    fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
    totalLoc: (json['totalLoc'] as num?)?.toInt() ?? 0,
    maxCognitive: (json['maxCognitive'] as num?)?.toInt() ?? 0,
    deadFiles: (json['deadFiles'] as num?)?.toInt() ?? 0,
    deadSymbols: (json['deadSymbols'] as num?)?.toInt() ?? 0,
    averageCoverage: (json['averageCoverage'] as num?)?.toDouble(),
  );
}

/// The result of comparing a new scan against a baseline.
class BaselineComparison {
  const BaselineComparison(this.regressions, this.improvements);

  /// Human-readable "got worse" lines (each fails a CI gate).
  final List<String> regressions;

  /// Human-readable "got better" lines.
  final List<String> improvements;

  bool get hasRegression => regressions.isNotEmpty;
}

/// Compares [now] against [base]. "Up" is worse for complexity/dead-code; "down"
/// is worse for coverage. LOC/file count are informational, not gated.
BaselineComparison compareBaseline(HealthBaseline base, HealthBaseline now) {
  final regressions = <String>[];
  final improvements = <String>[];

  void higherIsWorse(String label, int was, int isNow) {
    if (isNow > was) {
      regressions.add('$label: $was → $isNow (+${isNow - was})');
    } else if (isNow < was) {
      improvements.add('$label: $was → $isNow (${isNow - was})');
    }
  }

  higherIsWorse(
    'max cognitive complexity',
    base.maxCognitive,
    now.maxCognitive,
  );
  higherIsWorse('dead files', base.deadFiles, now.deadFiles);
  higherIsWorse('dead symbols', base.deadSymbols, now.deadSymbols);

  final wasCov = base.averageCoverage;
  final nowCov = now.averageCoverage;
  if (wasCov != null && nowCov != null) {
    final wasPct = (wasCov * 100).toStringAsFixed(1);
    final nowPct = (nowCov * 100).toStringAsFixed(1);
    // Small epsilon avoids flagging float noise as a coverage regression.
    if (nowCov < wasCov - 0.0001) {
      regressions.add('average coverage: $wasPct% → $nowPct%');
    } else if (nowCov > wasCov + 0.0001) {
      improvements.add('average coverage: $wasPct% → $nowPct%');
    }
  }

  return BaselineComparison(regressions, improvements);
}
