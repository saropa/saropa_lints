#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Project Health CLI — size scan increment.
///
/// Walks a Dart project and reports file/folder size (bytes + LOC, split into
/// code/comment/blank), streaming per-file rows to NDJSON on disk while keeping
/// only bounded aggregates in memory. Foundation for the Saropa Project Map dashboard.
///
/// Run `dart run saropa_lints:project_health --help` for options.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/project_health/ai_fix_handoff.dart';
import 'package:saropa_lints/src/cli/project_health/asset_scanner.dart';
import 'package:saropa_lints/src/cli/project_health/coupling_metrics.dart';
import 'package:saropa_lints/src/cli/project_health/coverage_rollup.dart';
import 'package:saropa_lints/src/cli/project_health/cycle_cut.dart';
import 'package:saropa_lints/src/cli/project_health/dead_islands.dart';
import 'package:saropa_lints/src/cli/project_health/deadweight_overlay.dart';
import 'package:saropa_lints/src/cli/project_health/fix_workflow.dart';
import 'package:saropa_lints/src/cli/project_health/git_signals.dart';
import 'package:saropa_lints/src/cli/project_health/stub_density.dart';
import 'package:saropa_lints/src/cli/project_health/temporal_coupling.dart';
import 'package:saropa_lints/src/cli/project_health/health_aggregator.dart';
import 'package:saropa_lints/src/cli/project_health/health_baseline.dart';
import 'package:saropa_lints/src/cli/project_health/health_cache.dart';
import 'package:saropa_lints/src/cli/project_health/health_config.dart';
import 'package:saropa_lints/src/cli/project_health/health_export_json.dart';
import 'package:saropa_lints/src/cli/project_health/health_history.dart';
import 'package:saropa_lints/src/cli/project_health/health_export_markdown.dart';
import 'package:saropa_lints/src/cli/project_health/health_html_reporter.dart';
import 'package:saropa_lints/src/cli/project_health/health_model.dart';
import 'package:saropa_lints/src/cli/project_health/health_summary.dart';
import 'package:saropa_lints/src/cli/project_health/hotspot_ranking.dart';
import 'package:saropa_lints/src/cli/project_health/size_scanner.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final cli = _parseArgs(args);
  final outputDir =
      cli.outputDir ?? p.join(cli.path, 'reports', '.saropa_lints', 'health');
  Directory(outputDir).createSync(recursive: true);

  // Config supplies extra excludes and an allowlist that silences known
  // false positives in the heuristic sections.
  final config = loadHealthConfig(cli.path, configPath: cli.config);
  final excludes = [...cli.excludes, ...config.excludeGlobs];

  // Precompute optional overlays before the walk; each is keyed by relative path.
  // --cycles also needs the import graph, so it triggers the dead-weight pass.
  final needGraph = cli.deadweight || cli.cycles;
  final deadWeight = needGraph
      ? await loadDeadWeight(
          projectPath: cli.path,
          excludeGlobs: excludes,
          includeSymbols: true,
        )
      : null;
  // Dead-weight flags attach only under --deadweight (allowlist applied first).
  final unusedFiles = cli.deadweight && deadWeight != null
      ? config.filterDeadFiles(deadWeight.unusedFiles)
      : null;
  final deadSymbols = cli.deadweight && deadWeight != null
      ? config.filterDeadSymbols(deadWeight.deadSymbolCounts)
      : null;
  // Fan-in/out rides free whenever the import graph was built.
  final importCoupling = deadWeight == null
      ? null
      : couplingFromGraph(cli.path);
  final cycleCuts = cli.cycles && deadWeight != null
      ? cycleCutsFromGraph(deadWeight.cycles, cli.path)
      : null;
  final lcovPath = p.join(cli.path, cli.lcov);
  final coverage = cli.coverage ? loadLcovCoverage(lcovPath, cli.path) : null;
  if (cli.coverage && isCoverageStale(lcovPath, cli.path)) {
    // Surface staleness, never hide it — stale coverage is unverified, not "fine".
    stderr.writeln(
      'WARNING: $lcovPath predates the latest commit — coverage is UNVERIFIED. '
      'Re-run `flutter test --coverage`.',
    );
  }
  final git = cli.git ? loadGitSignals(cli.path) : null;

  // Warm-rescan cache (opt-in): reuse the parse for unchanged files.
  final cachePath = p.join(outputDir, 'cache.json');
  final cacheIn = cli.cache ? loadComplexityCache(cachePath) : null;
  final cacheSink = cli.cache ? <String, CacheEntry>{} : null;

  final shard = File(p.join(outputDir, 'files.ndjson')).openWrite();
  final agg = await runSizeScan(
    SizeScanOptions(
      projectPath: cli.path,
      excludeGlobs: excludes,
      topN: cli.top,
      withComplexity: cli.complexity,
      unusedFiles: unusedFiles,
      deadSymbols: deadSymbols,
      coverage: coverage,
      gitSignals: git,
      coupling: importCoupling,
      complexityCache: cacheIn,
      cacheSink: cacheSink,
      onRow: (row) => shard.writeln(jsonEncode(row.toJson())),
    ),
  );
  await shard.flush();
  await shard.close();
  if (cacheSink != null) saveComplexityCache(cachePath, cacheSink);

  final assets = cli.assets
      ? [
          for (final a in scanUnusedAssets(cli.path))
            if (!config.isAssetIgnored(a.path)) a,
        ]
      : null;
  final islands = cli.islands
      ? config.filterIslands(scanProjectDeadIslands(cli.path))
      : null;
  final coupling = cli.coupling ? loadTemporalCoupling(cli.path) : null;
  final stubs = cli.stubs ? scanStubTests(cli.path) : null;
  final history = cli.history ? await loadHealthHistory(cli.path) : null;
  final firedSpots = rankHotspots(agg).where((s) => s.fire > 0).toList();
  final topHotspot = firedSpots.isEmpty ? null : firedSpots.first.file.path;
  final execSummary = buildExecSummary(agg, topHotspot: topHotspot);
  final whatIf = buildWhatIf(agg);
  if (cli.fix && unusedFiles != null && unusedFiles.isNotEmpty) {
    final script = buildRemovalScript(unusedFiles.toList()..sort());
    final out = File(p.join(outputDir, 'remove_dead_files.sh'))
      ..writeAsStringSync(script);
    print('Dead-file removal script (review before running): ${out.path}');
  }

  final sections = <String>[
    'size',
    if (cli.complexity) 'complexity',
    if (cli.deadweight) 'deadweight',
    if (cli.coverage) 'coverage',
    if (cli.git) 'git',
    if (cli.assets) 'assets',
  ];
  if (cli.format == 'json') {
    final report = buildHealthReport(
      agg,
      projectPath: cli.path,
      generatedAt: DateTime.now(),
      sections: sections,
    );
    if (assets != null) {
      report['unusedAssets'] = [for (final a in assets) a.toJson()];
    }
    if (islands != null) report['deadIslands'] = islands;
    if (coupling != null) {
      report['temporalCoupling'] = [for (final c in coupling) c.toJson()];
    }
    if (stubs != null) report['stubTests'] = stubs;
    if (history != null) {
      report['history'] = [for (final h in history) h.toJson()];
    }
    if (cycleCuts != null) {
      report['cycleCuts'] = [for (final c in cycleCuts) c.toJson()];
    }
    report['summary'] = execSummary;
    if (whatIf != null) report['whatIf'] = whatIf;
    print(const JsonEncoder.withIndent('  ').convert(report));
  } else if (cli.format == 'markdown') {
    print(
      buildHealthMarkdown(
        rankHotspots(agg),
        projectPath: cli.path,
        generatedAt: DateTime.now(),
        limit: cli.top,
      ),
    );
  } else if (cli.format == 'prompts') {
    print(
      buildFixPrompts(
        rankHotspots(agg),
        projectPath: cli.path,
        generatedAt: DateTime.now(),
        limit: cli.top,
      ),
    );
  } else if (cli.format == 'html') {
    final html = buildHealthHtml(
      agg,
      rankHotspots(agg),
      projectPath: cli.path,
      generatedAt: DateTime.now(),
    );
    final out = File(p.join(outputDir, 'index.html'))..writeAsStringSync(html);
    print('HTML report: ${out.path}');
  } else {
    print(execSummary);
    if (whatIf != null) print('What-if: $whatIf');
    print('');
    _printText(agg, outputDir);
    if (assets != null && assets.isNotEmpty) {
      print('');
      print('Dead assets (verify before deleting):');
      for (final a in assets.take(20)) {
        print('  ${a.kind.padLeft(12)}  ${a.path}');
      }
    }
    _printMap('Dead islands (unreachable private decls)', islands);
    _printMap('Stub tests (no assertions)', stubs);
    if (coupling != null && coupling.isNotEmpty) {
      print('');
      print('Change-coupled file pairs:');
      for (final c in coupling.take(15)) {
        print(
          '  ${(c.ratio * 100).toStringAsFixed(0).padLeft(4)}%  ${c.a}  <->  ${c.b}',
        );
      }
    }
    if (history != null && history.isNotEmpty) {
      print('');
      print('Health trajectory (oldest → newest):');
      for (final h in history) {
        print(
          '  ${h.tag.padRight(12)}  ${h.loc.toString().padLeft(8)} LOC  '
          'maxCognitive ${h.maxCognitive}',
        );
      }
    }
    if (cycleCuts != null && cycleCuts.isNotEmpty) {
      print('');
      print('Import cycles — suggested cut per cycle:');
      for (final c in cycleCuts.take(15)) {
        print('  cut  ${c.from}  ✂  ${c.to}   (cycle of ${c.cycle.length})');
      }
    }
  }

  _handleBaseline(cli, agg, p.join(outputDir, 'baseline.json'));
}

