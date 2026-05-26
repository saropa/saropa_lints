/// Per-function and per-class metric records, plus the per-file rollup used by
/// the dashboard table and hot-spot ranking.
///
/// All of these come from PARSED (unresolved) AST so the scanner stays
/// memory-light on huge projects — no element model is retained.
library;

import 'dart:math' as math;

/// One function/method's complexity profile.
class FunctionMetric {
  const FunctionMetric({
    required this.name,
    required this.lineStart,
    required this.lineEnd,
    required this.cyclomatic,
    required this.cognitive,
    required this.variableCount,
    required this.parameterCount,
    required this.maxBooleanTerms,
    required this.nesting,
    required this.exitPoints,
  });

  final String name;
  final int lineStart;
  final int lineEnd;
  final int cyclomatic;

  /// Cognitive complexity (SonarSource-style): nesting-weighted, a better
  /// "hard to read" proxy than cyclomatic.
  final int cognitive;

  /// Local variables declared in the body ("overrun with variables" signal).
  final int variableCount;
  final int parameterCount;

  /// Most boolean operators (`&&`/`||`/`!`) in any single condition here.
  final int maxBooleanTerms;

  /// Deepest block nesting inside the function.
  final int nesting;

  /// `return` / `throw` count (multiple exits hurt readability/testability).
  final int exitPoints;

  Map<String, Object?> toJson() => {
    'name': name,
    'lineStart': lineStart,
    'lineEnd': lineEnd,
    'cyclomatic': cyclomatic,
    'cognitive': cognitive,
    'variableCount': variableCount,
    'parameterCount': parameterCount,
    'maxBooleanTerms': maxBooleanTerms,
    'nesting': nesting,
    'exitPoints': exitPoints,
  };

  factory FunctionMetric.fromJson(Map<String, Object?> j) => FunctionMetric(
    name: j['name'] as String? ?? '',
    lineStart: (j['lineStart'] as num?)?.toInt() ?? 0,
    lineEnd: (j['lineEnd'] as num?)?.toInt() ?? 0,
    cyclomatic: (j['cyclomatic'] as num?)?.toInt() ?? 0,
    cognitive: (j['cognitive'] as num?)?.toInt() ?? 0,
    variableCount: (j['variableCount'] as num?)?.toInt() ?? 0,
    parameterCount: (j['parameterCount'] as num?)?.toInt() ?? 0,
    maxBooleanTerms: (j['maxBooleanTerms'] as num?)?.toInt() ?? 0,
    nesting: (j['nesting'] as num?)?.toInt() ?? 0,
    exitPoints: (j['exitPoints'] as num?)?.toInt() ?? 0,
  );
}

/// One class's size/cohesion profile.
class ClassMetric {
  const ClassMetric({
    required this.name,
    required this.fieldCount,
    required this.methodCount,
    required this.publicMembers,
    required this.lcom,
  });

  final String name;
  final int fieldCount;
  final int methodCount;
  final int publicMembers;

  /// Lack of cohesion of methods (0..1): fraction of method pairs that share no
  /// field. High = the class likely does several unrelated jobs → split it.
  final double lcom;

  Map<String, Object?> toJson() => {
    'name': name,
    'fieldCount': fieldCount,
    'methodCount': methodCount,
    'publicMembers': publicMembers,
    'lcom': double.parse(lcom.toStringAsFixed(4)),
  };
}

/// Per-file rollup of the worst function/class signals — what the table sorts
/// on and the hot-spot ranking consumes.
class FileComplexity {
  const FileComplexity({
    required this.functionCount,
    required this.maxCyclomatic,
    required this.maxCognitive,
    required this.maxVariableCount,
    required this.maxBooleanTerms,
    required this.maxNesting,
    required this.worstLcom,
    this.topFunctions = const [],
  });

  final int functionCount;
  final int maxCyclomatic;
  final int maxCognitive;
  final int maxVariableCount;
  final int maxBooleanTerms;
  final int maxNesting;
  final double worstLcom;

  /// The few worst functions by cognitive complexity (name + line + scores),
  /// so findings can be PINPOINTED — the worklist/AI-fix prompt names exactly
  /// which function to fix, not just the file's max.
  final List<FunctionMetric> topFunctions;

  /// Builds the rollup from a file's function and class metrics. Empties yield
  /// all-zero so a metric-free file ranks as harmless rather than crashing.
  factory FileComplexity.from(
    List<FunctionMetric> functions,
    List<ClassMetric> classes,
  ) {
    var cyclo = 0;
    var cog = 0;
    var vars = 0;
    var bools = 0;
    var nest = 0;
    for (final f in functions) {
      cyclo = math.max(cyclo, f.cyclomatic);
      cog = math.max(cog, f.cognitive);
      vars = math.max(vars, f.variableCount);
      bools = math.max(bools, f.maxBooleanTerms);
      nest = math.max(nest, f.nesting);
    }
    var lcom = 0.0;
    for (final c in classes) {
      lcom = math.max(lcom, c.lcom);
    }
    final ranked = [...functions]
      ..sort((a, b) => b.cognitive.compareTo(a.cognitive));
    return FileComplexity(
      functionCount: functions.length,
      maxCyclomatic: cyclo,
      maxCognitive: cog,
      maxVariableCount: vars,
      maxBooleanTerms: bools,
      maxNesting: nest,
      worstLcom: lcom,
      topFunctions: ranked.take(3).toList(),
    );
  }

  Map<String, Object?> toJson() => {
    'functionCount': functionCount,
    'maxCyclomatic': maxCyclomatic,
    'maxCognitive': maxCognitive,
    'maxVariableCount': maxVariableCount,
    'maxBooleanTerms': maxBooleanTerms,
    'maxNesting': maxNesting,
    'worstLcom': double.parse(worstLcom.toStringAsFixed(4)),
    if (topFunctions.isNotEmpty)
      'topFunctions': [for (final f in topFunctions) f.toJson()],
  };

  factory FileComplexity.fromJson(Map<String, Object?> j) => FileComplexity(
    functionCount: (j['functionCount'] as num?)?.toInt() ?? 0,
    maxCyclomatic: (j['maxCyclomatic'] as num?)?.toInt() ?? 0,
    maxCognitive: (j['maxCognitive'] as num?)?.toInt() ?? 0,
    maxVariableCount: (j['maxVariableCount'] as num?)?.toInt() ?? 0,
    maxBooleanTerms: (j['maxBooleanTerms'] as num?)?.toInt() ?? 0,
    maxNesting: (j['maxNesting'] as num?)?.toInt() ?? 0,
    worstLcom: (j['worstLcom'] as num?)?.toDouble() ?? 0,
    topFunctions: [
      for (final f in (j['topFunctions'] as List? ?? const []))
        FunctionMetric.fromJson((f as Map).cast<String, Object?>()),
    ],
  );
}
