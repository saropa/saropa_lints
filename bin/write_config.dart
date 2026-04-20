#!/usr/bin/env dart

/// Headless config writer for the VS Code extension and CI.
///
/// Usage: `dart run saropa_lints:write_config --tier <tier> [--target <dir>] [options]`
///
/// Writes analysis_options.yaml from tier + analysis_options_custom.yaml.
/// No interactive prompts or terminal output (except errors).
library;

import 'dart:io';

import 'package:saropa_lints/src/init/write_config_runner.dart';

void main(List<String> args) {
  String? tier;
  String? targetDir;
  bool stylisticAll = false;
  bool reset = false;
  String outputPath = 'analysis_options.yaml';

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--tier':
      case '-t':
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          tier = args[++i];
        }
        break;
      case '--target':
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          targetDir = args[++i];
        }
        break;
      case '--stylistic-all':
        stylisticAll = true;
        break;
      case '--reset':
        reset = true;
        break;
      case '--output':
      case '-o':
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          outputPath = args[++i];
        }
        break;
      case '--help':
      case '-h':
        _printUsage();
        exit(0);
    }
  }

  if (tier == null || tier.isEmpty) {
    stderr.writeln('Error: --tier is required.');
    _printUsage();
    exit(1);
  }

  final dir = targetDir != null
      ? Directory(targetDir).absolute.path
      : Directory.current.path;

  final result = runWriteConfig(WriteConfigOptions(
    targetDir: dir,
    tier: tier,
    stylisticAll: stylisticAll,
    reset: reset,
    outputPath: outputPath,
  ));

  if (!result.ok) {
    // Default nullable error to a descriptive placeholder (avoid_nullable_interpolation).
    stderr.writeln('write_config: ${result.error ?? 'unknown error'}');
    exit(2);
  }
}

void _printUsage() {
  stdout.writeln('Usage: dart run saropa_lints:write_config --tier <tier> [options]');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln('  --tier, -t <name>   Tier: essential, recommended, professional, comprehensive, pedantic');
  stdout.writeln('  --target <path>    Project directory (default: current)');
  stdout.writeln('  --stylistic-all    Enable all stylistic rules');
  stdout.writeln('  --reset            Do not preserve user customizations from existing analysis_options.yaml');
  stdout.writeln('  --output, -o <file> Output path (default: analysis_options.yaml)');
  stdout.writeln('  --help, -h          Show this help');
}
