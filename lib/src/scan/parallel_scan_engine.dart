/// Adaptive parallel scan engine.
///
/// Splits the file list into small ordered chunks and feeds them to a pool of
/// persistent worker isolates through a work queue. Compared with static
/// sharding this gives:
///
///  * **Determinism** — results are concatenated in chunk order, so output is
///    identical for any worker count.
///  * **Load balancing** — slow regions of the tree don't strand one worker.
///  * **Safety** — a watchdog samples process RSS and free system memory every
///    [ParallelScanOptions.tickInterval] and feeds a `ThrottleController`:
///    under pressure idle workers are killed and fewer chunks run at once;
///    when calm returns the pool grows back. If a single worker still exceeds
///    the budget the scan stops early with partial results instead of
///    crippling the machine.
///  * **Resilience** — a chunk that exceeds [ParallelScanOptions.chunkTimeout]
///    (a pathological file or rule) or whose worker dies is split into
///    single-file retries; a single file that hangs/crashes twice is skipped
///    and reported. Slow files are surfaced so users can see what dominates.
///  * **Visibility** — human progress (TTY bar or periodic plain lines for CI
///    logs) and machine-readable `SAROPA_SCAN_EVENT {json}` lines the VS Code
///    extension consumes.
///
/// The engine is independent of `ScanRunner`: callers supply the worker entry
/// point and an in-process fallback, which keeps it unit-testable with fake
/// workers and fake memory samplers.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'scan_diagnostic.dart';
import 'scan_pressure.dart';

/// Prefix of machine-readable event lines written to stderr.
const String kScanEventPrefix = 'SAROPA_SCAN_EVENT ';

/// A file whose scan exceeded the slow-file threshold.
class SlowFile {
  const SlowFile(this.path, this.ms);
  final String path;
  final int ms;
}

/// Result of scanning one chunk (worker → parent; all fields sendable).
class ChunkOutcome {
  const ChunkOutcome({
    required this.diagnostics,
    this.stopped = false,
    this.slowFiles = const [],
    this.outsideRoots = 0,
  });

  final List<ScanDiagnostic> diagnostics;

  /// True when the scan was asked to stop (`.saropa_stop`) mid-chunk.
  final bool stopped;
  final List<SlowFile> slowFiles;

  /// Files skipped because they lie outside the analysis roots (resolved scan).
  final int outsideRoots;
}

/// A function that scans one chunk of files.
typedef ChunkScanner = Future<ChunkOutcome> Function(List<String> files);

/// Opens a [ChunkScanner] inside a worker (loads rules once). Returns null
/// when the scan cannot run (e.g. all rules disabled → nothing to do).
typedef ChunkScannerFactory = Future<ChunkScanner?> Function(Object spec);

/// How progress is reported.
enum ProgressStyle {
  /// TTY → single updating line; otherwise periodic plain lines.
  auto,

  /// Single updating `\r` line.
  bar,

  /// One plain line every [ParallelScanOptions.plainInterval] (CI logs).
  plain,

  /// Only machine-readable events.
  json,

  /// No progress output.
  none,
}

/// Engine configuration.
class ParallelScanOptions {
  const ParallelScanOptions({
    required this.jobs,
    required this.limits,
    this.chunkTimeout = const Duration(seconds: 120),
    this.tickInterval = const Duration(milliseconds: 500),
    this.plainInterval = const Duration(seconds: 15),
    this.slowFileMs = 3000,
    this.progress = ProgressStyle.auto,
    this.hasTerminal = false,
    this.onMessage,
    this.shedCooldownTicks = 2,
    this.rampUpAfterCalmTicks = 20,
    this.abortAfterCriticalTicks = 6,
    this.chunkSize,
  });

  /// Number of workers to start (ceiling for ramp-up).
  final int jobs;

  /// Memory limits driving the throttle.
  final PressureLimits limits;

  /// Maximum wall time for one chunk before its worker is killed and the
  /// chunk retried file-by-file.
  final Duration chunkTimeout;

