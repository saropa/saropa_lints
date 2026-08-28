#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Dart CLI entrypoint for saropa_lints tooling.
///
/// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
/// and tiers in `lib/src/tiers.dart` where applicable; see `plans/COMMENT_COVERAGE_PLAN.md`.

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
// fact. This is the minimal slice of the "memory monitor" proposal in
// `bugs/proposal_infra_analyzer_memory_monitor.md`: it gives post-crash
// visibility into the RSS trend, but does NOT implement the proposal's
// warning threshold, rule shedding, or status-bar integration, none of
// which exist yet.
library;

import 'dart:io';

/// Matches a periodic memory trend line written by `PluginLogger.log`, e.g.
/// `2026-08-28T04:12:33.123Z | [memory] RSS 4200MB (cap 6144MB)`.
final _memoryLinePattern = RegExp(
  r'^(?<timestamp>\S+) \| \[memory\] RSS (?<rss>\d+)MB \(cap (?<cap>\d+)MB\)$',
);

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
  for (final line in logFile.readAsLinesSync()) {
    final match = _memoryLinePattern.firstMatch(line);
    if (match == null) continue;
    samples.add(
      _MemorySample(
        timestamp: match.namedGroup('timestamp')!,
        rssMb: int.parse(match.namedGroup('rss')!),
        capMb: int.parse(match.namedGroup('cap')!),
      ),
    );
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
