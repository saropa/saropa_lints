#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Long-lived resolved-scan daemon for save-triggered IDE scans.
///
/// `dart run saropa_lints scan --resolve` rebuilds the full analyzer
/// [AnalysisContextCollection] on every invocation — package-graph discovery
/// and dependency resolution for the whole project, before it can resolve
/// even one file. On a project of a few thousand files that costs on the
/// order of a minute, and unlike the syntactic-only scan it does not
/// benefit from OS/analyzer warm caching between separate process
/// invocations, so every save pays the full cost again.
///
/// This daemon builds that collection exactly once, prewarms it by
/// resolving one representative file, then answers repeated scan requests
/// over stdin/stdout by notifying the collection which files changed
/// ([AnalysisContext.changeFile] / [AnalysisContext.applyPendingFileChanges],
/// the analyzer's own public incremental-resolution API) and resolving only
/// those files. A caller (the VS Code extension) spawns this once per
/// project and keeps it alive across saves instead of spawning a fresh
/// `scan --resolve` per save.
///
/// Memory: a warm analyzer retains resolved element models and its RSS
/// grows with every newly-touched part of the import graph — the same
/// mechanism behind the historical multi-GB in-process plugin incident.
/// The daemon therefore recycles itself (clean exit) when its RSS passes
/// its recycle ceiling — the larger of `--max-rss-mb` and post-prewarm
/// RSS × [rssPrewarmMarginFactor] (a large project's warm baseline can
/// nearly exhaust the flag default on its own) — or after a bounded
/// number of requests; the extension detects the exit and respawns it.
///
/// Protocol: newline-delimited JSON on stdin/stdout (NDJSON). All logging
/// goes to stderr; stdout carries only protocol messages.
///
/// Startup:
///   dart run saropa_lints:scan_daemon `<projectRoot>` [--tier `<tier>`]
///       [--max-rss-mb `<mb>`]
///
/// Once the initial collection build + prewarm finishes (slow — about a
/// minute on a large project), the daemon writes one line to stdout:
/// `{"event":"ready"}`.
///
/// Request (one line on stdin):
///   {"id": "1", "files": ["lib/a.dart", "lib/b.dart"]}
///   {"id": "1", "files": [...], "excludeLane": "light"}
///   {"id": "2", "cmd": "shutdown"}
///   {"id": "3", "cmd": "listFiles"}
///
/// `excludeLane: "light"` drops the rules the in-process plugin runs itself
/// when the project is configured with `lane: light`, so the same finding is
/// not reported twice (see plans/PLAN_two_lane_daemon_architecture.md).
///
/// Response (one line on stdout per request):
///   {"id": "1", "ok": true, "diagnostics": [...], "summary": {...}}
///   {"id": "1", "ok": false, "error": "..."}
///   {"id": "3", "ok": true, "files": ["/abs/lib/a.dart", ...]}
///
/// `listFiles` walks the project the same way an unscoped `scan` would
/// (same exclusions: `.dart_tool/`, `build/`, generated files, etc.) and
/// returns absolute, normalized paths — the caller (the IDE baseline scan)
/// chunks this list itself before issuing per-chunk `files` requests, so a
/// full-project pass can stream partial results and be killed between
/// chunks instead of only at the very end.
///
/// EOF on stdin, or a `shutdown` command, exits the process (code 0).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/scan.dart';
import 'package:saropa_lints/src/config/rule_lane.dart' show RuleLane;
// bin/ is inside this package, so importing src/ directly is allowed; the
// reporter kill switch is deliberately NOT public API for consumers.
import 'package:saropa_lints/src/report/analysis_reporter.dart'
    show AnalysisReporter;
import 'package:saropa_lints/src/scan/scan_daemon_args.dart';