/// Writes or compares the health baseline. On comparison, prints the diff and
/// sets a non-zero exit code on regression so CI can gate on it.
void _handleBaseline(_CliArgs cli, HealthAggregator agg, String defaultPath) {
  if (cli.updateBaseline) {
    final path = cli.baseline ?? defaultPath;
    File(path).writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(HealthBaseline.from(agg).toJson()),
    );
    print('Baseline written: $path');
    return;
  }
  if (cli.baseline == null) return;
  final file = File(cli.baseline!);
  if (!file.existsSync()) {
    print(
      'Baseline not found: ${cli.baseline} (run with --update-baseline first)',
    );
    return;
  }
  final base = HealthBaseline.fromJson(
    jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
  );
  final cmp = compareBaseline(base, HealthBaseline.from(agg));
  print('');
  print('Baseline comparison:');
  for (final line in cmp.improvements) {
    print('  improved   $line');
  }
  for (final line in cmp.regressions) {
    print('  REGRESSED  $line');
  }
  if (cmp.improvements.isEmpty && cmp.regressions.isEmpty) {
    print('  no change in gated metrics');
  }
  if (cmp.hasRegression) exitCode = 1; // fail CI on regression
}

void _printMap(String title, Map<String, Object?>? data) {
  if (data == null || data.isEmpty) return;
  print('');
  print('$title:');
  for (final entry in data.entries.take(20)) {
    final v = entry.value;
    final detail = v is List ? v.join(', ') : '$v';
    print('  ${entry.key}: $detail');
  }
}

