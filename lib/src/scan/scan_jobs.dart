/// Parallelism configuration and recommendation for the scan command.
///
/// The syntactic scan is a per-file loop with no shared state between files,
/// so it can be sharded across worker isolates. This library decides HOW MANY
/// workers to use: [recommendJobs] derives a safe number from CPU count,
/// available memory and the file count, and [resolveJobs] turns the user's
/// `--jobs` value (`N`, `auto`, or unset) into a final [JobsDecision] that
/// the CLI can both act on and explain.
///
/// Safety first: more workers than memory can hold would cripple the machine,
/// so the recommendation is capped by available RAM and an absolute ceiling,
/// and an explicit user request above the recommendation is honored only up
/// to a hard cap (with a warning) unless it fits in memory.
library;

import 'dart:io' as io;

/// Estimated resident memory of one syntactic-scan worker isolate, in MB.
///
/// Measured: the serial syntactic scan of ~1400 files peaks near 100 MB RSS;
/// each worker re-registers every rule, so budget 3x that for headroom.
const int kWorkerMemoryBudgetMb = 300;

/// Fraction of currently available memory the scan may plan to use.
const double kMemoryUseFraction = 0.5;

/// Absolute ceiling for the *recommended* worker count. Beyond this, extra
/// workers mostly add startup cost (each re-registers every rule).
const int kMaxRecommendedJobs = 8;

/// Hard ceiling for an explicit `--jobs N`, regardless of CPU count.
const int kMaxJobs = 32;

/// Below this many files per worker, startup cost outweighs the speedup.
const int kMinFilesPerWorker = 50;

/// Below this many files the scan is fast enough serially; no hint is shown.
const int kHintFileThreshold = 200;

/// A recommended worker count with the reasoning behind it.
class JobsRecommendation {
  const JobsRecommendation({
    required this.jobs,
    required this.cores,
    required this.availableMemoryMb,
    required this.limitedBy,
  });

  /// Recommended number of workers (>= 1).
  final int jobs;

  /// Logical CPU count used for the calculation.
  final int cores;

  /// Available memory in MB, or null when it could not be determined.
  final int? availableMemoryMb;

  /// Human-readable name of the limiting factor ("CPU", "memory", "file
  /// count", "ceiling").
  final String limitedBy;
}

/// The final worker count for a run and a message explaining it.
class JobsDecision {
  const JobsDecision({required this.jobs, required this.notes});

  /// Worker count to use (1 = serial).
  final int jobs;

  /// Messages for stderr (suppressed by `--quiet`): hints and warnings.
  final List<String> notes;
}

/// Computes a safe recommended worker count.
///
/// The result is the minimum of: leave one core free ([cores] - 1), what
/// [kMemoryUseFraction] of [availableMemoryMb] can hold at
/// [kWorkerMemoryBudgetMb] per worker, a minimum [kMinFilesPerWorker] files
/// per worker, and [kMaxRecommendedJobs]. Always at least 1. When memory is
/// unknown the memory term is skipped but the ceiling still applies.
JobsRecommendation recommendJobs({
  required int fileCount,
  required int cores,
  int? availableMemoryMb,
}) {
  final candidates = <(String, int)>[
    ('CPU', cores - 1),
    ('file count', fileCount ~/ kMinFilesPerWorker),
    ('ceiling', kMaxRecommendedJobs),
  ];
  if (availableMemoryMb != null) {
    candidates.add((
      'memory',
      (availableMemoryMb * kMemoryUseFraction / kWorkerMemoryBudgetMb).floor(),
    ));
  }
  var best = candidates.first;
  for (final c in candidates) {
    if (c.$2 < best.$2) best = c;
  }
  return JobsRecommendation(
    jobs: best.$2 < 1 ? 1 : best.$2,
    cores: cores,
    availableMemoryMb: availableMemoryMb,
    limitedBy: best.$1,
  );
}

/// Parses a `--jobs` value: a positive integer or `auto`.
///
/// Returns `0` for `auto`, the integer for a valid count, or `null` when the
/// text is invalid.
int? parseJobsValue(String text) {
  final lower = text.trim().toLowerCase();
  if (lower == 'auto') return 0;
  final n = int.tryParse(lower);
  if (n == null || n < 1) return null;
  return n;
}

/// Decides the worker count from the user's [requested] value.
///
/// [requested]: `null` = flag not given (serial, with a hint when the scan is
/// large enough to benefit), `0` = `auto` (use the recommendation), `N` = use
/// N, clamped to [kMaxJobs] and warned about when above the recommendation.
/// [incompatibleReason] forces serial (e.g. `--profile`) and explains why.
JobsDecision resolveJobs({
  required int? requested,
  required int fileCount,
  required int cores,
  int? availableMemoryMb,
  String? incompatibleReason,
}) {
  final rec = recommendJobs(
    fileCount: fileCount,
    cores: cores,
    availableMemoryMb: availableMemoryMb,
  );
  final notes = <String>[];

  if (incompatibleReason != null) {
    if (requested != null) {
      notes.add('--jobs ignored: $incompatibleReason. Running serially.');
    }
    return JobsDecision(jobs: 1, notes: notes);
  }

  if (requested == null) {
    if (fileCount >= kHintFileThreshold && rec.jobs > 1) {
      notes.add(
        'Tip: this machine can scan $fileCount files faster with '
        '--jobs ${rec.jobs} (recommended; $cores CPUs, limited by '
        '${rec.limitedBy}). Use --jobs auto to apply it.',
      );
    }
    return JobsDecision(jobs: 1, notes: notes);
  }

  if (requested == 0) {
    notes.add(
      'Using ${rec.jobs} worker(s) (--jobs auto; $cores CPUs, limited by '
      '${rec.limitedBy}).',
    );
    return JobsDecision(jobs: rec.jobs, notes: notes);
  }

  var jobs = requested;
  if (jobs > kMaxJobs) {
    notes.add('--jobs $requested capped to $kMaxJobs.');
    jobs = kMaxJobs;
  }
  if (jobs > fileCount) jobs = fileCount < 1 ? 1 : fileCount;
  final mem = availableMemoryMb;
  if (mem != null && jobs * kWorkerMemoryBudgetMb > mem * kMemoryUseFraction) {
    notes.add(
      'Warning: --jobs $jobs may need ~${jobs * kWorkerMemoryBudgetMb} MB but '
      'only $mem MB is available; recommended is ${rec.jobs}. '
      'Risk of heavy swapping.',
    );
  } else if (jobs > rec.jobs) {
    notes.add('Note: --jobs $jobs exceeds the recommended ${rec.jobs}.');
  }
  return JobsDecision(jobs: jobs, notes: notes);
}

/// Reads available memory in MB, or null when unsupported or unreadable.
///
/// Linux only (`MemAvailable` from `/proc/meminfo`); other platforms return
/// null and the recommendation then relies on the CPU and ceiling limits.
int? readAvailableMemoryMb() {
  try {
    if (!io.Platform.isLinux) return null;
    final text = io.File('/proc/meminfo').readAsStringSync();
    final m = RegExp(
      r'^MemAvailable:\s+(\d+)\s+kB',
      multiLine: true,
    ).firstMatch(text);
    if (m == null) return null;
    return int.parse(m.group(1)!) ~/ 1024;
  } on Object {
    return null;
  }
}