/// Recycle after this many requests even if RSS looks fine —
/// [ProcessInfo.currentRss] can misreport on some platforms, so request
/// count is the platform-independent backstop.
const int _maxRequestsBeforeRecycle = 500;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }
  // Arg parsing lives in lib/src/scan/scan_daemon_args.dart so it is
  // unit-testable; the exit-2 policy on bad args stays here in the binary.
  final parsed = parseScanDaemonArgs(args);
  if (parsed is ScanDaemonParseInvalid) {
    stderr.writeln(parsed.message);
    _printUsage();
    exit(2);
  }
  final options = (parsed as ScanDaemonParseOk).options;

  // The shared rule machinery schedules debounced report writes into the
  // scanned project (reports/<date>/*_saropa_lint_report.log). One-shot
  // scans exit before the debounce fires; a daemon lives long enough that
  // it would litter the TARGET project on every request. Suppress entirely.
  AnalysisReporter.disableForProcess();

  stderr.writeln(
    '[scan_daemon] Building analysis context for ${options.projectRoot}…',
  );
  final buildSw = Stopwatch()..start();
  final collection = ScanRunner.buildProjectCollection(options.projectRoot);
  stderr.writeln(
    '[scan_daemon] Context built in '
    '${(buildSw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s.',
  );

  // Prewarm BEFORE emitting `ready`: collection construction is cheap
  // (~1s), but the first getResolvedUnit() resolves the file's whole
  // transitive import graph (~1 min on a large app). Paying that here
  // means `ready` genuinely means warm and the first save-scan is fast.
  await _prewarm(collection, options.projectRoot);

  // The warm element models built during prewarm can consume most of the
  // configured budget on a large project (measured ~3650 MB on contacts vs
  // the 4096 default), which would recycle the daemon after ~35 saves and
  // re-pay the full warmup each time. Adapt the ceiling to what prewarm
  // actually cost: max(configured, post-prewarm RSS × margin).
  final maxRssMb = resolveRssCeilingMb(
    configuredMb: options.maxRssMb,
    postPrewarmRssMb: _currentRssMb(),
  );
  stderr.writeln(
    '[scan_daemon] Ready in '
    '${(buildSw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s '
    '(RSS ${_currentRssMb() ?? '?'} MB, recycle ceiling $maxRssMb MB).',
  );
  stdout.writeln(jsonEncode({'event': 'ready'}));

  await _serveRequests(collection, options, maxRssMb: maxRssMb);
}

Future<void> _serveRequests(
  AnalysisContextCollection collection,
  ScanDaemonOptions options, {
  required int maxRssMb,
}) async {
  var requestCount = 0;
  await for (final line in stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    Map<String, Object?> request;
    try {
      request = jsonDecode(trimmed) as Map<String, Object?>;
    } on Object catch (e) {
      stdout.writeln(jsonEncode({'ok': false, 'error': 'Invalid JSON: $e'}));
      continue;
    }

    final id = request['id'];
    if (request['cmd'] == 'shutdown') {
      stdout.writeln(jsonEncode({'id': id, 'ok': true, 'event': 'shutdown'}));
      exit(0);
    }
    if (request['cmd'] == 'listFiles') {
      // Cheap directory walk, not a scan — does not count toward the
      // recycle request budget below (no resolution/memory cost incurred).
      final files = ScanRunner.discoverDartFiles(options.projectRoot);
      stdout.writeln(jsonEncode({'id': id, 'ok': true, 'files': files}));
      continue;
    }

    await _handleScanRequest(collection, options, request);
    requestCount++;

    // Check AFTER responding so the triggering request still gets its
    // result; the extension sees the exit and respawns a fresh daemon.
    if (_memoryBudgetExceeded(
      maxRssMb: maxRssMb,
      requestCount: requestCount,
    )) {
      stderr.writeln(
        '[scan_daemon] Recycling after $requestCount request(s), '
        'RSS ${_currentRssMb() ?? '?'} MB (limit $maxRssMb MB).',
      );
      exit(0);
    }
  }
}

Future<void> _handleScanRequest(
  AnalysisContextCollection collection,
  ScanDaemonOptions options,
  Map<String, Object?> request,
) async {
  final id = request['id'];
  final filesRaw = request['files'];
  final files = filesRaw is List
      ? filesRaw.whereType<String>().toList()
      : const <String>[];
  if (files.isEmpty) {
    stdout.writeln(
      jsonEncode({'id': id, 'ok': false, 'error': 'No files given'}),
    );
    return;
  }

  // Two-lane de-duplication. The caller sets `"excludeLane": "light"` when the
  // project's in-process plugin is configured with `lane: light`, meaning the
  // severe/cheap/resolution-free rules already produce in-editor squiggles
  // (once edits settle, not while typing); running them here too would
  // double every such finding in the Problems panel. Any other value (or an
  // absent key) means scan everything, so a caller that does not know about
  // lanes keeps today's behavior.
  final excludeLightLane = request['excludeLane'] == 'light';

  try {
    final sw = Stopwatch()..start();
    final runner = ScanRunner(
      targetPath: options.projectRoot,
      dartFiles: files,
      tier: options.tier,
      messageSink: (msg) => stderr.writeln('[scan_daemon] $msg'),
      excludeLightLane: excludeLightLane,
      // The daemon is a separate process from the analysis server, so RSS
      // is not shared — full lane is always correct here.
      lane: RuleLane.full,
      // Keep the IDE issue cap — daemon output feeds the Problems tab.
      // disableIssueCap: false (default),
    );
    final diagnostics = await runner.runResolvedWithCollection(collection);
    if (diagnostics == null) {
      stdout.writeln(
        jsonEncode({
          'id': id,
          'ok': false,
          'error': 'No configuration found or unknown tier',
        }),
      );
      return;
    }
    stderr.writeln(
      '[scan_daemon] Scanned ${files.length} file(s) in '
      '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s '
      '(${diagnostics.length} diagnostic(s), '
      'RSS ${_currentRssMb() ?? '?'} MB).',
    );
    final payload = scanDiagnosticsToJson(diagnostics);
    stdout.writeln(jsonEncode({'id': id, 'ok': true, ...payload}));
  } on Object catch (e, st) {
    stderr.writeln('[scan_daemon] Scan failed: $e\n$st');
    stdout.writeln(jsonEncode({'id': id, 'ok': false, 'error': '$e'}));
  }
}