typedef _CliArgs = ({
  String path,
  String format,
  String? outputDir,
  int top,
  List<String> excludes,
  bool complexity,
  bool deadweight,
  bool coverage,
  String lcov,
  bool git,
  bool assets,
  bool islands,
  bool coupling,
  bool stubs,
  bool fix,
  String? baseline,
  bool updateBaseline,
  String? config,
  bool history,
  bool cycles,
  bool cache,
});

_CliArgs _parseArgs(List<String> args) {
  var path = '.';
  var format = 'text';
  String? outputDir;
  var top = 25;
  final excludes = <String>[];
  var complexity = false;
  var deadweight = false;
  var coverage = false;
  var lcov = p.join('coverage', 'lcov.info');
  var git = false;
  var assets = false;
  var islands = false;
  var coupling = false;
  var stubs = false;
  var fix = false;
  String? baseline;
  var updateBaseline = false;
  String? config;
  var history = false;
  var cycles = false;
  var cache = false;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--path' && i + 1 < args.length) {
      path = args[++i];
    } else if (arg == '--format' && i + 1 < args.length) {
      format = args[++i];
    } else if (arg == '--output-dir' && i + 1 < args.length) {
      outputDir = args[++i];
    } else if (arg == '--top' && i + 1 < args.length) {
      top = int.tryParse(args[++i]) ?? top;
    } else if (arg == '--exclude' && i + 1 < args.length) {
      excludes.add(args[++i]);
    } else if (arg == '--complexity') {
      complexity = true;
    } else if (arg == '--deadweight') {
      deadweight = true;
    } else if (arg == '--coverage') {
      coverage = true;
    } else if (arg == '--lcov' && i + 1 < args.length) {
      coverage = true;
      lcov = args[++i];
    } else if (arg == '--git') {
      git = true;
    } else if (arg == '--assets') {
      assets = true;
    } else if (arg == '--islands') {
      islands = true;
    } else if (arg == '--coupling') {
      coupling = true;
    } else if (arg == '--stubs') {
      stubs = true;
    } else if (arg == '--fix') {
      fix = true;
    } else if (arg == '--baseline' && i + 1 < args.length) {
      baseline = args[++i];
    } else if (arg == '--update-baseline') {
      updateBaseline = true;
    } else if (arg == '--config' && i + 1 < args.length) {
      config = args[++i];
    } else if (arg == '--history') {
      history = true;
    } else if (arg == '--cycles') {
      cycles = true;
    } else if (arg == '--cache') {
      cache = true;
    }
  }
  return (
    path: path,
    format: format,
    outputDir: outputDir,
    top: top,
    excludes: excludes,
    complexity: complexity,
    deadweight: deadweight,
    coverage: coverage,
    lcov: lcov,
    git: git,
    assets: assets,
    islands: islands,
    coupling: coupling,
    stubs: stubs,
    fix: fix,
    baseline: baseline,
    updateBaseline: updateBaseline,
    config: config,
    history: history,
    cycles: cycles,
    cache: cache,
  );
}

