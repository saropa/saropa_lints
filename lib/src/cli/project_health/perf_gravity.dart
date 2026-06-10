/// Per-feature performance "gravity" for the Project Health dashboard.
///
/// Scans a parsed unit for compound performance patterns (see the shared
/// `compound_performance_patterns.dart` table — the same facts the lint rules
/// report), sums their weights, and rolls them up per feature into a 0–100
/// gravity score.
///
/// ## Corrected scoring (the reason this is not a port of the original tool)
///
/// The design this is adapted from divided total weight by file count, so a
/// feature's score DROPPED when harmless files were added — a 1-file feature
/// with one catastrophic pattern outscored the same pattern sitting in a
/// 5-file feature. Gravity here is a saturating function of total weight ALONE
/// ([gravityScore]); adding files with no patterns leaves the score unchanged.
/// File count is reported for context but never divides the score.
library;

import 'dart:math' as math;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../rules/core/compound_performance_patterns.dart';

/// Total compound-pattern weight and count found in a single file.
class PerfFileScan {
  const PerfFileScan({required this.weight, required this.patternCount});

  /// Sum of [CompoundPerfPattern.weight] for every compound pattern in the file.
  final int weight;

  /// How many compound patterns were found (for display alongside the score).
  final int patternCount;

  static const PerfFileScan empty = PerfFileScan(weight: 0, patternCount: 0);
}

/// Scans one parsed [unit] for compound performance patterns.
PerfFileScan scanPerfGravity(CompilationUnit unit) {
  final _PerfVisitor visitor = _PerfVisitor();
  unit.visitChildren(visitor);
  return PerfFileScan(
    weight: visitor.weight,
    patternCount: visitor.patternCount,
  );
}

/// Visits widget constructions (resolved as InstanceCreationExpression, or
/// unresolved as a target-less MethodInvocation) and matches them against the
/// shared compound-pattern table.
class _PerfVisitor extends RecursiveAstVisitor<void> {
  int weight = 0;
  int patternCount = 0;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? name = widgetConstructionName(node);
    if (name != null) _match(node, name);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // A widget constructor in an unresolved tree parses as `Foo(...)` with no
    // target; a genuine `obj.method()` has a target and is not a widget.
    if (node.target == null) {
      _match(node, node.methodName.name);
    }
    super.visitMethodInvocation(node);
  }

  /// Attributes the heaviest applicable pattern (the table is ordered worst-first
  /// and we stop at the first match) so a widget under two costly parents counts
  /// once, at its most severe weight.
  void _match(AstNode node, String widgetName) {
    for (final CompoundPerfPattern pattern in kCompoundPerfPatterns) {
      if (pattern.widget != widgetName) continue;
      if (enclosingWidgetOfType(node, pattern.parents) != null) {
        weight += pattern.weight;
        patternCount++;
        return;
      }
    }
  }
}

/// Derives the feature a file belongs to from its project-relative posix path.
///
/// Prefers the conventional `lib/features/<feature>/…` (also `modules`,
/// `feature`); otherwise falls back to the top-level directory under `lib/`, so
/// every file maps to some feature bucket even in projects without a features
/// folder. Files outside `lib/` bucket under their first path segment.
String featureOf(String relPosixPath) {
  final List<String> parts = relPosixPath.split('/');

  for (int i = 0; i + 1 < parts.length; i++) {
    if (parts[i] == 'lib' &&
        (parts[i + 1] == 'features' ||
            parts[i + 1] == 'modules' ||
            parts[i + 1] == 'feature')) {
      // The folder directly under the features root is the feature name.
      return i + 2 < parts.length ? parts[i + 2] : parts[i + 1];
    }
  }

  final int libIndex = parts.indexOf('lib');
  if (libIndex >= 0 && libIndex + 1 < parts.length) {
    // No features root: treat each top-level lib/<dir> as a feature bucket.
    return parts[libIndex + 1];
  }

  return parts.isNotEmpty ? parts.first : '(root)';
}

/// Maps a total compound-pattern weight to a 0–100 gravity score.
///
/// Saturating and monotonic in [totalWeight], and INDEPENDENT of file count:
/// adding pattern-free files never lowers it (the fix for the file-count
/// dilution flaw). The decay constant is tuned so a single worst-case pattern
/// (`BackdropFilter` in a scrollable, weight 100) reads HIGH (~63), two read
/// CRITICAL (~86), while a lone medium pattern (weight 50) reads MEDIUM (~39).
int gravityScore(int totalWeight) {
  if (totalWeight <= 0) return 0;
  const double decay = 100;
  final double score = 100 * (1 - math.exp(-totalWeight / decay));
  return score.round().clamp(0, 100);
}

/// Gravity band thresholds, matching the dashboard's color coding.
enum GravityBand { low, medium, high, critical }

/// Bands a [gravityScore] result: low ≤20, medium ≤45, high ≤70, else critical.
GravityBand gravityBand(int score) {
  if (score <= 20) return GravityBand.low;
  if (score <= 45) return GravityBand.medium;
  if (score <= 70) return GravityBand.high;
  return GravityBand.critical;
}

/// One feature's rolled-up performance gravity.
class FeatureGravity {
  const FeatureGravity({
    required this.feature,
    required this.fileCount,
    required this.patternCount,
    required this.totalWeight,
  });

  /// Feature name (see [featureOf]).
  final String feature;

  /// Dart files in the feature — context only; it never divides the score.
  final int fileCount;

  /// Total compound patterns detected across the feature's files.
  final int patternCount;

  /// Summed pattern weight driving [score].
  final int totalWeight;

  /// 0–100 gravity, independent of [fileCount].
  int get score => gravityScore(totalWeight);

  GravityBand get band => gravityBand(score);

  Map<String, Object?> toJson() => {
    'feature': feature,
    'fileCount': fileCount,
    'patternCount': patternCount,
    'gravityScore': score,
    'level': band.name,
  };
}

/// Accumulates per-feature gravity as files stream past, holding only O(features)
/// state. A file with no patterns still increments its feature's [fileCount] but
/// contributes zero weight, so empty files can never raise OR lower the score.
class PerfGravityAggregator {
  final Map<String, _FeatureAccumulator> _byFeature = {};

  /// Folds one file's scan into its feature bucket.
  void add(String relPosixPath, PerfFileScan scan) {
    final String feature = featureOf(relPosixPath);
    final _FeatureAccumulator acc = _byFeature.putIfAbsent(
      feature,
      () => _FeatureAccumulator(),
    );
    acc.fileCount++;
    acc.totalWeight += scan.weight;
    acc.patternCount += scan.patternCount;
  }

  /// Whether any feature carried at least one compound pattern.
  bool get hasFindings => _byFeature.values.any((a) => a.patternCount > 0);

  /// Features that carry at least one compound pattern, gravity descending.
  /// Pattern-free features are omitted — the dashboard lists risk, not every folder.
  List<FeatureGravity> features() {
    final List<FeatureGravity> list = [
      for (final entry in _byFeature.entries)
        if (entry.value.patternCount > 0)
          FeatureGravity(
            feature: entry.key,
            fileCount: entry.value.fileCount,
            patternCount: entry.value.patternCount,
            totalWeight: entry.value.totalWeight,
          ),
    ];
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }
}

class _FeatureAccumulator {
  int fileCount = 0;
  int patternCount = 0;
  int totalWeight = 0;
}
