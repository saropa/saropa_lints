/// Tests that complexity carries the worst functions (pinpointing) and that the
/// AI-fix prompts name them with lines + scores.
import 'package:saropa_lints/src/cli/project_health/ai_fix_handoff.dart';
import 'package:saropa_lints/src/cli/project_health/complexity_scanner.dart';
import 'package:saropa_lints/src/cli/project_health/health_aggregator.dart';
import 'package:saropa_lints/src/cli/project_health/health_model.dart';
import 'package:saropa_lints/src/cli/project_health/hotspot_ranking.dart';
import 'package:saropa_lints/src/cli/project_health/metrics_model.dart';
import 'package:test/test.dart';

void main() {
  test('FileComplexity carries the worst functions by cognitive', () {
    const code = '''
void simple() => 1;
void complexOne() {
  if (a) { if (b) { if (c) {} } }
}
''';
    final fns = scanComplexity(code);
    final fc = FileComplexity.from(fns, const []);
    expect(fc.topFunctions, isNotEmpty);
    expect(fc.topFunctions.first.name, 'complexOne'); // highest cognitive first
    expect(fc.topFunctions.first.lineStart, greaterThan(0));
  });

  test('fix prompts name the offending function with line and score', () {
    final agg = HealthAggregator(topN: 5)
      ..add(
        FileHealth(
          path: 'big.dart',
          bytes: 50000,
          loc: 5000,
          codeLoc: 4000,
          commentLoc: 500,
          blankLoc: 500,
          maintainability: 2,
          complexity: const FileComplexity(
            functionCount: 1,
            maxCyclomatic: 80,
            maxCognitive: 165,
            maxVariableCount: 18,
            maxBooleanTerms: 6,
            maxNesting: 7,
            worstLcom: 0,
            topFunctions: [
              FunctionMetric(
                name: 'monster',
                lineStart: 120,
                lineEnd: 400,
                cyclomatic: 80,
                cognitive: 165,
                variableCount: 18,
                parameterCount: 4,
                maxBooleanTerms: 6,
                nesting: 7,
                exitPoints: 9,
              ),
            ],
          ),
        ),
      );
    final prompts = buildFixPrompts(
      rankHotspots(agg),
      projectPath: '.',
      generatedAt: DateTime.utc(2026),
    );
    expect(prompts, contains('# AI Fix Prompts'));
    expect(prompts, contains('big.dart'));
    expect(prompts, contains('monster'));
    expect(prompts, contains('line 120'));
    expect(prompts, contains('cognitive 165'));
    expect(prompts, contains('do NOT comment code out'));
  });
}
