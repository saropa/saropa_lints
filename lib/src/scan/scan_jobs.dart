/// Parallelism configuration, machine detection and recommendations for the
/// scan command.
///
/// The scan can be sharded across worker isolates. This library decides HOW
/// MANY workers to use and how much memory the scan may plan to use:
///
///  * [detectMachine] reads CPU count and memory, honoring container (cgroup)
///    limits — in Docker/Kubernetes CI, `Platform.numberOfProcessors` reports
///    the HOST's cores, and oversubscribing a 2-CPU quota with 16 workers is a
///    classic way to make a CI job crawl or get OOM-killed.
///  * [recommendJobs] derives a safe worker count from the [MachineInfo].
///  * [resolveJobs] turns the user's `--jobs` value (`N`, `auto`, `off`, or
///    unset) into a final [JobsDecision] that the CLI can both act on and
///    explain.
///
/// Safety first: the recommendation is capped by available RAM, leaves a CPU
/// core free on interactive machines, and an explicit request above what fits
/// in memory is honored but warned about. A runtime watchdog
/// (`parallel_scan_engine.dart`) additionally throttles if the machine comes
/// under pressure mid-scan.
library;

import 'dart:io' as io;

/// Estimated resident memory of one syntactic-scan worker isolate, in MB.
///
/// Measured: the serial syntactic scan of ~1400 files peaks near 100 MB RSS;
/// each worker re-registers every rule, so budget 3x that for headroom.
const int kWorkerMemoryBudgetMb = 300;

/// Estimated resident memory of one RESOLVED-scan worker, in MB. A resolved
/// worker owns a whole analyzer context collection (element models for the
/// project's transitive imports), which is an order of magnitude heavier.
const int kResolvedWorkerMemoryBudgetMb = 1800;

/// Fixed overhead of the parent process (rule registry, merge buffers), in MB.
const int kParentMemoryBaseMb = 300;

/// Fraction of currently available memory the scan may plan to use.
const double kMemoryUseFraction = 0.5;

/// Absolute ceiling for the *recommended* worker count. Beyond this, extra
/// workers mostly add startup cost (each re-registers every rule).
const int kMaxRecommendedJobs = 8;

/// Ceiling for the recommended count of RESOLVED workers: each one is heavy.
const int kMaxRecommendedResolvedJobs = 3;

/// Hard ceiling for an explicit `--jobs N`, regardless of CPU count.
const int kMaxJobs = 32;

/// Below this many files per worker, startup cost outweighs the speedup.
const int kMinFilesPerWorker = 50;

/// Resolved workers pay a ~minute of context warmup, so they only pay off on
/// much larger file counts.
const int kMinResolvedFilesPerWorker = 400;

/// Below this many files the scan is fast enough serially; no hint is shown.
const int kHintFileThreshold = 200;

/// A snapshot of the machine's capacity, with container limits applied.
class MachineInfo {
  const MachineInfo({
    required this.cores,
    required this.availableMemoryMb,
    required this.totalMemoryMb,
    required this.isCi,
    this.cpuLimitedByContainer = false,
    this.memoryLimitedByContainer = false,
  });

  /// Usable logical CPUs (container CPU quota applied, never below 1).
  final int cores;

  /// Memory currently available to this process in MB, or null if unknown.
  final int? availableMemoryMb;

  /// Total memory visible to this process in MB (container limit applied), or
  /// null if unknown.
  final int? totalMemoryMb;

  /// True when running under a CI system (CI/GITHUB_ACTIONS/etc. env vars).
  final bool isCi;

  /// True when [cores] came from a cgroup CPU quota rather than the host.
  final bool cpuLimitedByContainer;

  /// True when memory figures came from a cgroup limit rather than the host.
  final bool memoryLimitedByContainer;
}

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

/// The final worker count for a run and messages explaining it.
class JobsDecision {
  const JobsDecision({required this.jobs, required this.notes});

  /// Worker count to use (1 = serial).
  final int jobs;

  /// Messages for stderr (suppressed by `--quiet`): hints and warnings.
  final List<String> notes;
}

