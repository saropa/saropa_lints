#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Dart CLI tool to summarize the analysis server's RSS trend from
/// `plugin.log`.
///
/// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
/// and tiers in `lib/src/tiers.dart` where applicable.
library;

// CLI tool to summarize the analysis server's RSS trend from `plugin.log`.
//
// Usage:
//   dart run saropa_lints:memory_report [path]
//   dart run saropa_lints:memory_report --help
//
// `MemoryPressureHandler` (project_context_throttle_memory.dart) writes a
// `[memory] RSS <n>MB (cap <n>MB)` line to `reports/.saropa_lints/plugin.log`
// roughly every 30s while the in-process analyzer plugin is running. This
// tool is a separate, short-lived process — it has no access to the live
// analysis server's memory — so it can only read that log file after the
// fact. This is Phase 0 of the memory-monitor plan in
// `plans/PLAN_analyzer_memory_monitor.md`: it gives post-crash
// visibility into the RSS trend, but does NOT implement that plan's
// warning threshold (Phase 1), rule shedding (Phase 3), or status-bar
// integration (Phase 4), none of which exist yet.
//
// `plugin.log` is size-capped and rotated (PluginLogger._rotateIfNeeded);
// when that happens mid-session, this tool prints a CAVEAT rather than
// silently reporting a min/max that omits the discarded history.

import 'dart:io';

/// Matches a periodic memory trend line written by `PluginLogger.log`, e.g.
/// `2026-08-28T04:12:33.123Z | [memory] RSS 4200MB (cap 6144MB)`.
final _memoryLinePattern = RegExp(
  r'^(?<timestamp>\S+) \| \[memory\] RSS (?<rss>\d+)MB \(cap (?<cap>\d+)MB\)$',
);

/// Matches the marker `PluginLogger._rotateIfNeeded` writes after truncating
/// `plugin.log` for size. Its presence means some history before this
/// timestamp was discarded, so this report's min/max cannot be trusted as
/// the full session's — only the retained window's.
final _rotationMarkerPattern = RegExp(r'^(?<timestamp>\S+) \| \[log-rotated\]');

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();

    return;
  }

  final projectRoot = args.isNotEmpty ? args.first : '.';
  final sep = Platform.pathSeparator;
  final logFile = File(
    '$projectRoot${sep}reports$sep.saropa_lints${sep}plugin.log',
  );

  if (!logFile.existsSync()) {
    print('No plugin.log found at ${logFile.path}');
    print(
      'The in-process analyzer plugin has not run yet, or memory trend '
      'logging has not reached its first 30s tick.',
    );

    return;
  }

  final samples = <_MemorySample>[];
  String? lastRotationTimestamp;
  for (final line in logFile.readAsLinesSync()) {
    final memoryMatch = _memoryLinePattern.firstMatch(line);
    if (memoryMatch != null) {
      samples.add(
        _MemorySample(
          timestamp: memoryMatch.namedGroup('timestamp')!,
          rssMb: int.parse(memoryMatch.namedGroup('rss')!),
          capMb: int.parse(memoryMatch.namedGroup('cap')!),
        ),
      );
      continue;
    }
    final rotationMatch = _rotationMarkerPattern.firstMatch(line);
    if (rotationMatch != null) {
      // Log-rotate can fire more than once across a long session — only the
      // most recent cut matters, since it discarded everything before it.
      lastRotationTimestamp = rotationMatch.namedGroup('timestamp');
    }
  }

  if (samples.isEmpty) {
    print('No memory trend lines found in ${logFile.path}');

    return;
  }

  final rssValues = samples.map((s) => s.rssMb);
  final minRss = rssValues.reduce((a, b) => a < b ? a : b);
  final maxRss = rssValues.reduce((a, b) => a > b ? a : b);
  final first = samples.first;
  final last = samples.last;

  // ASCII-only output: Windows console codepages (cp1252/cp437) can mangle
  // non-ASCII punctuation like em-dashes when stdout isn't UTF-8, corrupting
  // this tool's own output on the platform it's most likely to run on.
  print('Memory trend report - ${logFile.path}');
  print('');
  print('Samples: ${samples.length}');
  print('First:   ${first.timestamp} - ${first.rssMb}MB (cap ${first.capMb}MB)');
  print('Latest:  ${last.timestamp} - ${last.rssMb}MB (cap ${last.capMb}MB)');
  print('Min RSS: ${minRss}MB');
  print('Max RSS: ${maxRss}MB');
  if (last.capMb > 0) {
    final pctOfCap = (last.rssMb / last.capMb * 100).round();
    print('Latest is $pctOfCap% of the configured cap.');
  }
  if (lastRotationTimestamp != null) {
    print('');
    print(
      'CAVEAT: plugin.log was rotated at $lastRotationTimestamp — earlier '
      'entries were discarded to keep the file under its size cap. Min/Max '
      'above reflect only the retained window, not the full session.',
    );
  }
}

void _printUsage() {
  print('saropa_lints memory_report - summarize analysis server RSS trend');
  print('');
  print('Usage: dart run saropa_lints:memory_report [path]');
  print('');
  print(
    'Reads reports/.saropa_lints/plugin.log under [path] (default: current\n'
    'directory) and summarizes the RSS trend logged by the in-process\n'
    'analyzer plugin. Requires the plugin to have been active — the VS Code\n'
    'extension\'s out-of-process scan-on-save does not write this log.',
  );
  print('');
  print('Options:');
  print('  -h, --help      Show this help message');
}

/// One parsed `[memory]` trend line from `plugin.log`.
class _MemorySample {
  _MemorySample({required this.timestamp, required this.rssMb, required this.capMb});

  final String timestamp;
  final int rssMb;
  final int capMb;
}