void _printText(HealthAggregator agg, String outputDir) {
  print('Project Health — size scan');
  print('==========================');
  print('Files:    ${agg.fileCount}');
  print('Size:     ${_humanBytes(agg.totalBytes)}');
  print(
    'Lines:    ${agg.totalLoc}  '
    '(code ${agg.totalCodeLoc}, comment ${agg.totalCommentLoc}, blank ${agg.totalBlankLoc})',
  );
  _section('Largest files by lines', agg.topByLoc(), (f) => '${f.loc}');
  _section(
    'Largest files by size',
    agg.topByBytes(),
    (f) => _humanBytes(f.bytes),
  );
  // Each section prints only when its overlay ran (list is otherwise empty).
  _section(
    'Most cognitively complex',
    agg.topByCognitive(),
    (f) => '${f.complexity?.maxCognitive ?? 0}',
  );
  _section(
    'Lowest maintainability (0-100)',
    agg.worstMaintainability(),
    (f) => (f.maintainability ?? 0).toStringAsFixed(0),
  );
  // ROI ranking is most meaningful once complexity has run.
  if (agg.topByCognitive().isNotEmpty) {
    _section(
      'Refactoring priority (ROI)',
      agg.topByRoi(),
      (f) => HealthAggregator.roiOf(f).toStringAsFixed(0),
    );
  }
  _section('Largest dead files', agg.deadFiles(), (f) => '${f.loc} LOC');
  _section('Most churned', agg.topByChurn(), (f) => '${f.churn} commits');
  _section(
    'Lowest coverage',
    agg.lowestCoverage(),
    (f) => '${((f.coveragePct ?? 0) * 100).toStringAsFixed(0)}%',
  );
  print('');
  print('Per-file rows: ${p.join(outputDir, 'files.ndjson')}');
}

void _section(
  String title,
  List<FileHealth> files,
  String Function(FileHealth) value,
) {
  if (files.isEmpty) return;
  print('');
  print('$title:');
  for (final f in files.take(10)) {
    print('  ${value(f).padLeft(11)}  ${f.path}');
  }
}

String _humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

void _printUsage() {
  print('''
Project Health — size scan

Usage: dart run saropa_lints:project_health [options]

Options:
  --path <dir>         Project directory (default: current)
  --format <fmt>       Output: text, json, markdown, prompts, html (default: text)
  --output-dir <path>  NDJSON output dir (default: <path>/reports/.saropa_lints/health)
  --top <n>            Number of files in each "largest" list (default: 25)
  --exclude <glob>     Exclude matching paths (repeatable; e.g. lib/generated/**)
  --complexity         Also compute complexity + maintainability (one parse/file)
  --deadweight         Flag unused files + dead symbols (composes cross_file)
  --coverage           Read coverage/lcov.info for per-file line coverage
  --lcov <path>        Coverage file path (implies --coverage)
  --git                Per-file churn, recency, and bus-factor (git history)
  --assets             Flag pubspec assets/fonts never referenced in code
  --islands            Flag private declarations unreachable from any live root
  --coupling           Show file pairs that change together (git co-commits)
  --stubs              Flag tests that contain no assertions
  --fix                With --deadweight: write a reviewable git-rm script (never auto-runs)
  --update-baseline    Write the current health snapshot as the baseline
  --baseline <path>    Compare against a baseline; exit 1 on regression (CI gate)
  --config <path>      Config / allowlist file (default: .saropa_health.yaml)
  --history            Health trajectory across recent git tags (time-machine)
  --cycles             Import cycles + suggested cut per cycle (builds the graph)
  --cache              Reuse cached parse for unchanged files (faster rescans)
  -h, --help           Show this help
''');
}