  /// Watchdog sampling period.
  final Duration tickInterval;

  /// Interval between plain progress lines (non-TTY).
  final Duration plainInterval;

  /// Files slower than this are reported (ms).
  final int slowFileMs;

  final ProgressStyle progress;

  /// Whether stderr is a terminal (selects bar vs plain for [ProgressStyle.auto]).
  final bool hasTerminal;

  /// Human message sink (stderr). Null = silent (quiet).
  final void Function(String message)? onMessage;

  final int shedCooldownTicks;
  final int rampUpAfterCalmTicks;
  final int abortAfterCriticalTicks;

  /// Explicit files-per-chunk; null = derived from file and worker count.
  final int? chunkSize;
}

/// One throttle transition, for the report.
class ThrottleEvent {
  const ThrottleEvent(this.from, this.to, this.reason, this.atMs);
  final int from;
  final int to;
  final String reason;
  final int atMs;
}

/// What happened during the scan (for summaries and the extension).
class ParallelScanReport {
  int filesTotal = 0;
  int filesScanned = 0;
  int workersStarted = 0;
  int workersRestarted = 0;

  /// Files skipped because they are outside the analysis roots.
  int outsideRoots = 0;
  int minAllowedWorkers = 0;
  int peakRssMb = 0;
  int? minAvailableMb;
  int elapsedMs = 0;
  bool aborted = false;
  String? abortReason;
  bool usedFallback = false;
  final List<ThrottleEvent> throttleEvents = [];
  final List<SlowFile> slowFiles = [];
  final List<String> skippedFiles = [];

  Map<String, Object?> toJson() => {
    'filesTotal': filesTotal,
    'filesScanned': filesScanned,
    'workersStarted': workersStarted,
    'workersRestarted': workersRestarted,
    'outsideRoots': outsideRoots,
    'minAllowedWorkers': minAllowedWorkers,
    'peakRssMb': peakRssMb,
    'minAvailableMb': minAvailableMb,
    'elapsedMs': elapsedMs,
    'aborted': aborted,
    'abortReason': abortReason,
    'usedFallback': usedFallback,
    'throttleEvents': throttleEvents.length,
    'slowFiles': [
      for (final s in slowFiles.take(10)) {'file': s.path, 'ms': s.ms},
    ],
    'skippedFiles': skippedFiles,
  };
}

/// Engine output.
class ParallelScanResult {
  const ParallelScanResult(this.diagnostics, this.report);
  final List<ScanDiagnostic> diagnostics;
  final ParallelScanReport report;
}

/// Message handed to a worker isolate at spawn.
class WorkerBootstrap {
  const WorkerBootstrap(this.spec, this.toParent, this.workerId);
  final Object spec;
  final SendPort toParent;
  final int workerId;
}

/// Worker-side loop: opens the scanner, announces readiness, then serves
/// `['chunk', id, files]` commands until `['stop']`.
Future<void> runWorkerLoop(
  WorkerBootstrap boot,
  ChunkScannerFactory open,
) async {
  final commands = ReceivePort();
  ChunkScanner? scanner;
  try {
    scanner = await open(boot.spec);
  } on Object catch (e) {
    boot.toParent.send(['fatal', '$e']);
    commands.close();
    return;
  }
  if (scanner == null) {
    // Nothing to scan (no rules): behave as a worker that returns no results.
    scanner = (files) async => const ChunkOutcome(diagnostics: []);
  }
  boot.toParent.send(['ready', commands.sendPort]);
  await for (final msg in commands) {
    if (msg is! List || msg.isEmpty) continue;
    if (msg[0] == 'stop') break;
    if (msg[0] == 'chunk') {
      final id = msg[1] as int;
      final files = (msg[2] as List).cast<String>();
      try {
        final out = await scanner(files);
        boot.toParent.send([
          'done',
          id,
          out.diagnostics,
          out.stopped,
          [
            for (final s in out.slowFiles) [s.path, s.ms],
          ],
          out.outsideRoots,
        ]);
      } on Object catch (e) {
        boot.toParent.send(['error', id, '$e']);
      }
    }
  }
  commands.close();
}

