#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Unified CLI for saropa_lints tools.
///
/// Usage:
///   dart run saropa_lints <command> [options]
///
/// Commands:
///   init            Generate analysis_options.yaml with explicit rule config
///   baseline        Generate and manage baseline files for existing violations
///   impact-report   Run lint analysis and display results by impact level
///
/// Examples:
///   dart run saropa_lints init --tier comprehensive
///   dart run saropa_lints baseline --update
///   dart run saropa_lints impact-report
///   dart run saropa_lints --help
library;

import 'baseline.dart' as baseline_cmd;
import 'impact_report.dart' as impact_cmd;
import 'init.dart' as init_cmd;

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    _printUsage();
    return;
  }

  final command = args.first;
  final commandArgs = args.sublist(1);

  switch (command) {
    case 'init':
      await init_cmd.main(commandArgs);
    case 'baseline':
      await baseline_cmd.main(commandArgs);
    case 'impact-report' || 'impact_report':
      await impact_cmd.main(commandArgs);
    default:
      print('Unknown command: $command');
      print('');
      _printUsage();
  }
}

void _printUsage() {
  print('saropa_lints - CLI tools for saropa_lints');
  print('');
  print('Usage: dart run saropa_lints <command> [options]');
  print('');
  print('Commands:');
  print('  init            Generate analysis_options.yaml with rule config');
  print('  baseline        Generate/manage baseline for existing violations');
  print('  impact-report   Run analysis and show results by impact level');
  print('');
  print('Options:');
  print('  -h, --help      Show this help message');
  print('');
  print(
      'Run "dart run saropa_lints <command> --help" for command-specific help.');
  print('');
  print('Examples:');
  print('  dart run saropa_lints init --tier comprehensive');
  print('  dart run saropa_lints init --tier essential --reset');
  print('  dart run saropa_lints baseline');
  print('  dart run saropa_lints baseline --update');
  print('  dart run saropa_lints impact-report');
}
