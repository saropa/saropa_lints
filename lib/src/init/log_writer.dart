/// Logging infrastructure for the init tool.
///
/// Captures terminal output in a buffer for writing to a timestamped report
/// file. Also provides report-file management (migration, lookup).
library;

import 'dart:developer' as dev;
import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/report/analysis_reporter.dart'
    show AnalysisReporter;

// ---------------------------------------------------------------------------
// Run summary
// ---------------------------------------------------------------------------

/// Summary data written to the tail of the log file.
typedef RunSummary = ({
  String version,
  String tier,
  int enabled,
  int disabled,
  String outputPath,
});

// ---------------------------------------------------------------------------
// LogWriter
// ---------------------------------------------------------------------------

/// Centralized logging for the init tool.
///
/// Captures every `terminal()` call in [buffer] so the full session can be
/// written to a report file via [writeFile].
class LogWriter {
  /// Buffer collecting all log output for the report file.
  final StringBuffer buffer = StringBuffer();

  /// Timestamp string (`YYYYMMDD_HHMMSS`) used for log-file naming.
  String? timestamp;

  /// Warnings collected during the run — printed in the log summary.
  final List<String> warnings = <String>[];

  /// Print [message] to the terminal and record it in [buffer].
  void terminal(String message) {
    // ignore: avoid_print
    print(message);
    buffer.writeln(message);
  }

  /// Log a validation-check result to both terminal and [buffer].
  void check(String label, {required bool pass, String? detail}) {
    final tag = pass
        ? '${InitColors.green}[PASS]${InitColors.reset}'
        : '${InitColors.yellow}[WARN]${InitColors.reset}';
    final msg = detail != null ? '$tag $label — $detail' : '$tag $label';
    terminal(msg);

    if (!pass) {
      warnings.add(detail != null ? '$label — $detail' : label);
    }
  }

  /// Print a labeled code example with multi-line support.
  ///
  /// Splits [exampleText] on `\n`. The first line is prefixed with a colored
  /// label; continuation lines are indented to align under the code content.
  void example(
    String label,
    String colorCode,
    String exampleText, {
    int indent = 2,
  }) {
    final lines = exampleText.split('\n');
    final padded = label.padRight(4);
    final spaces = ' ' * indent;
    terminal(
      '$spaces${InitColors.bold}$colorCode$padded:${InitColors.reset} '
      '${lines[0]}',
    );
    if (lines.length > 1) {
      final contIndent = ' ' * (indent + padded.length + 2);
      for (int i = 1; i < lines.length; i++) {
        terminal('$contIndent${lines[i]}');
      }
    }
  }

  /// Append a final summary block to [buffer].
  ///
  /// Called just before [writeFile] so the summary is the last section in
  /// the report, after any analysis output.
  void appendSummary(RunSummary s) {
    buffer.writeln('');
    buffer.writeln('${'=' * 80}');
    buffer.writeln('SUMMARY');
    buffer.writeln('${'=' * 80}');
    buffer.writeln('Version:  ${s.version}');
    buffer.writeln('Tier:     ${s.tier}');
    buffer.writeln('Enabled:  ${s.enabled} rules');
    buffer.writeln('Disabled: ${s.disabled} rules');
    buffer.writeln('Output:   ${s.outputPath}');

    if (warnings.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Warnings (${warnings.length}):');
      for (final w in warnings) {
        buffer.writeln('  - $w');
      }
    } else {
      buffer.writeln('Warnings: none');
    }
    buffer.writeln('${'=' * 80}');
  }

  /// Write [buffer] to a timestamped report file.
  void writeFile() {
    final logTimestamp = timestamp;
    if (logTimestamp == null) return;

    try {
      final dateFolder = AnalysisReporter.dateFolder(logTimestamp);
      final reportsDir = Directory('reports/$dateFolder');
      if (!reportsDir.existsSync()) {
        reportsDir.createSync(recursive: true);
      }

      final logPath =
          'reports/$dateFolder/${logTimestamp}_saropa_lints_init.log';
      final logContent = stripAnsi(buffer.toString());
      File(logPath).writeAsStringSync(logContent);

      // ignore: avoid_print
      print(
        '${InitColors.bold}Log:${InitColors.reset} '
        '${InitColors.cyan}$logPath${InitColors.reset}',
      );
    } on Exception catch (e, st) {
      dev.log('Could not write log file', error: e, stackTrace: st);
      // ignore: avoid_print
      print(
        '${InitColors.yellow}Warning: Could not write log file: '
        '$e${InitColors.reset}',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Standalone helpers
// ---------------------------------------------------------------------------

/// Strip ANSI escape codes from text for plain-text log files.
String stripAnsi(String text) {
  return text.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
}

/// Migrate old report files from `reports/` root into date subfolders.
///
/// Files matching `YYYYMMDD_HHMMSS_*.log` in `reports/` are moved to
/// `reports/YYYYMMDD/`. Runs silently if nothing to migrate.
void migrateOldReports() {
  try {
    final reportsDir = Directory('reports');
    if (!reportsDir.existsSync()) return;

    final pattern = RegExp(r'^\d{8}_\d{6}_.*\.log$');
    final toMigrate = reportsDir.listSync().whereType<File>().where((f) {
      final name = f.path.split('/').last.split('\\').last;
      return pattern.hasMatch(name);
    }).toList();

    if (toMigrate.isEmpty) return;

    for (final file in toMigrate) {
      final name = file.path.split('/').last.split('\\').last;
      final df = AnalysisReporter.dateFolder(name);
      final targetDir = Directory('reports/$df');
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      file.renameSync('${targetDir.path}${Platform.pathSeparator}$name');
    }

    final n = toMigrate.length;
    // ignore: avoid_print
    print(
      '${InitColors.dim}Migrated $n old report${n == 1 ? '' : 's'}'
      ' to date subfolders${InitColors.reset}',
    );
  } catch (e) {
    // ignore: avoid_print
    print(
      '${InitColors.yellow}Warning: Could not migrate old reports: '
      '$e${InitColors.reset}',
    );
  }
}

/// Find the newest plugin lint report in the given date subfolder.
///
/// The plugin writes its report asynchronously via a debounce timer, so the
/// file may not exist immediately after `dart analyze` exits. Retries up to
/// [maxAttempts] times with a short delay.
///
/// Returns the relative path or `null` if no report was found.
Future<String?> findNewestPluginReport(
  String dateFolderName, {
  int maxAttempts = 20,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      final dir = Directory('reports/$dateFolderName');
      if (!dir.existsSync()) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      }

      final reports = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_saropa_lint_report.log'))
          .toList()
        // Filenames start with YYYYMMDD_HHMMSS — lexicographic = newest first
        ..sort((a, b) => b.path.compareTo(a.path));

      if (reports.isNotEmpty) {
        final name = reports.first.path.split('/').last.split('\\').last;
        return 'reports/$dateFolderName/$name';
      }
    } catch (e, st) {
      dev.log(
        'Non-critical: listing report files failed',
        error: e,
        stackTrace: st,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  return null;
}

/// Returns a bracketed note explaining why a rule has a non-default state.
String detailNote(
  String rule,
  Map<String, bool> customs,
  Set<String> platform,
  Set<String> package,
) {
  if (customs.containsKey(rule)) return '  [custom override]';

  if (platform.contains(rule)) return '  [platform filtered]';

  if (package.contains(rule)) return '  [package filtered]';
  return '';
}

/// Shared log writer instance for the init tool session.
final LogWriter log = LogWriter();