class _Item {
  _Item(this.id, this.slot, this.part, this.files);
  final int id;
  final int slot; // original chunk position — merge order
  final int part; // sub-order within a split chunk
  final List<String> files;
  bool isRetry = false;
}

class _Worker {
  _Worker(this.id);
  final int id;
  Isolate? isolate;
  ReceivePort? port;
  ReceivePort? exitPort;
  ReceivePort? errPort;
  SendPort? commands;
  bool ready = false;
  bool dead = false;
  _Item? busy;
  DateTime? busySince;
}

/// Runs the chunked parallel scan. See the library docs.
///
/// [readRssMb] / [readAvailableMb] are injectable so tests can simulate
/// memory pressure. [inlineScan] is the in-process fallback used if workers
/// cannot start.
Future<ParallelScanResult> runChunkedScan({
  required List<String> files,
  required ParallelScanOptions options,
  required Object spec,
  required void Function(WorkerBootstrap) workerEntry,
  required ChunkScanner inlineScan,
  required int Function() readRssMb,
  required int? Function() readAvailableMb,
}) async {
  final report = ParallelScanReport()..filesTotal = files.length;
  final sw = Stopwatch()..start();
  final msg = options.onMessage;

  final jobs = options.jobs < 1
      ? 1
      : (options.jobs > files.length ? files.length : options.jobs);
  if (files.isEmpty) return ParallelScanResult(const [], report);

  // Chunking: aim for ~12 chunks per worker for balance, bounded [5, 50].
  final chunkSize =
      options.chunkSize ?? (files.length ~/ (jobs * 12)).clamp(5, 50).toInt();
  final queue = <_Item>[];
  var nextId = 0;
  var slot = 0;
  for (var i = 0; i < files.length; i += chunkSize) {
    final end = i + chunkSize > files.length ? files.length : i + chunkSize;
    queue.add(_Item(nextId++, slot++, 0, files.sublist(i, end)));
  }
  final totalSlots = slot;

  // results[slot][part] = diagnostics
  final results = <int, Map<int, List<ScanDiagnostic>>>{};
  final pendingParts = <int, int>{}; // slot -> outstanding parts
  for (var s = 0; s < totalSlots; s++) {
    pendingParts[s] = 1;
  }

  final controller = ThrottleController(
    maxWorkers: jobs,
    limits: options.limits,
    shedCooldown: options.shedCooldownTicks,
    rampUpAfterCalmTicks: options.rampUpAfterCalmTicks,
    abortAfterCriticalTicks: options.abortAfterCriticalTicks,
  );
  report.minAllowedWorkers = jobs;

  final workers = <_Worker>[];
  var nextWorkerId = 0;
  var fatalCount = 0;
  var allowed = jobs;
  var filesDone = 0;
  var stopRequested = false;
  var inlineMode = false;
  final done = Completer<void>();
  Timer? ticker;
  var lastPlain = DateTime.now();
  var lastProgressEventMs = -1000;
  String? lastBarLine;

  void emit(String event, Map<String, Object?> data) {
    if (options.progress != ProgressStyle.json) return;
    // JSON events go through onMessage so quiet/redirect rules stay in one place.
    msg?.call('$kScanEventPrefix${jsonEncode({'event': event, ...data})}');
  }

  bool jsonMode = options.progress == ProgressStyle.json;
  void human(String line) {
    if (jsonMode) return;
    msg?.call(line);
  }

  int liveWorkers() => workers.where((w) => !w.dead).length;
  int busyWorkers() => workers.where((w) => !w.dead && w.busy != null).length;

  void finishIfDone() {
    if (done.isCompleted) return;
    final anyBusy = workers.any((w) => w.busy != null);
    if (queue.isEmpty && !anyBusy && !inlineMode) done.complete();
  }

  void killWorker(_Worker w) {
    if (w.dead) return;
    w.dead = true;
    try {
      w.commands?.send(['stop']);
    } on Object {
      // ignore: worker may be gone already
    }
    w.isolate?.kill(priority: Isolate.immediate);
    w.port?.close();
    w.exitPort?.close();
    w.errPort?.close();
  }

  void recordResult(_Item item, List<ScanDiagnostic> diags) {
    results.putIfAbsent(item.slot, () => {})[item.part] = diags;
    pendingParts[item.slot] = (pendingParts[item.slot] ?? 1) - 1;
    filesDone += item.files.length;
    report.filesScanned = filesDone;
  }

  void splitAndRequeue(_Item item, String why) {
    if (item.files.length > 1) {
      // Retry file-by-file at the FRONT so the culprit is isolated quickly.
      final parts = <_Item>[];
      for (var i = 0; i < item.files.length; i++) {
        parts.add(
          _Item(nextId++, item.slot, i, [item.files[i]])..isRetry = true,
        );
      }
      pendingParts[item.slot] =
          (pendingParts[item.slot] ?? 1) - 1 + parts.length;
      queue.insertAll(0, parts);
    } else {
      final f = item.files.single;
      report.skippedFiles.add(f);
      human('  Skipped $f ($why) — see the summary.');
      emit('skipped', {'file': f, 'reason': why});
      pendingParts[item.slot] = (pendingParts[item.slot] ?? 1) - 1;
      results.putIfAbsent(item.slot, () => {})[item.part] = const [];
      filesDone += 1;
      report.filesScanned = filesDone;
    }
  }

  late void Function() dispatch;
  late void Function() ensureWorkers;

  Future<void> runInline() async {
    // Last resort: workers cannot start (or all died) → scan in this isolate.
    inlineMode = true;
    report.usedFallback = true;
    human('  Parallel workers unavailable — continuing in-process.');
    while (queue.isNotEmpty && !stopRequested) {
      final item = queue.removeAt(0);
      try {
        final out = await inlineScan(item.files);
        report.slowFiles.addAll(out.slowFiles);
        report.outsideRoots += out.outsideRoots;
        recordResult(item, out.diagnostics);
        if (out.stopped) stopRequested = true;
      } on Object catch (e) {
        human('  In-process scan failed for ${item.files.first}: $e');
        report.skippedFiles.addAll(item.files);
        recordResult(item, const []);
      }
    }
    inlineMode = false;
    if (!done.isCompleted) done.complete();
  }

  void spawnWorker() {
    final w = _Worker(nextWorkerId++);
    workers.add(w);
    report.workersStarted++;
    if (report.workersStarted > jobs) report.workersRestarted++;
    final port = ReceivePort();
    final exitPort = ReceivePort();
    final errPort = ReceivePort();
    w.port = port;
    w.exitPort = exitPort;
    w.errPort = errPort;

    void onCrash(String why) {
      if (w.dead) return;
      final item = w.busy;
      w.busy = null;
      killWorker(w);
      if (item != null) splitAndRequeue(item, why);
      if (!stopRequested && !done.isCompleted) {
        if (liveWorkers() == 0 && queue.isNotEmpty && fatalCount >= 2) {
          unawaited(runInline());
        } else {
          ensureWorkers();
          dispatch();
        }
      }
      finishIfDone();
    }

    port.listen((m) {
      if (m is! List || m.isEmpty) return;
      switch (m[0]) {
        case 'ready':
          w.commands = m[1] as SendPort;
          w.ready = true;
          dispatch();
        case 'fatal':
          fatalCount++;
          human('  Worker failed to start: ${m[1]}');
          onCrash('worker failed to start');
        case 'done':
          final item = w.busy;
          w.busy = null;
          w.busySince = null;
          if (item == null) return;
          final diags = (m[2] as List).cast<ScanDiagnostic>();
          if (m[3] == true) stopRequested = true;
          for (final s in (m[4] as List)) {
            final sf = SlowFile((s as List)[0] as String, s[1] as int);
            report.slowFiles.add(sf);
            emit('slow', {'file': sf.path, 'ms': sf.ms});
          }
          report.outsideRoots += (m[5] as int?) ?? 0;
          recordResult(item, diags);
          if (stopRequested) {
            if (!done.isCompleted) done.complete();
            return;
          }
          // Throttled below the live pool → retire this worker to free RAM.
          if (liveWorkers() > allowed && queue.isNotEmpty) {
            killWorker(w);
          }
          dispatch();
          finishIfDone();
        case 'error':
          // The scanner threw on this chunk (not a crash): retry per file.
          final item = w.busy;
          w.busy = null;
          w.busySince = null;
          if (item != null) splitAndRequeue(item, 'scan error: ${m[2]}');
          dispatch();
          finishIfDone();
      }
    });
    exitPort.listen((_) => onCrash('worker exited unexpectedly'));
    errPort.listen((e) => onCrash('worker crashed: $e'));

    Isolate.spawn(
      workerEntry,
      WorkerBootstrap(spec, port.sendPort, w.id),
      onExit: exitPort.sendPort,
      onError: errPort.sendPort,
      errorsAreFatal: true,
    ).then(
      (iso) {
        w.isolate = iso;
        if (w.dead) iso.kill(priority: Isolate.immediate);
      },
      onError: (Object e) {
        fatalCount++;
        onCrash('could not spawn worker: $e');
      },
    );
  }

  ensureWorkers = () {
    if (stopRequested || done.isCompleted) return;
    // Repeated startup failures: stop respawning; the crash handler falls
    // back to in-process scanning once no workers remain.
    if (fatalCount >= 3) return;
    // Spawn only as many as can usefully run: allowed, remaining chunks.
    while (liveWorkers() < allowed &&
        liveWorkers() < queue.length + busyWorkers()) {
      spawnWorker();
    }
  };

  dispatch = () {
    if (stopRequested || done.isCompleted) return;
    for (final w in workers) {
      if (queue.isEmpty) break;
      if (w.dead || !w.ready || w.busy != null) continue;
      if (busyWorkers() >= allowed) break;
      final item = queue.removeAt(0);
      w.busy = item;
      w.busySince = DateTime.now();
      w.commands!.send(['chunk', item.id, item.files]);
    }
  };

  void printProgress(int rss, int? avail, {bool force = false}) {
    if (options.progress == ProgressStyle.none) return;
    final pct = files.isEmpty ? 100 : (filesDone * 100 ~/ files.length);
    final rate = sw.elapsedMilliseconds > 0
        ? (filesDone * 1000 / sw.elapsedMilliseconds).round()
        : 0;
    final line =
        'Scanned $filesDone/${files.length} files ($pct%) · $rate files/s · '
        '${busyWorkers()}/${liveWorkers()} workers (allowed $allowed) · '
        '$rss MB${avail != null ? ' · ${avail} MB free' : ''}';
    final style = options.progress == ProgressStyle.auto
        ? (options.hasTerminal ? ProgressStyle.bar : ProgressStyle.plain)
        : options.progress;
    if (style == ProgressStyle.bar) {
      if (line != lastBarLine) {
        lastBarLine = line;
        msg?.call('\r  $line${' ' * 10}');
      }
    } else if (style == ProgressStyle.plain) {
      final now = DateTime.now();
      if (force || now.difference(lastPlain) >= options.plainInterval) {
        lastPlain = now;
        msg?.call('  $line');
      }
    }
    if (options.progress == ProgressStyle.json &&
        (sw.elapsedMilliseconds - lastProgressEventMs >= 1000 || force)) {
      lastProgressEventMs = sw.elapsedMilliseconds;
      emit('progress', {
        'done': filesDone,
        'total': files.length,
        'workers': liveWorkers(),
        'allowed': allowed,
        'rssMb': rss,
        'availableMb': avail,
        'elapsedMs': sw.elapsedMilliseconds,
      });
    }
  }

  // Records peak/min figures; also called at start and end so short scans
  // that finish between watchdog ticks still report real numbers.
  (int, int?) sampleMemory() {
    final rss = readRssMb();
    final avail = readAvailableMb();
    if (rss > report.peakRssMb) report.peakRssMb = rss;
    if (avail != null &&
        (report.minAvailableMb == null || avail < report.minAvailableMb!)) {
      report.minAvailableMb = avail;
    }
    return (rss, avail);
  }

  void onTick() {
    if (done.isCompleted) return;
    final (rss, avail) = sampleMemory();

    // Chunk watchdog: a busy worker past the timeout is wedged.
    final now = DateTime.now();
    for (final w in List.of(workers)) {
      final since = w.busySince;
      if (!w.dead &&
          w.busy != null &&
          since != null &&
          now.difference(since) > options.chunkTimeout) {
        final item = w.busy!;
        w.busy = null;
        w.busySince = null;
        killWorker(w);
        human(
          '  A worker exceeded ${options.chunkTimeout.inSeconds}s on '
          '${item.files.length == 1 ? item.files.single : '${item.files.length} files'}'
          ' — restarting it${item.files.length > 1 ? ' and retrying file by file' : ''}.',
        );
        splitAndRequeue(
          item,
          'timed out after ${options.chunkTimeout.inSeconds}s',
        );
        ensureWorkers();
        dispatch();
      }
    }

    final decision = controller.step(
      PressureSample(rssMb: rss, availableMb: avail),
    );
    if (decision.changed) {
      final from = allowed;
      allowed = decision.allowedWorkers;
      if (allowed < report.minAllowedWorkers) {
        report.minAllowedWorkers = allowed;
      }
      report.throttleEvents.add(
        ThrottleEvent(
          from,
          allowed,
          decision.verdict.reason,
          sw.elapsedMilliseconds,
        ),
      );
      if (allowed < from) {
        human(
          '  Memory pressure: $from → $allowed workers '
          '(${decision.verdict.reason}).',
        );
        // Retire idle workers beyond the allowance right away to free RAM.
        for (final w in List.of(workers)) {
          if (liveWorkers() <= allowed) break;
          if (!w.dead && w.busy == null) killWorker(w);
        }
      } else {
        human('  Pressure eased: $from → $allowed workers.');
        ensureWorkers();
        dispatch();
      }
      emit('throttle', {
        'from': from,
        'to': allowed,
        'level': decision.verdict.level.name,
        'reason': decision.verdict.reason,
      });
    }
    if (decision.shouldAbort && !report.aborted) {
      report.aborted = true;
      report.abortReason =
          '${decision.verdict.reason} even with a single worker';
      human('  Stopping early to protect your machine: ${report.abortReason}.');
      emit('abort', {'reason': report.abortReason});
      stopRequested = true;
      if (!done.isCompleted) done.complete();
      return;
    }
    printProgress(rss, avail);
    finishIfDone();
  }

  // Start.
  emit('start', {
    'files': files.length,
    'workers': jobs,
    'maxMemoryMb': options.limits.maxMemoryMb,
    'reserveMb': options.limits.reserveMb,
  });
  sampleMemory();
  ensureWorkers();
  ticker = Timer.periodic(options.tickInterval, (_) => onTick());

  await done.future;
  ticker.cancel();
  sampleMemory();
  for (final w in workers) {
    killWorker(w);
  }
  report.elapsedMs = sw.elapsedMilliseconds;
  if (options.progress == ProgressStyle.bar ||
      (options.progress == ProgressStyle.auto && options.hasTerminal)) {
    msg?.call('\r${' ' * 100}\r');
  }

  // Merge in chunk order. After an abort/stop, unfinished slots are simply
  // missing (partial results).
  final merged = <ScanDiagnostic>[];
  for (var s = 0; s < totalSlots; s++) {
    final parts = results[s];
    if (parts == null) continue;
    final keys = parts.keys.toList()..sort();
    for (final k in keys) {
      merged.addAll(parts[k]!);
    }
  }
  report.slowFiles.sort((a, b) => b.ms.compareTo(a.ms));
  emit('summary', report.toJson());
  return ParallelScanResult(merged, report);
}