/// Computes a safe recommended worker count.
///
/// The result is the minimum of: the CPU count (minus one on interactive
/// machines so the desktop stays responsive; all cores in [isCi]), what
/// [kMemoryUseFraction] of [availableMemoryMb] can hold at the per-worker
/// budget, a minimum files-per-worker ratio, and a ceiling. Always at least
/// 1. When memory is unknown the memory term is skipped but the ceiling still
/// applies.
JobsRecommendation recommendJobs({
  required int fileCount,
  required int cores,
  int? availableMemoryMb,
  bool isCi = false,
  bool resolved = false,
}) {
  final perWorker = resolved
      ? kResolvedWorkerMemoryBudgetMb
      : kWorkerMemoryBudgetMb;
  final candidates = <(String, int)>[
    ('CPU', isCi ? cores : cores - 1),
    (
      'file count',
      fileCount ~/ (resolved ? kMinResolvedFilesPerWorker : kMinFilesPerWorker),
    ),
    ('ceiling', resolved ? kMaxRecommendedResolvedJobs : kMaxRecommendedJobs),
  ];
  if (availableMemoryMb != null) {
    final usable = availableMemoryMb * kMemoryUseFraction - kParentMemoryBaseMb;
    candidates.add(('memory', (usable / perWorker).floor()));
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

/// Default process-RSS budget (MB) for a scan with [jobs] workers: the
/// parent's base plus each worker's estimate, but never more than
/// [kMemoryUseFraction] of the memory that was available at start (when
/// known), and never below a floor that lets a single worker run.
int defaultMaxMemoryMb({
  required int jobs,
  required bool resolved,
  int? availableMemoryMb,
}) {
  final perWorker = resolved
      ? kResolvedWorkerMemoryBudgetMb
      : kWorkerMemoryBudgetMb;
  // Headroom factor: the estimate is a typical figure, not a ceiling.
  final planned = ((kParentMemoryBaseMb + jobs * perWorker) * 1.5).round();
  final floor = resolved ? 4096 : 1500;
  var limit = planned < floor ? floor : planned;
  if (availableMemoryMb != null) {
    final cap = (availableMemoryMb * 0.7).round();
    if (cap < limit) limit = cap < 512 ? 512 : cap;
  }
  return limit;
}

/// Parses a `--jobs` value: a positive integer, `auto`, or `off`/`serial`.
///
/// Returns `0` for `auto`, `1` for `off`/`serial`, the integer for a valid
/// count, or `null` when the text is invalid.
int? parseJobsValue(String text) {
  final lower = text.trim().toLowerCase();
  if (lower == 'auto') return 0;
  if (lower == 'off' || lower == 'serial' || lower == 'none') return 1;
  final n = int.tryParse(lower);
  if (n == null || n < 1) return null;
  return n;
}

/// Decides the worker count from the user's [requested] value.
///
/// [requested]: `null` = flag/env not given → auto (the best default: the
/// watchdog makes it safe), `0` = `auto` (use the recommendation), `N` = use
/// N, clamped to [kMaxJobs] and warned about when it will not fit in memory.
/// [incompatibleReason] forces serial (e.g. `--profile`) and explains why.
///
/// For [resolved] scans an unset value stays serial (each resolved worker is
/// a full analyzer context — opt in explicitly) but a hint is shown.
JobsDecision resolveJobs({
  required int? requested,
  required int fileCount,
  required MachineInfo machine,
  bool resolved = false,
  String? incompatibleReason,
}) {
  final rec = recommendJobs(
    fileCount: fileCount,
    cores: machine.cores,
    availableMemoryMb: machine.availableMemoryMb,
    isCi: machine.isCi,
    resolved: resolved,
  );
  final notes = <String>[];
  final cpuNote = machine.cpuLimitedByContainer
      ? '${machine.cores} CPUs (container limit)'
      : '${machine.cores} CPUs';

  if (incompatibleReason != null) {
    if (requested != null && requested != 1) {
      notes.add('--jobs ignored: $incompatibleReason. Running serially.');
    }
    return JobsDecision(jobs: 1, notes: notes);
  }

  // Unset: auto for the cheap syntactic scan; serial (with a hint) for the
  // heavy resolved scan.
  if (requested == null) {
    if (resolved) {
      if (fileCount >= kMinResolvedFilesPerWorker * 2 && rec.jobs > 1) {
        notes.add(
          'Tip: a resolved scan of $fileCount files can use up to '
          '${rec.jobs} workers (~$kResolvedWorkerMemoryBudgetMb MB each; '
          '$cpuNote, limited by ${rec.limitedBy}). '
          'Use --jobs ${rec.jobs} to opt in.',
        );
      }
      return JobsDecision(jobs: 1, notes: notes);
    }
    if (rec.jobs > 1 && fileCount >= kHintFileThreshold) {
      notes.add(
        'Using ${rec.jobs} workers ($cpuNote, limited by ${rec.limitedBy}). '
        'Pass --jobs 1 to scan serially or --jobs N to choose.',
      );
      return JobsDecision(jobs: rec.jobs, notes: notes);
    }
    return JobsDecision(jobs: 1, notes: notes);
  }

  if (requested == 0) {
    notes.add(
      'Using ${rec.jobs} worker(s) (--jobs auto; $cpuNote, limited by '
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
  final perWorker = resolved
      ? kResolvedWorkerMemoryBudgetMb
      : kWorkerMemoryBudgetMb;
  final mem = machine.availableMemoryMb;
  if (jobs > 1 && mem != null && jobs * perWorker > mem * kMemoryUseFraction) {
    notes.add(
      'Warning: --jobs $jobs may need ~${jobs * perWorker} MB but only '
      '$mem MB is available; recommended is ${rec.jobs}. The scan will '
      'throttle itself if memory runs low.',
    );
  } else if (jobs > machine.cores) {
    notes.add(
      'Note: --jobs $jobs exceeds the ${machine.cores} available CPUs.',
    );
  } else if (jobs > rec.jobs) {
    notes.add('Note: --jobs $jobs exceeds the recommended ${rec.jobs}.');
  }
  return JobsDecision(jobs: jobs, notes: notes);
}

// ---------------------------------------------------------------------------
// Machine detection
// ---------------------------------------------------------------------------

/// Env vars that identify a CI environment.
const List<String> kCiEnvVars = [
  'CI',
  'GITHUB_ACTIONS',
  'GITLAB_CI',
  'BUILDKITE',
  'TF_BUILD',
  'JENKINS_URL',
  'CIRCLECI',
  'TRAVIS',
  'TEAMCITY_VERSION',
  'BITBUCKET_BUILD_NUMBER',
];

/// True when any known CI env var is set (and not explicitly false/0).
bool detectCi([Map<String, String>? env]) {
  final e = env ?? io.Platform.environment;
  for (final name in kCiEnvVars) {
    final v = e[name];
    if (v != null && v.isNotEmpty && v != '0' && v.toLowerCase() != 'false') {
      return true;
    }
  }
  return false;
}

/// Parses cgroup v2 `cpu.max` content (`"max 100000"` or `"200000 100000"`)
/// into a CPU count, or null when unlimited/unparseable. Fractional quotas
/// round UP (a 1.5-CPU quota can usefully run 2 threads).
int? parseCgroupCpuMax(String content) {
  final parts = content.trim().split(RegExp(r'\s+'));
  if (parts.length < 2 || parts[0] == 'max') return null;
  final quota = int.tryParse(parts[0]);
  final period = int.tryParse(parts[1]);
  if (quota == null || period == null || quota <= 0 || period <= 0) {
    return null;
  }
  return (quota / period).ceil();
}

/// Parses cgroup v1 quota/period files into a CPU count, or null.
int? parseCgroupV1Cpu(String quotaText, String periodText) {
  final quota = int.tryParse(quotaText.trim());
  final period = int.tryParse(periodText.trim());
  if (quota == null || period == null || quota <= 0 || period <= 0) {
    return null;
  }
  return (quota / period).ceil();
}

/// Parses a cgroup memory limit file; `max` or absurdly large values (the
/// "unlimited" sentinel is near 2^63) mean no limit → null.
int? parseCgroupMemoryBytes(String content) {
  final text = content.trim();
  if (text == 'max') return null;
  final v = int.tryParse(text);
  if (v == null || v <= 0) return null;
  // cgroup v1 reports ~9.2e18 for "no limit"; treat anything above 1 PB as such.
  if (v > (1 << 50)) return null;
  return v;
}

String? _readText(String path) {
  try {
    return io.File(path).readAsStringSync();
  } on Object {
    return null;
  }
}

/// Reads the host memory figures from `/proc/meminfo` (Linux). Returns
/// (availableMb, totalMb) with nulls for what could not be read.
(int?, int?) _readProcMeminfo() {
  final text = _readText('/proc/meminfo');
  if (text == null) return (null, null);
  int? kb(String key) {
    final m = RegExp(
      '^$key:\\s+(\\d+)\\s+kB',
      multiLine: true,
    ).firstMatch(text);
    return m == null ? null : int.parse(m.group(1)!);
  }

  final avail = kb('MemAvailable');
  final total = kb('MemTotal');
  return (
    avail == null ? null : avail ~/ 1024,
    total == null ? null : total ~/ 1024,
  );
}

/// Cheap, repeatable availability sample (safe to call every second): Linux
/// reads `/proc` and cgroup files; other platforms return null (the watchdog
/// then relies on process RSS alone).
int? readAvailableMemoryMb() {
  try {
    if (!io.Platform.isLinux) return null;
    var (avail, _) = _readProcMeminfo();
    // Container limit: the usable figure is limit minus current usage.
    final limitV2 = _readText('/sys/fs/cgroup/memory.max');
    final limitV1 = _readText('/sys/fs/cgroup/memory/memory.limit_in_bytes');
    final usageV2 = _readText('/sys/fs/cgroup/memory.current');
    final usageV1 = _readText('/sys/fs/cgroup/memory/memory.usage_in_bytes');
    final limit = parseCgroupMemoryBytes(limitV2 ?? limitV1 ?? 'max');
    final usageText = usageV2 ?? usageV1;
    final usage = usageText == null ? null : int.tryParse(usageText.trim());
    if (limit != null && usage != null) {
      final cgAvail = (limit - usage) ~/ (1024 * 1024);
      if (avail == null || cgAvail < avail) avail = cgAvail;
    }
    return avail;
  } on Object {
    return null;
  }
}

/// Detects the machine's capacity. Reads cgroup limits on Linux so containers
/// are sized by their quota, not the host.
MachineInfo detectMachine({Map<String, String>? env}) {
  var cores = io.Platform.numberOfProcessors;
  var cpuContainer = false;
  var memContainer = false;
  int? total;
  int? available;
  try {
    if (io.Platform.isLinux) {
      final cpuV2 = _readText('/sys/fs/cgroup/cpu.max');
      final quotaV1 = _readText('/sys/fs/cgroup/cpu/cpu.cfs_quota_us');
      final periodV1 = _readText('/sys/fs/cgroup/cpu/cpu.cfs_period_us');
      final limit = cpuV2 != null
          ? parseCgroupCpuMax(cpuV2)
          : (quotaV1 != null && periodV1 != null
                ? parseCgroupV1Cpu(quotaV1, periodV1)
                : null);
      if (limit != null && limit < cores) {
        cores = limit;
        cpuContainer = true;
      }
      var (_, hostTotal) = _readProcMeminfo();
      final limitMem = parseCgroupMemoryBytes(
        _readText('/sys/fs/cgroup/memory.max') ??
            _readText('/sys/fs/cgroup/memory/memory.limit_in_bytes') ??
            'max',
      );
      if (limitMem != null) {
        final limitMb = limitMem ~/ (1024 * 1024);
        if (hostTotal == null || limitMb < hostTotal) {
          hostTotal = limitMb;
          memContainer = true;
        }
      }
      total = hostTotal;
      available = readAvailableMemoryMb();
    }
  } on Object {
    // Detection is best-effort; fall through with what was gathered.
  }
  return MachineInfo(
    cores: cores < 1 ? 1 : cores,
    availableMemoryMb: available,
    totalMemoryMb: total,
    isCi: detectCi(env),
    cpuLimitedByContainer: cpuContainer,
    memoryLimitedByContainer: memContainer,
  );
}
