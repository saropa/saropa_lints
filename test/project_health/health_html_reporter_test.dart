/// Tests that the HTML report is well-formed and embeds the data + chart hosts.
import 'package:saropa_lints/src/cli/project_health/health_aggregator.dart';
import 'package:saropa_lints/src/cli/project_health/health_html_reporter.dart';
import 'package:saropa_lints/src/cli/project_health/health_model.dart';
import 'package:saropa_lints/src/cli/project_health/hotspot_ranking.dart';
import 'package:saropa_lints/src/cli/project_health/metrics_model.dart';
import 'package:test/test.dart';

void main() {
  test('emits a complete HTML document with data and chart containers', () {
    final agg = HealthAggregator(topN: 5)
      ..add(
        const FileHealth(
          path: 'big.dart',
          bytes: 50000,
          loc: 5000,
          codeLoc: 4000,
          commentLoc: 500,
          blankLoc: 500,
          complexity: FileComplexity(
            functionCount: 10,
            maxCyclomatic: 80,
            maxCognitive: 120,
            maxVariableCount: 20,
            maxBooleanTerms: 6,
            maxNesting: 7,
            worstLcom: 0.8,
          ),
          maintainability: 4,
          churn: 30,
        ),
      );
    final html = buildHealthHtml(
      agg,
      rankHotspots(agg),
      projectPath: '.',
      generatedAt: DateTime.utc(2026),
    );

    expect(html, contains('<!DOCTYPE html>'));
    expect(html, contains('id="treemap"'));
    expect(html, contains('id="scatter"'));
    expect(html, contains('const DATA ='));
    expect(html, contains('echarts'));
    expect(html, contains('big.dart'));
  });

  test('emits the rebranded banner, KPI strip, and treemap legend', () {
    // Pins the structural surfaces of the beautify pass — if a future template
    // change drops the sticky banner, the KPI strip, or the gradient legend,
    // this test catches it before the dashboard regresses visually.
    final agg = HealthAggregator(topN: 5)
      ..add(
        const FileHealth(
          path: 'a.dart',
          bytes: 10,
          loc: 1,
          codeLoc: 1,
          commentLoc: 0,
          blankLoc: 0,
        ),
      );
    final html = buildHealthHtml(
      agg,
      rankHotspots(agg),
      projectPath: '.',
      generatedAt: DateTime.utc(2026),
    );

    expect(html, contains('Saropa Project Map'));
    expect(html, contains('class="banner"'));
    expect(html, contains('id="kpis"'));
    expect(html, contains('id="scanChip"'));
    expect(html, contains('class="legend-bar"'));
    expect(html, contains('prefers-reduced-motion'));
  });
}
