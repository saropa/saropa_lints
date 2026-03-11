#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Standalone lint scanner that runs saropa_lints rules against any Dart
/// project without requiring it as a dependency.
///
/// Usage:
///   dart run saropa_lints scan [path] [--tier essential|recommended|...]
///   dart run saropa_lints:scan [path] [--tier essential]
///
/// Exit codes:
///   0 - No issues found
///   1 - Issues found
///   2 - Invalid arguments

import 'dart:io';

import 'package:saropa_lints/src/scan/scan_diagnostic.dart';
import 'package:saropa_lints/src/scan/scan_runner.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final tier = _parseTier(args);
  final path = _parsePath(args);

  final runner = ScanRunner(tier: tier, targetPath: path);
  final diagnostics = runner.run();

  if (diagnostics.isEmpty) {
    print('No issues found.');
    exit(0);
  }

  final byFile = <String, List<ScanDiagnostic>>{};
  for (final d in diagnostics) {
    byFile.putIfAbsent(d.filePath, () => []).add(d);
  }

  for (final entry in byFile.entries) {
    print(entry.key);
    for (final d in entry.value) {
      print('    $d');
    }
    print('');
  }

  print('${diagnostics.length} issue(s) found.');
  exit(1);
}

String _parseTier(List<String> args) {
  final idx = args.indexOf('--tier');
  if (idx >= 0 && idx + 1 < args.length) return args[idx + 1];
  return 'essential';
}

String _parsePath(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    // Skip --tier and its value
    if (arg == '--tier') {
      i++;
      continue;
    }
    if (!arg.startsWith('--') && arg != 'scan') return arg;
  }
  return '.';
}

void _printUsage() {
  print('saropa_lints scan - Standalone lint scanner');
  print('');
  print('Usage: dart run saropa_lints scan [path] [options]');
  print('');
  print('Options:');
  print('  --tier <name>  Tier to use (default: essential)');
  print('                 Values: essential, recommended, professional,');
  print('                         comprehensive, pedantic');
  print('  -h, --help     Show this help');
  print('');
  print('Examples:');
  print('  dart run saropa_lints scan .');
  print('  dart run saropa_lints scan /path/to/project --tier recommended');
  print('  dart run saropa_lints:scan . --tier professional');
}