/// Current RSS in whole MB, or null when the platform reports nonsense
/// (some platforms return 0/-1 from [ProcessInfo.currentRss]).
int? _currentRssMb() {
  try {
    final rss = ProcessInfo.currentRss;
    if (rss <= 0) return null;
    return rss ~/ (1024 * 1024);
  } on Object {
    return null;
  }
}

/// True when the daemon should recycle: RSS past the ceiling, or the
/// request-count backstop reached (covers platforms where RSS is
/// unreadable).
bool _memoryBudgetExceeded({
  required int maxRssMb,
  required int requestCount,
}) {
  if (requestCount >= _maxRequestsBeforeRecycle) return true;
  final rssMb = _currentRssMb();
  return rssMb != null && rssMb > maxRssMb;
}

/// Resolves one representative file so the analyzer's element models for the
/// project's dependency graph are built before the daemon reports ready.
///
/// Failure is non-fatal: the daemon still works cold, the first request just
/// pays the warmup instead.
Future<void> _prewarm(
  AnalysisContextCollection collection,
  String projectRoot,
) async {
  final target = _findPrewarmTarget(projectRoot);
  if (target == null) {
    stderr.writeln('[scan_daemon] No lib/*.dart file found to prewarm with.');
    return;
  }
  stderr.writeln('[scan_daemon] Warming analyzer on $target…');
  final sw = Stopwatch()..start();
  try {
    final context = collection.contextFor(target);
    await context.currentSession.getResolvedUnit(target);
    stderr.writeln(
      '[scan_daemon] Warm in '
      '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s.',
    );
  } on Object catch (e) {
    stderr.writeln('[scan_daemon] Prewarm failed (continuing cold): $e');
  }
}

/// Picks the file whose transitive imports best cover the project:
/// `lib/main.dart` when present (an app's entry point imports nearly
/// everything), else the first Dart file under `lib/`.
///
/// Returned paths are absolute and normalized — the analyzer throws on
/// anything else (forward-slash roots crash it on Windows).
String? _findPrewarmTarget(String projectRoot) {
  final root = p.normalize(p.absolute(projectRoot));
  final mainFile = File(p.join(root, 'lib', 'main.dart'));
  if (mainFile.existsSync()) return mainFile.path;
  final libDir = Directory(p.join(root, 'lib'));
  if (!libDir.existsSync()) return null;
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      return p.normalize(entity.path);
    }
  }
  return null;
}

void _printUsage() {
  print('''
Usage: dart run saropa_lints:scan_daemon <projectRoot> [--tier <tier>] [--max-rss-mb <mb>]

Long-lived resolved-scan process for save-triggered IDE scans. Builds the
analyzer's AnalysisContextCollection once and prewarms it (slow), then
answers NDJSON scan requests on stdin with NDJSON responses on stdout until
stdin closes or a {"cmd":"shutdown"} request is received.

The daemon exits cleanly (code 0) to recycle itself when its resident
memory passes the recycle ceiling or after $_maxRequestsBeforeRecycle
requests; the caller is expected to respawn it. The ceiling is the larger
of --max-rss-mb (default $defaultMaxRssMb) and post-prewarm RSS ×
$rssPrewarmMarginFactor, so a large project whose warm analyzer already
uses most of the configured budget still gets proportional headroom.

See the top of bin/scan_daemon.dart for the full protocol.
''');
}
