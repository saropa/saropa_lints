// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Result shape for cross-file analysis (unused files, circular deps,
/// missing mirror tests, stats).
class CrossFileResult {
  const CrossFileResult({
    required this.unusedFiles,
    required this.circularDependencies,
    required this.missingMirrorTests,
    required this.stats,
    this.includedPaths = const {},
  });

  final List<String> unusedFiles;
  final List<List<String>> circularDependencies;

  /// `lib/foo/bar.dart` with no `test/foo/bar_test.dart` at the project root.
  final List<String> missingMirrorTests;

  final Map<String, dynamic> stats;

  /// All file paths that survived exclude filtering. Empty when no excludes
  /// were applied (callers should fall back to the full graph in that case).
  final Set<String> includedPaths;
}

/// Formats cross-file analysis results as text or JSON.
///
/// Usage:
/// ```dart
/// CrossFileReporter.report(result, format: 'text', sink: stdout);
/// CrossFileReporter.report(result, format: 'json', sink: stdout);
/// ```
class CrossFileReporter {
  CrossFileReporter._();

  /// Output format: `text` (default) or `json`.
  /// [sink] defaults to [stdout] when null.
  static void report(
    CrossFileResult result, {
    String format = 'text',
    StringSink? sink,
  }) {
    final out = sink ?? stdout;
    switch (format) {
      case 'json':
        _reportJson(result, out);
        break;
      case 'text':
      default:
        _reportText(result, out);
    }
  }

  static void _reportText(CrossFileResult result, StringSink sink) {
    final u = result.unusedFiles;
    sink.writeln('Unused Files (${u.length} found):');
    if (u.isEmpty) {
      sink.writeln('  (none)');
    } else {
      for (final f in u) {
        sink.writeln('  $f');
      }
    }
    sink.writeln('');

    final m = result.missingMirrorTests;
    sink.writeln('Lib sources without mirror test (${m.length} found):');
    if (m.isEmpty) {
      sink.writeln('  (none)');
    } else {
      for (final f in m) {
        sink.writeln('  $f');
      }
    }
    sink.writeln('');

    final c = result.circularDependencies;
    sink.writeln('Circular Dependencies (${c.length} found):');
    if (c.isEmpty) {
      sink.writeln('  (none)');
    } else {
      for (final cycle in c) {
        sink.writeln('  ${cycle.join(' -> ')}');
      }
    }
    sink.writeln('');

    if (result.stats.isNotEmpty) {
      sink.writeln('Import graph stats:');
      sink.writeln('  fileCount: ${result.stats['fileCount'] ?? 0}');
      sink.writeln('  totalImports: ${result.stats['totalImports'] ?? 0}');
    }
  }

  static void _reportJson(CrossFileResult result, StringSink sink) {
    final map = <String, dynamic>{
      'unusedFiles': result.unusedFiles,
      'circularDependencies': result.circularDependencies,
      'missingMirrorTests': result.missingMirrorTests,
      if (result.stats.isNotEmpty) 'stats': result.stats,
    };
    sink.writeln(const JsonEncoder.withIndent('  ').convert(map));
  }
}
