import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_analyzer.dart';

Future<void> main(List<String> args) async {
  var fileCount = 1000;
  var iterations = 3;
  var outputJson = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--files' && i + 1 < args.length) {
      fileCount = int.tryParse(args[++i]) ?? fileCount;
    } else if (arg == '--iterations' && i + 1 < args.length) {
      iterations = int.tryParse(args[++i]) ?? iterations;
    } else if (arg == '--json') {
      outputJson = true;
    } else if (arg == '--help' || arg == '-h') {
      _printUsage();
      return;
    }
  }

  if (fileCount < 50) fileCount = 50;
  if (iterations < 1) iterations = 1;

  final tempRoot = await Directory.systemTemp.createTemp(
    'saropa_cross_file_benchmark_',
  );
  try {
    final projectDir = Directory(p.join(tempRoot.path, 'project'));
    final libDir = Directory(p.join(projectDir.path, 'lib'));
    await libDir.create(recursive: true);
    await _seedBenchmarkFiles(libDir.path, fileCount);

    final durationsMs = <int>[];
    for (var i = 0; i < iterations; i++) {
      final sw = Stopwatch()..start();
      await runCrossFileAnalysis(projectPath: projectDir.path);
      sw.stop();
      durationsMs.add(sw.elapsedMilliseconds);
    }

    final totalMs = durationsMs.fold<int>(0, (sum, ms) => sum + ms);
    final avgMs = totalMs ~/ durationsMs.length;
    final sorted = [...durationsMs]..sort();
    final medianMs = sorted[sorted.length ~/ 2];
    final maxMs = sorted.isEmpty ? 0 : sorted.last;
    final minMs = sorted.isEmpty ? 0 : sorted.first;

    final summary = <String, Object>{
      'fileCount': fileCount,
      'iterations': iterations,
      'durationsMs': durationsMs,
      'avgMs': avgMs,
      'medianMs': medianMs,
      'minMs': minMs,
      'maxMs': maxMs,
    };

    if (outputJson) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));
      return;
    }

    stdout.writeln('Cross-file benchmark summary');
    stdout.writeln('  files: $fileCount');
    stdout.writeln('  iterations: $iterations');
    stdout.writeln('  durations (ms): ${durationsMs.join(', ')}');
    stdout.writeln('  avg: $avgMs ms');
    stdout.writeln('  median: $medianMs ms');
    stdout.writeln('  min/max: $minMs / $maxMs ms');
  } finally {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

Future<void> _seedBenchmarkFiles(String libPath, int fileCount) async {
  for (var i = 0; i < fileCount; i++) {
    final next = i + 1;
    final imports = <String>[];
    if (next < fileCount) imports.add("import 'f$next.dart';");
    if (next + 1 < fileCount) imports.add("import 'f${next + 1}.dart';");
    final content = StringBuffer();
    for (final imp in imports) {
      content.writeln(imp);
    }
    content.writeln('');
    content.writeln('String f$i() => \'$i\';');
    await File(p.join(libPath, 'f$i.dart')).writeAsString(content.toString());
  }
}

void _printUsage() {
  stdout.writeln('''
Cross-file benchmark harness.

Usage: dart run tool/cross_file_benchmark.dart [options]

Options:
  --files <n>       Number of synthetic Dart files (default: 1000)
  --iterations <n>  Number of benchmark runs (default: 3)
  --json            Print JSON output
  -h, --help        Show this help
''');
}
