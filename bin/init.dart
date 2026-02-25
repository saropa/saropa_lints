#!/usr/bin/env dart
// ignore_for_file: avoid_print

library;

/// CLI tool to generate analysis_options.yaml with explicit rule configuration.
///
/// ## Purpose
///
/// The native analyzer plugin system requires lint rules to be explicitly
/// enabled in the `diagnostics:` section. This tool generates the full
/// `plugins: saropa_lints: diagnostics:` configuration with explicit
/// `rule_name: true/false` entries for ALL saropa_lints rules.
///
/// ## Usage
///
/// ```bash
/// dart run saropa_lints:init [options]
/// ```
///
/// ## Options
///
/// | Option | Description | Default |
/// |--------|-------------|---------|
/// | `-t, --tier <tier>` | Tier level (1-5 or name) | prompt (or comprehensive) |
/// | `-o, --output <file>` | Output file path | analysis_options.yaml |
/// | `--stylistic` | Interactive stylistic rules walkthrough | default |
/// | `--stylistic-all` | Bulk-enable all stylistic rules (CI) | false |
/// | `--no-stylistic` | Skip stylistic walkthrough entirely | false |
/// | `--reset-stylistic` | Clear reviewed markers, re-walkthrough | false |
/// | `--reset` | Discard user customizations | false |
/// | `--dry-run` | Preview output without writing | false |
/// | `-h, --help` | Show help message | - |
///
/// ## Tiers
///
/// 1. **essential** - Critical rules (~340): crashes, security, memory leaks
/// 2. **recommended** - Essential + accessibility, performance (~850)
/// 3. **professional** - Recommended + architecture, testing (~1590)
/// 4. **comprehensive** - Professional + thorough coverage (~1640)
/// 5. **pedantic** - All rules enabled (~1650)
///
/// ## Preservation Behavior
///
/// When regenerating an existing file, this tool preserves:
/// - All non-plugins sections (analyzer, linter, formatter, etc.)
/// - User customizations in plugins.saropa_lints.diagnostics (unless --reset)
///
/// User customizations appear first in the generated output, making it easy
/// to see which rules have been manually configured.
///
/// ## Exit Codes
///
/// - 0: Success
/// - 1: Invalid tier specified
/// - 2: File write error
///
/// ## Examples
///
/// ```bash
/// # Interactive tier selection (prompts if no --tier given)
/// dart run saropa_lints:init
///
/// # Start with essential tier for legacy projects
/// dart run saropa_lints:init --tier essential
///
/// # Bulk-enable all stylistic rules (for CI)
/// dart run saropa_lints:init --tier professional --stylistic-all
///
/// # Skip the interactive stylistic walkthrough
/// dart run saropa_lints:init --no-stylistic
///
/// # Preview without writing
/// dart run saropa_lints:init --dry-run
///
/// # Reset to tier defaults, discarding customizations
/// dart run saropa_lints:init --tier recommended --reset
/// ```
///
/// ## See Also
///
/// - [README.md](../README.md) for tier philosophy and adoption strategy
/// - [PERFORMANCE.md](../PERFORMANCE.md) for performance considerations
/// - [CONTRIBUTING.md](../CONTRIBUTING.md) for adding new rules

import 'dart:convert' show utf8;
import 'dart:ffi';
import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart'
    show RuleTier, SaropaLintRule, allSaropaRules;
import 'package:saropa_lints/src/report/analysis_reporter.dart'
    show AnalysisReporter;
import 'package:saropa_lints/src/tiers.dart' as tiers;

import 'whats_new.dart' show AnsiColors, formatWhatsNew;

/// Get saropa_lints rootUri from .dart_tool/package_config.json.
/// Returns null if not found. Used by both version and source detection.
String? _getSaropaLintsRootUri() {
  try {
    final packageConfigFile = File('.dart_tool/package_config.json');
    if (!packageConfigFile.existsSync()) return null;

    final content = packageConfigFile.readAsStringSync();
    final match = RegExp(
      r'"name":\s*"saropa_lints"[^}]*"rootUri":\s*"([^"]+)"',
    ).firstMatch(content);

    return match?.group(1);
  } catch (_) {}

  return null;
}

/// Convert rootUri to absolute file path.
String? _rootUriToPath(String rootUri) {
  if (rootUri.startsWith('file://')) {
    return Uri.parse(rootUri).toFilePath();
  } else if (rootUri.startsWith('../')) {
    final dartToolDir = Directory('.dart_tool').absolute.path;
    return Directory('$dartToolDir/$rootUri').absolute.path;
  }

  return null;
}

/// Detect which packages the host project uses from its pubspec.yaml.
///
/// Reads the project's pubspec.yaml (not the saropa_lints package's),
/// parses dependencies + dev_dependencies, and returns a map of
/// saropa_lints package names to whether they were found.
///
/// Used to auto-filter stylistic rules irrelevant to the project.
Map<String, bool> _detectProjectPackages() {
  // Start with all disabled — only enable what we find
  final detected = <String, bool>{
    for (final pkg in tiers.allPackages) pkg: false,
  };

  try {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) return detected;

    final content = pubspecFile.readAsStringSync();

    // Detect Flutter
    final isFlutter =
        content.contains('flutter:') ||
        content.contains('flutter_test:') ||
        content.contains('sdk: flutter');

    // Parse indented dependency names (under dependencies: or
    // dev_dependencies:)
    final deps = <String>{};
    final depMatches = RegExp(r'^\s+(\w+):').allMatches(content);
    for (final match in depMatches) {
      final dep = match.group(1);
      if (dep != null) deps.add(dep);
    }

    // Map detected deps to saropa_lints package names.
    // Some saropa_lints names differ from pub.dev package names:
    //   saropa name       → pub.dev name(s)
    //   bloc              → bloc, flutter_bloc
    //   getx              → get
    //   flutter_hooks     → flutter_hooks
    //   firebase          → firebase_core, firebase_auth, etc.
    //   qr_scanner        → mobile_scanner, qr_code_scanner
    const Map<String, List<String>> aliases = {
      'bloc': ['bloc', 'flutter_bloc'],
      'getx': ['get', 'getx'],
      'firebase': [
        'firebase_core',
        'firebase_auth',
        'cloud_firestore',
        'firebase_storage',
        'firebase_messaging',
        'firebase_analytics',
      ],
      'qr_scanner': ['mobile_scanner', 'qr_code_scanner'],
    };

    for (final pkg in tiers.allPackages) {
      final pubNames = aliases[pkg] ?? [pkg];
      if (pubNames.any((name) => deps.contains(name))) {
        detected[pkg] = true;
      }
    }

    // If not Flutter, disable Flutter-dependent packages too
    if (!isFlutter) {
      // These packages require Flutter
      for (final pkg in ['flutter_hooks', 'flame']) {
        detected[pkg] = false;
      }
    }

    _logTerminal(
      '${_Colors.dim}Auto-detected packages from pubspec.yaml: '
      '${detected.entries.where((e) => e.value).map((e) => e.key).join(', ')}'
      '${isFlutter ? ' (Flutter project)' : ' (pure Dart)'}${_Colors.reset}',
    );
  } catch (_) {
    // Can't read pubspec — fall back to all enabled
    return Map<String, bool>.of(tiers.defaultPackages);
  }

  return detected;
}

/// Get package version by reading pubspec.yaml from package location.
String _getPackageVersion() {
  try {
    final rootUri = _getSaropaLintsRootUri();
    if (rootUri == null) return 'unknown';

    final packageDir = _rootUriToPath(rootUri);
    if (packageDir == null) return 'unknown';

    final pubspecFile = File('$packageDir/pubspec.yaml');
    if (!pubspecFile.existsSync()) return 'unknown';

    final content = pubspecFile.readAsStringSync();
    final match = RegExp(
      r'^version:\s*(.+)$',
      multiLine: true,
    ).firstMatch(content);
    return match?.group(1)?.trim() ?? 'unknown';
  } catch (_) {}

  return 'unknown';
}

/// Detect where the saropa_lints package is loaded from.
String _getPackageSource() {
  final rootUri = _getSaropaLintsRootUri();

  if (rootUri == null) return 'unknown';

  if (rootUri.startsWith('file://') || rootUri.startsWith('../')) {
    return 'local: $rootUri';
  } else if (rootUri.contains('.pub-cache')) {
    return 'pub.dev';
  }

  return rootUri;
}

// ---------------------------------------------------------------------------
// Log buffer for detailed report file
// ---------------------------------------------------------------------------

/// Buffer to collect all log output for the report file.
final StringBuffer _logBuffer = StringBuffer();

/// Timestamp for log file naming.
String? _logTimestamp;

/// Strip ANSI escape codes from text for plain text log file.
String _stripAnsi(String text) {
  return text.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
}

/// Write the log buffer to a timestamped report file.
void _writeLogFile() {
  if (_logTimestamp == null) return;

  try {
    final dateFolder = AnalysisReporter.dateFolder(_logTimestamp!);
    final reportsDir = Directory('reports/$dateFolder');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }

    final logPath =
        'reports/$dateFolder/${_logTimestamp}_saropa_lints_init.log';
    final logContent = _stripAnsi(_logBuffer.toString());
    File(logPath).writeAsStringSync(logContent);

    print(
      '${_Colors.bold}Log:${_Colors.reset} ${_Colors.cyan}$logPath${_Colors.reset}',
    );
  } on Exception catch (e) {
    print(
      '${_Colors.yellow}Warning: Could not write log file: $e${_Colors.reset}',
    );
  }
}

/// Migrate old report files from `reports/` root into date subfolders.
///
/// Files matching `YYYYMMDD_HHMMSS_*.log` in the `reports/` root are
/// moved to `reports/YYYYMMDD/` based on the first 8 characters of the
/// filename. This is a one-time cleanup for logs created before the
/// date-folder migration. Runs silently if nothing to migrate.
void _migrateOldReports() {
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

    // Use print() not _logTerminal() — migration is operational cleanup,
    // not configuration data for the init log.
    final n = toMigrate.length;
    print(
      '${_Colors.dim}Migrated $n old report${n == 1 ? '' : 's'}'
      ' to date subfolders${_Colors.reset}',
    );
  } catch (e) {
    print(
      '${_Colors.yellow}Warning: Could not migrate old reports: '
      '$e${_Colors.reset}',
    );
  }
}

/// Find the newest plugin lint report in the given date subfolder.
///
/// The plugin's [AnalysisReporter] writes its report asynchronously via a
/// debounce timer, so the file may not exist immediately after `dart analyze`
/// exits. Retries up to [maxAttempts] times with a short delay.
///
/// Returns the relative path (e.g. `reports/20260221/..._report.log`)
/// or null if no report was found.
Future<String?> _findNewestPluginReport(
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

      final reports =
          dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('_saropa_lint_report.log'))
              .toList()
            // Filenames start with YYYYMMDD_HHMMSS so lexicographic = newest first
            ..sort((a, b) => b.path.compareTo(a.path));

      if (reports.isNotEmpty) {
        final name = reports.first.path.split('/').last.split('\\').last;
        return 'reports/$dateFolderName/$name';
      }
    } catch (_) {
      // Non-critical — fall through to retry or return null
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  return null;
}

/// Append a detailed rule-by-rule listing to the log buffer.
///
/// Written to the log file only, not printed to the terminal.
/// Each rule gets one line: `+ SEVERITY  tier  rule_name  [note]`.
void _appendDetailedReport({
  required Set<String> enabledRules,
  required Set<String> disabledRules,
  required Map<String, bool> userCustomizations,
  required Set<String> platformFilteredRules,
  required Set<String> packageFilteredRules,
}) {
  final allRules = [...enabledRules, ...disabledRules]..sort();

  _logBuffer.writeln('');
  _logBuffer.writeln('${'=' * 80}');
  _logBuffer.writeln('DETAILED RULE REPORT (${allRules.length} rules)');
  _logBuffer.writeln('${'=' * 80}');
  _logBuffer.writeln('');

  for (final rule in allRules) {
    final enabled = enabledRules.contains(rule);
    final marker = enabled ? '+' : '-';
    final severity = _getRuleSeverity(rule).padRight(7);
    final tierName = _tierToString(_getRuleTierFromMetadata(rule)).padRight(13);
    final note = _detailNote(
      rule,
      userCustomizations,
      platformFilteredRules,
      packageFilteredRules,
    );
    _logBuffer.writeln('$marker $severity $tierName $rule$note');
  }

  _logBuffer.writeln('');
  _logBuffer.writeln('Legend: + enabled, - disabled');
  _logBuffer.writeln('${'=' * 80}');
}

/// Returns a bracketed note explaining why a rule has a non-default state.
String _detailNote(
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

/// Summary data for the log file.
typedef _RunSummary = ({
  String version,
  String tier,
  int enabled,
  int disabled,
  String outputPath,
});

/// Append a final summary block to the log buffer.
///
/// Called just before [_writeLogFile] so the summary is the last section
/// in the report, after any analysis output.
void _appendLogSummary(_RunSummary s) {
  _logBuffer.writeln('');
  _logBuffer.writeln('${'=' * 80}');
  _logBuffer.writeln('SUMMARY');
  _logBuffer.writeln('${'=' * 80}');
  _logBuffer.writeln('Version:  ${s.version}');
  _logBuffer.writeln('Tier:     ${s.tier}');
  _logBuffer.writeln('Enabled:  ${s.enabled} rules');
  _logBuffer.writeln('Disabled: ${s.disabled} rules');
  _logBuffer.writeln('Output:   ${s.outputPath}');

  if (_warnings.isNotEmpty) {
    _logBuffer.writeln('');
    _logBuffer.writeln('Warnings (${_warnings.length}):');
    for (final w in _warnings) {
      _logBuffer.writeln('  - $w');
    }
  } else {
    _logBuffer.writeln('Warnings: none');
  }
  _logBuffer.writeln('${'=' * 80}');
}

// ---------------------------------------------------------------------------
// Pre-flight validation
// ---------------------------------------------------------------------------

/// Collected warnings during the run (printed in log summary).
final List<String> _warnings = <String>[];

/// Log a validation check result to both terminal and log buffer.
void _logCheck(String label, {required bool pass, String? detail}) {
  final tag = pass
      ? '${_Colors.green}[PASS]${_Colors.reset}'
      : '${_Colors.yellow}[WARN]${_Colors.reset}';
  final msg = detail != null ? '$tag $label — $detail' : '$tag $label';
  _logTerminal(msg);

  if (!pass) {
    _warnings.add(detail != null ? '$label — $detail' : label);
  }
}

/// Run pre-flight checks before generating the configuration.
///
/// All checks are non-fatal (warnings only). Results are logged to both
/// terminal and the log buffer so they appear in the report file.
void _runPreflightChecks({required String version}) {
  _logTerminal('${_Colors.bold}Pre-flight checks${_Colors.reset}');

  _checkPubspecDependency();
  _checkDartSdkVersion();
  _auditExistingConfig(version);

  _logTerminal('');
}

/// Check that pubspec.yaml lists saropa_lints as a dependency.
void _checkPubspecDependency() {
  final pubspec = File('pubspec.yaml');

  if (!pubspec.existsSync()) {
    _logCheck(
      'pubspec.yaml',
      pass: false,
      detail: 'file not found — are you in the project root?',
    );
    return;
  }

  final content = pubspec.readAsStringSync();
  final hasDep = RegExp(
    r'^\s+saropa_lints:',
    multiLine: true,
  ).hasMatch(content);

  if (hasDep) {
    _logCheck('pubspec.yaml contains saropa_lints dependency', pass: true);
  } else {
    _logCheck(
      'pubspec.yaml',
      pass: false,
      detail:
          'saropa_lints not found in dependencies — '
          'add it to dev_dependencies',
    );
  }
}

/// Check that the Dart SDK version supports the plugin system (>= 3.6).
void _checkDartSdkVersion() {
  final versionStr = Platform.version; // e.g. "3.10.0 (stable) ..."
  final match = RegExp(r'^(\d+)\.(\d+)').firstMatch(versionStr);

  if (match == null) {
    _logCheck(
      'Dart SDK version',
      pass: false,
      detail: 'could not parse: $versionStr',
    );
    return;
  }

  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);

  if (major > 3 || (major == 3 && minor >= 6)) {
    _logCheck('Dart SDK $major.$minor (plugin support OK)', pass: true);
  } else {
    _logCheck(
      'Dart SDK version',
      pass: false,
      detail: '$major.$minor detected — native plugins require Dart >= 3.6',
    );
  }
}

/// Audit an existing analysis_options.yaml for common issues.
void _auditExistingConfig(String currentVersion) {
  final configFile = File('analysis_options.yaml');

  if (!configFile.existsSync()) {
    _logCheck('No existing analysis_options.yaml (fresh setup)', pass: true);
    return;
  }

  final content = configFile.readAsStringSync();

  // Check for old custom_lint section (v4 leftover)
  if (RegExp(r'custom_lint:', multiLine: true).hasMatch(content)) {
    _logCheck(
      'Existing config',
      pass: false,
      detail:
          'contains custom_lint: section — '
          'saropa_lints v5 uses native plugins, not custom_lint',
    );
  }

  // Check for plugins section missing version key
  if (RegExp(r'^\s+saropa_lints:', multiLine: true).hasMatch(content) &&
      !RegExp(r'^\s+version:', multiLine: true).hasMatch(content)) {
    _logCheck(
      'Existing config',
      pass: false,
      detail:
          'plugins section missing version: key — '
          'the analyzer will silently ignore the plugin',
    );
  }

  // Check for stale version constraint
  final versionMatch = RegExp(
    r'version:\s*"?\^?([^"\s]+)"?',
    multiLine: true,
  ).firstMatch(content);

  if (versionMatch != null && currentVersion != 'unknown') {
    final existing = versionMatch.group(1)!;
    if (existing != currentVersion && !existing.startsWith(currentVersion)) {
      _logCheck(
        'Existing config',
        pass: false,
        detail:
            'version $existing may be stale (current: $currentVersion) '
            '— re-run "dart run saropa_lints" to update',
      );
    }
  }

  // If none of the config-specific checks above fired, report OK
  if (!_warnings.any((w) => w.startsWith('Existing config'))) {
    _logCheck('Existing analysis_options.yaml looks OK', pass: true);
  }
}

// ---------------------------------------------------------------------------
// Post-write validation
// ---------------------------------------------------------------------------

/// Validate the written configuration file has the critical sections.
///
/// Returns true if all checks pass.
bool _validateWrittenConfig(String filePath, int expectedRuleCount) {
  _logTerminal('');
  _logTerminal('${_Colors.bold}Post-write validation${_Colors.reset}');

  final file = File(filePath);

  if (!file.existsSync()) {
    _logCheck(filePath, pass: false, detail: 'file does not exist');
    return false;
  }

  final content = file.readAsStringSync();
  var allPassed = true;

  // Check plugins: section exists
  if (RegExp(r'^plugins:', multiLine: true).hasMatch(content)) {
    _logCheck('plugins: section present', pass: true);
  } else {
    _logCheck('plugins:', pass: false, detail: 'section missing');
    allPassed = false;
  }

  // Check version: key under saropa_lints
  if (RegExp(r'^\s+version:', multiLine: true).hasMatch(content)) {
    _logCheck('version: key present', pass: true);
  } else {
    _logCheck(
      'version:',
      pass: false,
      detail: 'key missing — analyzer will silently ignore plugin',
    );
    allPassed = false;
  }

  // Check diagnostics: section
  if (RegExp(r'^\s+diagnostics:', multiLine: true).hasMatch(content)) {
    _logCheck('diagnostics: section present', pass: true);
  } else {
    _logCheck('diagnostics:', pass: false, detail: 'section missing');
    allPassed = false;
  }

  // Check rule count (5% tolerance)
  final ruleLines = RegExp(
    r'^\s{6}\w+:\s*(true|false)',
    multiLine: true,
  ).allMatches(content).length;
  final tolerance = (expectedRuleCount * 0.05).ceil();
  final diff = (ruleLines - expectedRuleCount).abs();

  if (diff <= tolerance) {
    _logCheck(
      'Rule count: $ruleLines (expected ~$expectedRuleCount)',
      pass: true,
    );
  } else {
    _logCheck(
      'Rule count',
      pass: false,
      detail: '$ruleLines rules found, expected ~$expectedRuleCount',
    );
    allPassed = false;
  }

  _logTerminal('');
  return allPassed;
}

// ---------------------------------------------------------------------------
// Cross-platform ANSI color support
// ---------------------------------------------------------------------------

/// Enable ANSI virtual terminal processing on Windows 10+.
///
/// Windows supports ANSI escape codes but requires enabling
/// ENABLE_VIRTUAL_TERMINAL_PROCESSING on the console output handle.
/// Dart's [stdout.supportsAnsiEscapes] only checks the flag; this sets it.
void _tryEnableAnsiWindows() {
  if (!Platform.isWindows) return;
  try {
    final k = DynamicLibrary.open('kernel32.dll');
    final getStdHandle = k
        .lookupFunction<IntPtr Function(Int32), int Function(int)>(
          'GetStdHandle',
        );
    final getMode = k
        .lookupFunction<
          Int32 Function(IntPtr, Pointer<Uint32>),
          int Function(int, Pointer<Uint32>)
        >('GetConsoleMode');
    final setMode = k
        .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
          'SetConsoleMode',
        );
    final getHeap = k.lookupFunction<IntPtr Function(), int Function()>(
      'GetProcessHeap',
    );
    final alloc = k
        .lookupFunction<
          Pointer<Void> Function(IntPtr, Uint32, IntPtr),
          Pointer<Void> Function(int, int, int)
        >('HeapAlloc');
    final free = k
        .lookupFunction<
          Int32 Function(IntPtr, Uint32, Pointer<Void>),
          int Function(int, int, Pointer<Void>)
        >('HeapFree');

    final handle = getStdHandle(-11); // STD_OUTPUT_HANDLE
    final heap = getHeap();
    final ptr = alloc(heap, 0x08, 4); // HEAP_ZERO_MEMORY, 4 bytes
    if (ptr.address == 0) return;

    final mode = ptr.cast<Uint32>();
    if (getMode(handle, mode) != 0) {
      setMode(
        handle,
        mode.value | 0x0004,
      ); // ENABLE_VIRTUAL_TERMINAL_PROCESSING
    }
    free(heap, 0, ptr);
  } catch (_) {
    // VTP unavailable - colors degrade gracefully to plain text
  }
}

/// Cached color support result.
bool? _colorSupportCache;

/// Detects if the terminal supports ANSI colors.
bool get _supportsColor {
  return _colorSupportCache ??= _detectColorSupport();
}

/// Checks terminal capabilities for ANSI color support.
bool _detectColorSupport() {
  // Standard NO_COLOR / FORCE_COLOR environment variables
  if (Platform.environment.containsKey('NO_COLOR')) return false;

  if (Platform.environment.containsKey('FORCE_COLOR')) return true;

  // Not a terminal (piped, redirected)
  if (!stdout.hasTerminal) return false;

  // Dart's built-in check (reliable after VTP is enabled on Windows)
  if (stdout.supportsAnsiEscapes) return true;

  // cspell:ignore ANSICON
  // Windows: detect terminals known to support ANSI
  if (Platform.isWindows) {
    final env = Platform.environment;
    return env.containsKey('WT_SESSION') || // Windows Terminal
        env['ConEmuANSI'] == 'ON' || // ConEmu
        env['TERM_PROGRAM'] == 'vscode' || // VS Code terminal
        env.containsKey('ANSICON') || // ANSICON
        env['TERM'] == 'xterm'; // xterm-compatible
  }

  // Unix-like: most terminals support colors
  return true;
}

/// ANSI color codes (cross-platform safe).
class _Colors {
  static String get reset => _supportsColor ? '\x1B[0m' : '';
  static String get bold => _supportsColor ? '\x1B[1m' : '';
  static String get dim => _supportsColor ? '\x1B[2m' : '';

  // Foreground colors
  static String get red => _supportsColor ? '\x1B[31m' : '';
  static String get green => _supportsColor ? '\x1B[32m' : '';
  static String get yellow => _supportsColor ? '\x1B[33m' : '';
  static String get blue => _supportsColor ? '\x1B[34m' : '';
  static String get magenta => _supportsColor ? '\x1B[35m' : '';
  static String get cyan => _supportsColor ? '\x1B[36m' : '';

  // Bright variants
  static String get brightRed => _supportsColor ? '\x1B[91m' : '';
  static String get brightCyan => _supportsColor ? '\x1B[96m' : '';
}

/// Color helpers for consistent styling.
String _success(String text) => '${_Colors.green}$text${_Colors.reset}';
String _error(String text) => '${_Colors.red}$text${_Colors.reset}';
String _tierColor(String tier) {
  switch (tier) {
    case 'essential':
      return '${_Colors.brightRed}$tier${_Colors.reset}';
    case 'recommended':
      return '${_Colors.yellow}$tier${_Colors.reset}';
    case 'professional':
      return '${_Colors.blue}$tier${_Colors.reset}';
    case 'comprehensive':
      return '${_Colors.magenta}$tier${_Colors.reset}';
    case 'pedantic':
      return '${_Colors.brightCyan}$tier${_Colors.reset}';
    case 'stylistic':
      return '${_Colors.dim}$tier${_Colors.reset}';
    default:
      return tier;
  }
}

// ---------------------------------------------------------------------------
// Rule metadata cache (problem messages, severities)
// ---------------------------------------------------------------------------

/// Cache for rule metadata (built once from allSaropaRules).
Map<String, _RuleMetadata>? _ruleMetadataCache;

/// Metadata for a single rule.
class _RuleMetadata {
  const _RuleMetadata({
    required this.name,
    required this.problemMessage,
    required this.correctionMessage,
    required this.severity,
    required this.tier,
    required this.hasFix,
    this.exampleBad,
    this.exampleGood,
  });

  final String name;
  final String problemMessage;
  final String correctionMessage;
  final String severity; // 'ERROR', 'WARNING', 'INFO'
  final RuleTier tier;

  /// Whether this rule provides a quick fix in the IDE.
  final bool hasFix;

  /// Short BAD example for CLI walkthrough (null if not provided).
  final String? exampleBad;

  /// Short GOOD example for CLI walkthrough (null if not provided).
  final String? exampleGood;
}

/// Builds and returns rule metadata from rule classes.
Map<String, _RuleMetadata> _getRuleMetadata() {
  if (_ruleMetadataCache != null) return _ruleMetadataCache!;

  _ruleMetadataCache = <String, _RuleMetadata>{};
  for (final SaropaLintRule rule in allSaropaRules) {
    {
      final String ruleName = rule.code.name;
      final String message = rule.code.problemMessage;
      final String correction = rule.code.correctionMessage ?? '';

      // Extract severity from LintCode
      final severity = rule.code.severity.name.toUpperCase();

      // Get tier from tiers.dart (single source of truth)
      final RuleTier tier = _getTierFromSets(ruleName);

      _ruleMetadataCache![ruleName] = _RuleMetadata(
        name: ruleName,
        problemMessage: message,
        correctionMessage: correction,
        severity: severity,
        tier: tier,
        hasFix: rule.fixGenerators.isNotEmpty,
        exampleBad: rule.exampleBad,
        exampleGood: rule.exampleGood,
      );
    }
  }

  return _ruleMetadataCache!;
}

/// Gets the problem message for a rule (for YAML comment).
String _getProblemMessage(String ruleName) {
  final metadata = _getRuleMetadata()[ruleName];

  if (metadata == null) return '';

  return _stripRulePrefix(metadata.problemMessage);
}

/// Gets a combined description for a rule (problem + correction).
///
/// Used in the stylistic section of analysis_options_custom.yaml where
/// users need enough context to decide whether to enable each rule.
/// Falls back to just problemMessage if correctionMessage is empty or
/// redundant.
String _getStylisticDescription(String ruleName) {
  final metadata = _getRuleMetadata()[ruleName];

  if (metadata == null) return '';

  final problem = _stripRulePrefix(metadata.problemMessage);
  final correction = _stripRulePrefix(metadata.correctionMessage);

  if (correction.isEmpty) return problem;

  // If correction just restates the problem, skip it
  if (problem.contains(correction) || correction.contains(problem)) {
    // Return whichever is longer (more context)
    return problem.length >= correction.length ? problem : correction;
  }

  return '$problem $correction';
}

/// Remove rule name prefix if present (e.g., "`rule_name` ...").
String _stripRulePrefix(String msg) {
  final prefixMatch = RegExp(r'^\[[\w_]+\]\s*').firstMatch(msg);

  if (prefixMatch != null) {
    return msg.substring(prefixMatch.end);
  }

  return msg;
}

/// Gets the severity for a rule.
String _getRuleSeverity(String ruleName) {
  return _getRuleMetadata()[ruleName]?.severity ?? 'INFO';
}

/// Gets the tier for a rule.
RuleTier _getRuleTierFromMetadata(String ruleName) {
  return _getRuleMetadata()[ruleName]?.tier ?? RuleTier.professional;
}

// ---------------------------------------------------------------------------
// Regex patterns (defined once, used in multiple places)
// ---------------------------------------------------------------------------

/// Matches the `plugins:` section header in YAML.
final RegExp _pluginsSectionPattern = RegExp(r'^plugins:\s*$', multiLine: true);

/// Matches any top-level YAML key (for finding section boundaries).
final RegExp _topLevelKeyPattern = RegExp(r'^\w+:', multiLine: true);

/// Matches rule entries like `rule_name: true` or `rule_name: false`.
final RegExp _ruleEntryPattern = RegExp(
  r'^\s+(\w+):\s*(true|false)',
  multiLine: true,
);

/// Matches the `custom_lint:` section header (v4 format) in YAML.
final RegExp _customLintSectionPattern = RegExp(
  r'^custom_lint:\s*$',
  multiLine: true,
);

/// Matches v4 rule entries: `rule_name: true` or `- rule_name: false`.
/// Handles both dash-prefix (list) and plain (map) v4 formats.
final RegExp _v4RuleEntryPattern = RegExp(
  r'^\s+-?\s*([\w_]+):\s*(true|false)',
  multiLine: true,
);

/// Matches `- custom_lint` line in the `analyzer: plugins:` section.
final RegExp _analyzerCustomLintLine = RegExp(
  r'^\s+-\s*custom_lint\s*$',
  multiLine: true,
);

/// All available tiers in order of strictness.
const List<String> tierOrder = <String>[
  'essential',
  'recommended',
  'professional',
  'comprehensive',
  'pedantic',
];

/// Map tier names to numeric IDs for user convenience.
const Map<String, int> tierIds = <String, int>{
  'essential': 1,
  'recommended': 2,
  'professional': 3,
  'comprehensive': 4,
  'pedantic': 5,
};

/// Tier descriptions for display.
const Map<String, String> tierDescriptions = <String, String>{
  'essential':
      'Critical rules preventing crashes, security holes, memory leaks',
  'recommended': 'Essential + accessibility, performance patterns',
  'professional': 'Recommended + architecture, testing, documentation',
  'comprehensive': 'Professional + thorough coverage (recommended)',
  'pedantic': 'All rules enabled (may have conflicts)',
};

/// Stylistic rule categories, mirroring the organization in tiers.dart.
/// Used to generate the STYLISTIC RULES section in analysis_options_custom.yaml.
///
/// Categories containing "(conflicting - choose one)" in their name use a
/// pick-one UI in the walkthrough; all others are reviewed rule-by-rule.
const Map<String, List<String>> _stylisticRuleCategories =
    <String, List<String>>{
      // ── Non-conflicting categories ──────────────────────────────────────
      'Debug/Test utility': <String>['prefer_fail_test_case'],
      'Ordering & Sorting': <String>[
        'prefer_member_ordering',
        'prefer_arguments_ordering',
        'prefer_sorted_parameters',
        'prefer_sorted_pattern_fields',
        'prefer_sorted_record_fields',
        'binary_expression_operand_order',
        'enforce_parameters_ordering',
        'enum_constants_ordering',
        'map_keys_ordering',
      ],
      'Naming conventions': <String>[
        'prefer_boolean_prefixes',
        'prefer_no_getter_prefix',
        'prefer_kebab_tag_name',
        'prefer_capitalized_comment_start',
        'prefer_descriptive_bool_names',
        'prefer_snake_case_files',
        'prefer_camel_case_method_names',
        'prefer_exception_suffix',
        'prefer_error_suffix',
        'prefer_boolean_prefixes_for_params',
        'prefer_boolean_prefixes_for_locals',
        'prefer_trailing_underscore_for_unused',
        'prefer_sliver_prefix',
        'prefer_correct_callback_field_name',
        'prefer_correct_handler_name',
        'prefer_correct_setter_parameter_name',
        'prefer_bloc_event_suffix',
        'prefer_bloc_state_suffix',
        'prefer_use_prefix',
      ],
      'Code style preferences': <String>[
        'prefer_no_continue_statement',
        'prefer_wildcard_for_unused_param',
        'prefer_rethrow_over_throw_e',
        'prefer_list_first',
        'prefer_list_last',
        'no_boolean_literal_compare',
        'prefer_returning_conditional_expressions',
        'prefer_duration_constants',
        'prefer_immediate_return',
        'prefer_for_in',
        'prefer_conditional_expressions',
        'prefer_returning_condition',
        'prefer_returning_conditionals',
        'prefer_returning_shorthands',
        'prefer_pushing_conditional_expressions',
        'prefer_getter_over_method',
      ],
      'Function & Parameter style': <String>[
        'prefer_arrow_functions',
        'prefer_all_named_parameters',
        'prefer_inline_callbacks',
        'avoid_parameter_reassignment',
      ],
      'Widget style': <String>[
        'avoid_shrink_wrap_in_scroll',
        'prefer_one_widget_per_file',
        'prefer_widget_methods_over_classes',
        'prefer_borderradius_circular',
        'avoid_small_text',
        'prefer_sized_box_square',
        'prefer_center_over_align',
        'prefer_spacing_over_sizedbox',
      ],
      'Class & Record style': <String>[
        'prefer_class_over_record_return',
        'prefer_private_underscore_prefix',
        'prefer_explicit_this',
      ],
      'Formatting': <String>[
        'prefer_blank_line_before_case',
        'prefer_blank_line_before_constructor',
        'prefer_blank_line_before_method',
        'prefer_trailing_comma',
        'double_literal_format',
        'format_comment_style',
      ],
      'Comments & Documentation': <String>[
        'prefer_todo_format',
        'prefer_fixme_format',
        'prefer_sentence_case_comments',
        'prefer_period_after_doc',
        'prefer_doc_comments_over_regular',
        'prefer_no_commented_out_code',
      ],
      'Testing style': <String>['prefer_expect_over_assert_in_tests'],

      // ── Conflicting categories (pick one) ───────────────────────────────

      // Type & variable style
      'Type argument style (conflicting - choose one)': <String>[
        'prefer_inferred_type_arguments',
        'prefer_explicit_type_arguments',
      ],
      'Variable type style (conflicting - choose one)': <String>[
        'prefer_type_over_var',
        'prefer_var_over_explicit_type',
      ],
      'Dynamic vs Object (conflicting - choose one)': <String>[
        'prefer_dynamic_over_object',
        'prefer_object_over_dynamic',
      ],

      // Imports & strings
      'Import style (conflicting - choose one)': <String>[
        'prefer_absolute_imports',
        'prefer_flat_imports',
        'prefer_grouped_imports',
        'prefer_named_imports',
        'prefer_relative_imports',
      ],
      'Quote style (conflicting - choose one)': <String>[
        'prefer_double_quotes',
        'prefer_single_quotes',
      ],
      'Apostrophe style (conflicting - choose one)': <String>[
        'prefer_doc_curly_apostrophe',
        'prefer_doc_straight_apostrophe',
        'prefer_straight_apostrophe',
      ],
      'String building (conflicting - choose one)': <String>[
        'prefer_interpolation_over_concatenation',
        'prefer_concatenation_over_interpolation',
      ],

      // Control flow & error handling
      'Exit strategy (conflicting - choose one)': <String>[
        'prefer_early_return',
        'prefer_single_exit_point',
      ],
      'Boolean comparison (conflicting - choose one)': <String>[
        'prefer_implicit_boolean_comparison',
        'prefer_explicit_boolean_comparison',
      ],
      'Error handling (conflicting - choose one)': <String>[
        'prefer_catch_over_on',
        'prefer_on_over_catch',
      ],
      'Exception specificity (conflicting - choose one)': <String>[
        'prefer_specific_exceptions',
        'prefer_generic_exception',
      ],

      // Async & chaining
      'Async style (conflicting - choose one)': <String>[
        'prefer_await_over_then',
        'prefer_then_over_await',
      ],
      'Method chaining (conflicting - choose one)': <String>[
        'prefer_cascade_over_chained',
        'prefer_chained_over_cascade',
      ],

      // Collections & null handling
      'Spread vs addAll (conflicting - choose one)': <String>[
        'prefer_spread_over_addall',
        'prefer_addall_over_spread',
      ],
      'Collection conditionals (conflicting - choose one)': <String>[
        'prefer_collection_if_over_ternary',
        'prefer_ternary_over_collection_if',
      ],
      'Null ternary (conflicting - choose one)': <String>[
        'prefer_if_null_over_ternary',
        'prefer_ternary_over_if_null',
      ],
      'Null assignment (conflicting - choose one)': <String>[
        'prefer_null_aware_assignment',
        'prefer_explicit_null_assignment',
      ],
      'Nullable vs late (conflicting - choose one)': <String>[
        'prefer_nullable_over_late',
        'prefer_late_over_nullable',
      ],

      // Ordering & naming
      'Member ordering (conflicting - choose one)': <String>[
        'prefer_static_members_first',
        'prefer_instance_members_first',
        'prefer_public_members_first',
        'prefer_private_members_first',
      ],
      'Field/method order (conflicting - choose one)': <String>[
        'prefer_fields_before_methods',
        'prefer_methods_before_fields',
      ],
      'Constant case (conflicting - choose one)': <String>[
        'prefer_lower_camel_case_constants',
        'prefer_screaming_case_constants',
      ],

      // Formatting & spacing
      'Trailing comma (conflicting - choose one)': <String>[
        'prefer_trailing_comma_always',
        'unnecessary_trailing_comma',
      ],
      'Blank line before return (conflicting - choose one)': <String>[
        'prefer_blank_line_before_return',
        'prefer_no_blank_line_before_return',
      ],
      'Declaration spacing (conflicting - choose one)': <String>[
        'prefer_blank_line_after_declarations',
        'prefer_compact_declarations',
      ],
      'Member spacing (conflicting - choose one)': <String>[
        'prefer_blank_lines_between_members',
        'prefer_compact_class_members',
      ],

      // Widget conflicts
      'Container vs SizedBox (conflicting - choose one)': <String>[
        'prefer_sizedbox_over_container',
        'prefer_container_over_sizedbox',
      ],
      'Expanded vs Flexible (conflicting - choose one)': <String>[
        'prefer_expanded_over_flexible',
        'prefer_flexible_over_expanded',
      ],
      'EdgeInsets style (conflicting - choose one)': <String>[
        'prefer_edgeinsets_symmetric',
        'prefer_edgeinsets_only',
      ],
      'RichText widget (conflicting - choose one)': <String>[
        'prefer_text_rich_over_richtext',
        'prefer_richtext_over_text_rich',
      ],
      'Theme colors (conflicting - choose one)': <String>[
        'prefer_material_theme_colors',
        'prefer_explicit_colors',
      ],

      // Testing conflicts
      'Test naming (conflicting - choose one)': <String>[
        'prefer_test_name_should_when',
        'prefer_test_name_descriptive',
      ],
      'Test comments (conflicting - choose one)': <String>[
        'prefer_given_when_then_comments',
        'prefer_self_documenting_tests',
      ],
      'Test expectations (conflicting - choose one)': <String>[
        'prefer_single_expectation_per_test',
        'prefer_grouped_expectations',
      ],

      // ── Remaining opinionated rules (no conflicts) ─────────────────────
      'Opinionated rules': <String>[
        'prefer_clip_r_superellipse',
        'prefer_clip_r_superellipse_clipper',
        'prefer_concise_variable_names',
        'prefer_constructor_assertion',
        'prefer_constructor_body_assignment',
        'prefer_curly_apostrophe',
        'prefer_default_enum_case',
        'prefer_descriptive_bool_names_strict',
        'prefer_descriptive_variable_names',
        'prefer_dot_shorthand',
        'prefer_exhaustive_enums',
        'prefer_explicit_types',
        'prefer_factory_for_validation',
        'prefer_fake_over_mock',
        'prefer_future_void_function_over_async_callback',
        'prefer_grouped_by_purpose',
        'prefer_guard_clauses',
        'prefer_initializing_formals',
        'prefer_keys_with_lookup',
        'prefer_map_entries_iteration',
        'prefer_mutable_collections',
        'prefer_no_blank_line_inside_blocks',
        'prefer_positive_conditions',
        'prefer_positive_conditions_first',
        'prefer_record_over_equatable',
        'prefer_required_before_optional',
        'prefer_single_blank_line_max',
        'prefer_super_parameters',
        'prefer_switch_statement',
        'prefer_sync_over_async_where_possible',
        'prefer_test_data_builder',
        'prefer_wheretype_over_where_is',
      ],
    };

// ---------------------------------------------------------------------------
// Tier functions - read directly from rule classes (single source of truth)
// ---------------------------------------------------------------------------

/// Maps RuleTier enum to tier string name.
String _tierToString(RuleTier tier) {
  return switch (tier) {
    RuleTier.essential => 'essential',
    RuleTier.recommended => 'recommended',
    RuleTier.professional => 'professional',
    RuleTier.comprehensive => 'comprehensive',
    RuleTier.pedantic => 'pedantic',
    RuleTier.stylistic => 'stylistic',
  };
}

/// Returns the tier order index (lower = stricter requirements).
int _tierIndex(RuleTier tier) {
  return switch (tier) {
    RuleTier.essential => 0,
    RuleTier.recommended => 1,
    RuleTier.professional => 2,
    RuleTier.comprehensive => 3,
    RuleTier.pedantic => 4,
    RuleTier.stylistic =>
      -1, // Stylistic is opt-in, not part of tier progression
  };
}

/// Gets tier from tiers.dart sets (single source of truth).
RuleTier _getTierFromSets(String ruleName) {
  if (tiers.stylisticRules.contains(ruleName)) return RuleTier.stylistic;

  if (tiers.essentialRules.contains(ruleName)) return RuleTier.essential;

  if (tiers.pedanticOnlyRules.contains(ruleName)) return RuleTier.pedantic;

  if (tiers.comprehensiveOnlyRules.contains(ruleName)) {
    return RuleTier.comprehensive;
  }

  if (tiers.professionalOnlyRules.contains(ruleName)) {
    return RuleTier.professional;
  }

  if (tiers.recommendedOnlyRules.contains(ruleName)) {
    return RuleTier.recommended;
  }

  return RuleTier.professional;
}

/// Main entry point for the CLI tool.
Future<void> main(List<String> args) async {
  // Enable ANSI color support on Windows 10+
  _tryEnableAnsiWindows();

  // Initialize log timestamp for report file
  final now = DateTime.now();
  _logTimestamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

  // Move old reports from reports/ root into date subfolders
  _migrateOldReports();

  // Get version, source, and package directory early for logging + what's new
  final version = _getPackageVersion();
  final source = _getPackageSource();
  final rootUri = _getSaropaLintsRootUri();
  final packageDir = rootUri != null ? _rootUriToPath(rootUri) : null;

  // Add header to log buffer
  _logBuffer.writeln('=' * 80);
  _logBuffer.writeln('SAROPA LINTS CONFIGURATION LOG');
  _logBuffer.writeln('Version: $version');
  _logBuffer.writeln('Source: $source');
  _logBuffer.writeln('Generated: ${now.toIso8601String()}');
  _logBuffer.writeln('Arguments: ${args.join(' ')}');
  _logBuffer.writeln('=' * 80);
  _logBuffer.writeln();

  final CliArgs cliArgs = _parseArguments(args);

  if (cliArgs.showHelp) {
    _printUsage();
    return;
  }

  _logTerminal('');
  _logTerminal('${_Colors.cyan}SAROPA LINTS${_Colors.reset} v$version');
  _logTerminal('${_Colors.dim}Source: $source${_Colors.reset}');
  _showWhatsNew(version, packageDir);
  _logTerminal('');

  // Resolve tier (handle numeric input, or prompt if not specified)
  String? tier = _resolveTier(cliArgs.tier);

  if (tier == null && cliArgs.tier != null) {
    // User explicitly provided an invalid tier name/number
    _logTerminal(_error('✗ Error: Invalid tier "${cliArgs.tier}"'));
    _logTerminal('');
    _logTerminal('Valid tiers:');
    for (final MapEntry<String, int> entry in tierIds.entries) {
      _logTerminal('  ${entry.value} or ${_tierColor(entry.key)}');
    }
    exitCode = 1;
    return;
  }

  if (tier == null) {
    // No tier specified — prompt interactively or fall back to default
    tier = _promptForTier();
  }
  final String resolvedTier = tier;

  _logTerminal(
    '${_Colors.bold}Tier:${_Colors.reset} ${_tierColor(resolvedTier)} (level ${tierIds[resolvedTier]})',
  );
  _logTerminal(
    '${_Colors.dim}${tierDescriptions[resolvedTier]}${_Colors.reset}',
  );
  _logTerminal('');

  // Run pre-flight validation checks (non-fatal warnings)
  _runPreflightChecks(version: version);

  // tiers.dart is the source of truth for all rules
  // A unit test validates that all plugin rules are in tiers.dart
  final Set<String> allRules = tiers.getAllDefinedRules();
  final Set<String> enabledRules = tiers.getRulesForTier(resolvedTier);
  final Set<String> disabledRules = allRules.difference(enabledRules);

  // Handle stylistic rules (opt-in).
  // --stylistic-all: bulk-enable all (old --stylistic behavior for CI).
  // --stylistic / default: interactive walkthrough (handled after config gen).
  // --no-stylistic: skip entirely, stylistic rules stay as-is in custom yaml.
  Set<String> finalEnabled = enabledRules;
  Set<String> finalDisabled = disabledRules;

  if (cliArgs.stylisticAll) {
    finalEnabled = finalEnabled.union(tiers.stylisticRules);
    finalDisabled = finalDisabled.difference(tiers.stylisticRules);
  } else {
    // Stylistic rules are managed in analysis_options_custom.yaml,
    // not in the main diagnostics block. Keep them out of tier output.
    finalEnabled = finalEnabled.difference(tiers.stylisticRules);
    finalDisabled = finalDisabled.union(tiers.stylisticRules);
  }

  // Read or create custom overrides file (survives --reset)
  final File overridesFile = File('analysis_options_custom.yaml');
  Map<String, bool> permanentOverrides = <String, bool>{};
  Map<String, bool> platformSettings = Map<String, bool>.of(
    tiers.defaultPlatforms,
  );
  Map<String, bool> packageSettings = Map<String, bool>.of(
    tiers.defaultPackages,
  );

  if (overridesFile.existsSync()) {
    // Ensure all sections exist in the file
    _ensureMaxIssuesSetting(overridesFile);
    _ensurePlatformsSetting(overridesFile);
    _ensurePackagesSetting(overridesFile);
    _ensureStylisticRulesSection(overridesFile);
    platformSettings = _extractPlatformsFromFile(overridesFile);
    packageSettings = _extractPackagesFromFile(overridesFile);

    // Extract overrides and partition stylistic from non-stylistic
    final allOverrides = _extractOverridesFromFile(overridesFile, allRules);
    for (final entry in allOverrides.entries) {
      if (tiers.stylisticRules.contains(entry.key)) {
        // Stylistic overrides apply on top of --stylistic flag
        if (entry.value) {
          finalEnabled = finalEnabled.union(<String>{entry.key});
          finalDisabled = finalDisabled.difference(<String>{entry.key});
        } else {
          finalEnabled = finalEnabled.difference(<String>{entry.key});
          finalDisabled = finalDisabled.union(<String>{entry.key});
        }
      } else {
        permanentOverrides[entry.key] = entry.value;
      }
    }
  } else {
    // Auto-detect packages from pubspec.yaml for first-time setup
    packageSettings = _detectProjectPackages();

    // Create the custom overrides file with a helpful header
    _createCustomOverridesFile(overridesFile);
    _logTerminal(
      '${_Colors.green}✓ Created:${_Colors.reset} '
      'analysis_options_custom.yaml',
    );
  }

  // Apply platform filtering - disable rules for disabled platforms
  final Set<String> platformDisabledRules = tiers.getRulesDisabledByPlatforms(
    platformSettings,
  );

  if (platformDisabledRules.isNotEmpty) {
    finalEnabled = finalEnabled.difference(platformDisabledRules);
    finalDisabled = finalDisabled.union(platformDisabledRules);

    final disabledPlatforms = platformSettings.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();
    _logTerminal(
      '${_Colors.yellow}Platforms disabled:${_Colors.reset} '
      '${disabledPlatforms.join(', ')} '
      '${_Colors.dim}(${platformDisabledRules.length} rules affected)${_Colors.reset}',
    );
  }

  // Apply package filtering - disable rules for disabled packages
  final Set<String> packageDisabledRules = tiers.getRulesDisabledByPackages(
    packageSettings,
  );

  if (packageDisabledRules.isNotEmpty) {
    finalEnabled = finalEnabled.difference(packageDisabledRules);
    finalDisabled = finalDisabled.union(packageDisabledRules);

    final disabledPackages = packageSettings.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();
    _logTerminal(
      '${_Colors.yellow}Packages disabled:${_Colors.reset} '
      '${disabledPackages.join(', ')} '
      '${_Colors.dim}(${packageDisabledRules.length} rules affected)${_Colors.reset}',
    );
  }

  // Read existing config and extract user customizations
  final File outputFile = File(cliArgs.outputPath);
  Map<String, bool> userCustomizations = <String, bool>{};
  String existingContent = '';

  // Track whether v4 migration occurred (used for ignore comment tip)
  bool v4Detected = false;
  Map<String, bool> v4MigratedRules = <String, bool>{};

  if (outputFile.existsSync()) {
    existingContent = outputFile.readAsStringSync();

    // Auto-detect and migrate v4 custom_lint: format
    if (_detectV4Config(existingContent)) {
      v4Detected = true;
      _logTerminal('');
      _logTerminal(
        '${_Colors.yellow}--- V4 MIGRATION DETECTED ---${_Colors.reset}',
      );
      _logTerminal(
        '${_Colors.yellow}Found custom_lint: section (v4 format)${_Colors.reset}',
      );

      v4MigratedRules = _extractV4Rules(existingContent, allRules);
      _logTerminal(
        '${_Colors.dim}  Extracted ${v4MigratedRules.length} rule '
        'settings from v4 config${_Colors.reset}',
      );

      existingContent = _removeCustomLintSection(existingContent);
      existingContent = _removeAnalyzerCustomLintPlugin(existingContent);
      _logTerminal(
        '${_Colors.green}Removed custom_lint: section${_Colors.reset}',
      );

      _cleanPubspecCustomLint(dryRun: cliArgs.dryRun);
      _logTerminal('');
    }

    if (!cliArgs.reset) {
      userCustomizations = _extractUserCustomizations(
        existingContent,
        allRules,
      );

      // Warn if manual edits in tier sections were recovered
      final tierEdits = _detectManualTierEdits(existingContent, allRules);
      if (tierEdits.isNotEmpty) {
        _logTerminal(
          '${_Colors.yellow}⚠ Recovered ${tierEdits.length} manually '
          'edited rule(s) from tier sections${_Colors.reset}',
        );
        _logTerminal(
          '${_Colors.dim}  Tip: add overrides to '
          'analysis_options_custom.yaml RULE OVERRIDES '
          'section instead${_Colors.reset}',
        );
      }

      // Merge v4 rules as customizations (v5 customizations take precedence)
      // Only import rules where v4 setting differs from v5 tier default
      if (v4MigratedRules.isNotEmpty) {
        final int totalV4 = v4MigratedRules.length;
        v4MigratedRules.removeWhere((rule, enabled) {
          if (enabled) {
            return finalEnabled.contains(rule);
          } else {
            return finalDisabled.contains(rule);
          }
        });
        userCustomizations = {...v4MigratedRules, ...userCustomizations};
        final int skipped = totalV4 - v4MigratedRules.length;
        _logTerminal(
          '${_Colors.green}${v4MigratedRules.length} v4 rules imported '
          'as user customizations${_Colors.reset}'
          '${skipped > 0 ? ' ${_Colors.dim}($skipped matched tier defaults, skipped)${_Colors.reset}' : ''}',
        );
      }

      // Warn if suspiciously many customizations (likely corrupted)
      if (userCustomizations.length > 50) {
        _logTerminal(
          '${_Colors.red}⚠ ${userCustomizations.length} customizations found - consider --reset${_Colors.reset}',
        );
      }
    } else {
      if (v4MigratedRules.isNotEmpty) {
        _logTerminal(
          '${_Colors.yellow}⚠ --reset: discarding ${v4MigratedRules.length} '
          'v4 rule settings (run without --reset to preserve)${_Colors.reset}',
        );
      } else {
        _logTerminal(
          '${_Colors.yellow}⚠ --reset: discarding customizations${_Colors.reset}',
        );
      }
    }
  }

  // Merge permanent overrides with user customizations
  // Permanent overrides always take precedence
  if (permanentOverrides.isNotEmpty) {
    userCustomizations = {...userCustomizations, ...permanentOverrides};
  }

  // Count rules by severity for summary
  final Map<String, int> enabledBySeverity = {
    'ERROR': 0,
    'WARNING': 0,
    'INFO': 0,
  };
  final Map<String, int> disabledBySeverity = {
    'ERROR': 0,
    'WARNING': 0,
    'INFO': 0,
  };

  for (final rule in finalEnabled) {
    final severity = _getRuleSeverity(rule);
    enabledBySeverity[severity] = (enabledBySeverity[severity] ?? 0) + 1;
  }
  for (final rule in finalDisabled) {
    final severity = _getRuleSeverity(rule);
    disabledBySeverity[severity] = (disabledBySeverity[severity] ?? 0) + 1;
  }

  // Count by tier for enabled rules
  final Map<String, int> enabledByTierCount = {};
  for (final rule in finalEnabled) {
    final tierName = _tierToString(_getRuleTierFromMetadata(rule));
    enabledByTierCount[tierName] = (enabledByTierCount[tierName] ?? 0) + 1;
  }

  // Compact summary
  _logTerminal('');
  final totalRules = finalEnabled.length + finalDisabled.length;
  final disabledPct = totalRules > 0
      ? (finalDisabled.length * 100 ~/ totalRules)
      : 0;
  _logTerminal(
    '${_Colors.bold}Rules:${_Colors.reset} ${_success('${finalEnabled.length} enabled')} / ${_error('${finalDisabled.length} disabled')} ${_Colors.dim}($disabledPct%)${_Colors.reset}',
  );
  _logTerminal(
    '${_Colors.bold}Severity:${_Colors.reset} ${_Colors.red}${enabledBySeverity['ERROR']} errors${_Colors.reset} · ${_Colors.yellow}${enabledBySeverity['WARNING']} warnings${_Colors.reset} · ${_Colors.cyan}${enabledBySeverity['INFO']} info${_Colors.reset}',
  );

  // Project overrides summary
  final customCount = userCustomizations.length;

  if (customCount > 0) {
    final Map<String, int> customBySeverity = {
      'ERROR': 0,
      'WARNING': 0,
      'INFO': 0,
    };
    for (final rule in userCustomizations.keys) {
      final severity = _getRuleSeverity(rule);
      customBySeverity[severity] = (customBySeverity[severity] ?? 0) + 1;
    }
    _logTerminal(
      '${_Colors.bold}Project Overrides${_Colors.reset} ${_Colors.dim}(analysis_options_custom.yaml):${_Colors.reset} '
      '$customCount '
      '${_Colors.dim}(${_Colors.reset}'
      '${_Colors.red}${customBySeverity['ERROR']} error${_Colors.reset}, '
      '${_Colors.yellow}${customBySeverity['WARNING']} warning${_Colors.reset}, '
      '${_Colors.cyan}${customBySeverity['INFO']} info${_Colors.reset}'
      '${_Colors.dim})${_Colors.reset}',
    );
  }
  _logTerminal('');

  // Append rule-by-rule detail to the log file (not printed to terminal)
  _appendDetailedReport(
    enabledRules: finalEnabled,
    disabledRules: finalDisabled,
    userCustomizations: userCustomizations,
    platformFilteredRules: platformDisabledRules,
    packageFilteredRules: packageDisabledRules,
  );

  // Generate the new plugins section with proper formatting
  final String pluginsYaml = _generatePluginsYaml(
    tier: resolvedTier,
    packageVersion: version,
    enabledRules: finalEnabled,
    disabledRules: finalDisabled,
    userCustomizations: userCustomizations,
    allRules: allRules,
    includeStylistic: cliArgs.includeStylistic,
    platformSettings: platformSettings,
    packageSettings: packageSettings,
  );

  // Replace plugins section in existing content, preserving everything else
  final String newContent = _replacePluginsSection(
    existingContent,
    pluginsYaml,
  );

  if (cliArgs.dryRun) {
    _logTerminal('${_Colors.yellow}━━━ DRY RUN ━━━${_Colors.reset}');
    _logTerminal(
      '${_Colors.dim}Would write to: ${cliArgs.outputPath}${_Colors.reset}',
    );
    _logTerminal('');

    // Show preview of plugins section only
    final List<String> lines = pluginsYaml.split('\n');
    const int previewLines = 100;
    _logTerminal(
      '${_Colors.bold}Preview${_Colors.reset} ${_Colors.dim}(first $previewLines of ${lines.length} lines):${_Colors.reset}',
    );
    _logTerminal('${_Colors.dim}${'─' * 60}${_Colors.reset}');
    for (int i = 0; i < previewLines && i < lines.length; i++) {
      _logTerminal(lines[i]);
    }
    if (lines.length > previewLines) {
      _logTerminal(
        '${_Colors.dim}... (${lines.length - previewLines} more lines)${_Colors.reset}',
      );
    }
    return;
  }

  // Skip writing if the file content hasn't changed
  if (newContent == existingContent) {
    _logTerminal(
      '${_Colors.dim}✓ No changes needed: ${cliArgs.outputPath}${_Colors.reset}',
    );
  } else {
    // Create backup before overwriting
    try {
      final outputDir = outputFile.parent.path;
      final outputName = cliArgs.outputPath.split('/').last.split('\\').last;
      final backupPath = '$outputDir/${_logTimestamp}_$outputName.bak';
      outputFile.copySync(backupPath);
    } on Exception catch (_) {
      // Backup failed - continue anyway
    }

    try {
      outputFile.writeAsStringSync(newContent);
      _logTerminal('${_success('✓ Written to:')} ${cliArgs.outputPath}');
    } on Exception catch (e) {
      _logTerminal(_error('✗ Failed to write file: $e'));
      exitCode = 2;
      return;
    }
  }

  // Validate the written file has the critical sections
  _validateWrittenConfig(cliArgs.outputPath, allRules.length);

  // Convert v4 ignore comments (interactive prompt or --fix-ignores flag)
  if (v4Detected && !cliArgs.dryRun) {
    final bool shouldConvert;
    if (cliArgs.fixIgnores) {
      shouldConvert = true;
    } else if (!stdin.hasTerminal) {
      // Non-interactive: skip unless explicitly requested
      shouldConvert = false;
    } else {
      _logTerminal('');
      stdout.write(
        '${_Colors.cyan}Convert v4 ignore comments to v5 format? [y/N]: '
        '${_Colors.reset}',
      );
      final String resp = stdin.readLineSync()?.toLowerCase().trim() ?? '';
      shouldConvert = resp == 'y' || resp == 'yes';
    }

    if (shouldConvert) {
      _logTerminal(
        '${_Colors.bold}Converting v4 ignore comments...${_Colors.reset}',
      );
      final Map<String, int> ignoreResults = _convertIgnoreComments(
        allRules,
        false,
      );
      if (ignoreResults.isEmpty) {
        _logTerminal(
          '${_Colors.dim}  No v4 ignore comments found${_Colors.reset}',
        );
      } else {
        final int total = ignoreResults.values.fold(0, (s, c) => s + c);
        _logTerminal(
          '${_Colors.green}Converted $total ignore comments in '
          '${ignoreResults.length} files${_Colors.reset}',
        );
        for (final MapEntry<String, int> entry in ignoreResults.entries) {
          _logTerminal(
            '${_Colors.dim}  ${entry.key}: ${entry.value}${_Colors.reset}',
          );
        }
      }
    } else {
      _logTerminal(
        '${_Colors.dim}  Skipped ignore comment conversion${_Colors.reset}',
      );
    }
  }

  // ── Interactive stylistic walkthrough ──
  // Runs by default after config generation. Skip with --no-stylistic.
  // --stylistic-all already handled above (bulk-enable).
  if (!cliArgs.dryRun && !cliArgs.noStylistic && !cliArgs.stylisticAll) {
    final File overridesForWalkthrough = File('analysis_options_custom.yaml');
    if (overridesForWalkthrough.existsSync()) {
      _runStylisticWalkthrough(
        customFile: overridesForWalkthrough,
        packageSettings: packageSettings,
        platformSettings: platformSettings,
        resetStylistic: cliArgs.resetStylistic,
      );
    }
  }

  _logTerminal('');

  if (!cliArgs.dryRun) {
    // Write the init log (setup only) BEFORE analysis. The plugin writes
    // its own detailed report (*_saropa_lint_report.log) during analysis.
    _appendLogSummary((
      version: version,
      tier: resolvedTier,
      enabled: finalEnabled.length,
      disabled: finalDisabled.length,
      outputPath: cliArgs.outputPath,
    ));
    _writeLogFile();
    _logTerminal('');

    // Ask user if they want to run analysis
    stdout.write('${_Colors.cyan}Run analysis now? [y/N]: ${_Colors.reset}');
    final response = stdin.readLineSync()?.toLowerCase().trim() ?? '';

    if (response == 'y' || response == 'yes') {
      _logTerminal('');
      _logTerminal('${_Colors.bold}Running: dart analyze${_Colors.reset}');
      _logTerminal('${'─' * 60}');

      // Stream output to terminal. The plugin's AnalysisReporter writes
      // the structured results to a separate *_saropa_lint_report.log.
      final process = await Process.start('dart', [
        'analyze',
      ], runInShell: true);

      // Use UTF-8 decoder (not SystemEncoding) because Dart processes
      // always write UTF-8, and SystemEncoding on Windows uses the
      // console code page which corrupts Unicode progress bar characters.
      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .forEach(stdout.write);
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .forEach(stderr.write);

      // Wait for exit code AND stream drain together so the separator
      // line doesn't appear before trailing analyzer output.
      final exitCodeFuture = process.exitCode;
      await Future.wait([exitCodeFuture, stdoutDone, stderrDone]);
      final analyzeExitCode = await exitCodeFuture;
      _logTerminal('${'─' * 60}');

      if (analyzeExitCode == 0) {
        _logTerminal(_success('✓ dart analyze passed'));
      } else if (analyzeExitCode <= 2) {
        // Exit codes 1-2 mean "issues found" — the analysis completed.
        _logTerminal(_success('✓ dart analyze completed'));
      } else {
        // Exit code 3+ means the analyzer itself failed (internal error,
        // could not analyze, etc.)
        _logTerminal(
          _error('✗ dart analyze failed (exit code $analyzeExitCode)'),
        );
      }

      // Show the plugin's lint report path if one was generated.
      // Retries briefly since the plugin may still be flushing to disk.
      final dateFolder = AnalysisReporter.dateFolder(_logTimestamp!);
      final pluginReport = await _findNewestPluginReport(dateFolder);
      if (pluginReport != null) {
        _logTerminal(
          '${_Colors.bold}Report:${_Colors.reset} '
          '${_Colors.cyan}$pluginReport${_Colors.reset}',
        );
      }
    }
  }
}

/// Matches the USER CUSTOMIZATIONS section header in generated YAML.
final RegExp _userCustomizationsSectionPattern = RegExp(
  r'USER CUSTOMIZATIONS',
  multiLine: true,
);

/// Extract existing user customizations from the generated YAML.
///
/// Reads from two sources:
/// 1. The USER CUSTOMIZATIONS section (explicitly marked overrides)
/// 2. Tier sections where a rule value differs from the section's expected
///    direction (e.g., `false` in ENABLED → user manually disabled it)
///
/// This prevents tier changes from creating spurious "customizations"
/// while still preserving intentional manual edits.
///
/// Parameters:
/// - [yamlContent] - The existing YAML file content
/// - [allRules] - All known saropa_lints rules
Map<String, bool> _extractUserCustomizations(
  String yamlContent,
  Set<String> allRules,
) {
  final Map<String, bool> customizations = <String, bool>{};

  // Find USER CUSTOMIZATIONS section
  final Match? customizationsMatch = _userCustomizationsSectionPattern
      .firstMatch(yamlContent);

  if (customizationsMatch == null) {
    // No customizations section - file wasn't generated by this tool
    // or user hasn't made any customizations
    return customizations;
  }

  // Find the content after USER CUSTOMIZATIONS header
  final String afterHeader = yamlContent.substring(customizationsMatch.end);

  // Find the end of the customizations section (next major section header)
  // Look for ENABLED, DISABLED, STYLISTIC, or TIER headers
  final sectionEndPattern = RegExp(
    r'(ENABLED RULES|DISABLED RULES|STYLISTIC|TIER \d+:)',
    multiLine: true,
  );
  final Match? nextSection = sectionEndPattern.firstMatch(afterHeader);
  final String customizationsSection = nextSection != null
      ? afterHeader.substring(0, nextSection.start)
      : afterHeader;

  // Extract rules from the customizations section only
  for (final Match match in _ruleEntryPattern.allMatches(
    customizationsSection,
  )) {
    final String ruleName = match.group(1)!;
    final bool currentEnabled = match.group(2) == 'true';

    // Skip rules that aren't in our rule set (might be from other plugins)
    if (!allRules.contains(ruleName)) {
      continue;
    }

    customizations[ruleName] = currentEnabled;
  }

  // Detect manual edits in tier sections: the ENABLED section should only
  // contain true entries and DISABLED should only contain false. Any rule
  // with the opposite value was manually edited and should be preserved.
  final manualEdits = _detectManualTierEdits(yamlContent, allRules);
  for (final entry in manualEdits.entries) {
    // Existing USER CUSTOMIZATIONS take precedence
    if (!customizations.containsKey(entry.key)) {
      customizations[entry.key] = entry.value;
    }
  }

  return customizations;
}

/// Detect rules manually edited in ENABLED/DISABLED tier sections.
///
/// Init generates `true` in ENABLED sections and `false` in DISABLED
/// sections. Any opposite value was changed by the user after generation.
Map<String, bool> _detectManualTierEdits(
  String yamlContent,
  Set<String> allRules,
) {
  final Map<String, bool> edits = <String, bool>{};

  // ENABLED section: false entries are manual disables
  _collectOppositeEntries(
    yamlContent,
    allRules,
    sectionHeader: 'ENABLED RULES',
    expectedValue: true,
    edits: edits,
  );

  // DISABLED section: true entries are manual enables
  _collectOppositeEntries(
    yamlContent,
    allRules,
    sectionHeader: 'DISABLED RULES',
    expectedValue: false,
    edits: edits,
  );

  return edits;
}

/// Scan a tier section for rules whose value differs from [expectedValue].
void _collectOppositeEntries(
  String yamlContent,
  Set<String> allRules, {
  required String sectionHeader,
  required bool expectedValue,
  required Map<String, bool> edits,
}) {
  final headerMatch = RegExp(sectionHeader).firstMatch(yamlContent);

  if (headerMatch == null) return;

  final afterHeader = yamlContent.substring(headerMatch.end);

  // Section ends at the next major section header
  final nextSection = RegExp(
    r'(USER CUSTOMIZATIONS|ENABLED RULES|DISABLED RULES|STYLISTIC RULES)',
  ).firstMatch(afterHeader);

  final section = nextSection != null
      ? afterHeader.substring(0, nextSection.start)
      : afterHeader;

  for (final match in _ruleEntryPattern.allMatches(section)) {
    final ruleName = match.group(1)!;
    final value = match.group(2) == 'true';

    if (!allRules.contains(ruleName)) continue;
    if (value != expectedValue) {
      edits[ruleName] = value;
    }
  }
}

// ---------------------------------------------------------------------------
// V4 (custom_lint) auto-migration
// ---------------------------------------------------------------------------

/// Detects whether the YAML content contains a v4 `custom_lint:` section.
bool _detectV4Config(String yamlContent) {
  return _customLintSectionPattern.hasMatch(yamlContent);
}

/// Extracts rule settings from a v4 `custom_lint:` section.
///
/// Handles both v4 formats:
/// - Plain: `rule_name: true`
/// - List:  `- rule_name: true`
///
/// Only returns rules that exist in [allRules].
Map<String, bool> _extractV4Rules(String yamlContent, Set<String> allRules) {
  final Map<String, bool> rules = <String, bool>{};

  final Match? sectionMatch = _customLintSectionPattern.firstMatch(yamlContent);

  if (sectionMatch == null) return rules;

  // Get content from custom_lint: until next top-level key or EOF
  final String afterSection = yamlContent.substring(sectionMatch.end);
  final Match? nextTopLevel = _topLevelKeyPattern.firstMatch(afterSection);
  final String sectionContent = nextTopLevel != null
      ? afterSection.substring(0, nextTopLevel.start)
      : afterSection;

  for (final Match match in _v4RuleEntryPattern.allMatches(sectionContent)) {
    final String ruleName = match.group(1)!;
    final bool enabled = match.group(2) == 'true';

    if (allRules.contains(ruleName)) {
      rules[ruleName] = enabled;
    }
  }

  return rules;
}

/// Removes the `custom_lint:` section from YAML content.
///
/// Removes everything from `custom_lint:` to the next top-level key
/// (or end of file).
String _removeCustomLintSection(String content) {
  final Match? sectionMatch = _customLintSectionPattern.firstMatch(content);

  if (sectionMatch == null) return content;

  final String before = content.substring(0, sectionMatch.start);
  final String afterStart = content.substring(sectionMatch.end);
  final Match? nextTopLevel = _topLevelKeyPattern.firstMatch(afterStart);
  final String after = nextTopLevel != null
      ? afterStart.substring(nextTopLevel.start)
      : '';

  return '${before.trimRight()}\n\n$after'.trimRight() + '\n';
}

/// Removes `- custom_lint` from the `analyzer: plugins:` section.
/// Also removes the `plugins:` sub-key if it becomes empty.
String _removeAnalyzerCustomLintPlugin(String content) {
  String result = content.replaceAll(_analyzerCustomLintLine, '');

  // Remove empty `plugins:` key (no indented children remaining)
  result = result.replaceAll(
    RegExp(r'^\s+plugins:\s*\n(?=\s{0,2}\S|\s*$)', multiLine: true),
    '',
  );

  return result;
}

/// Removes custom_lint from pubspec.yaml dev_dependencies after user
/// confirmation. Skips silently if not found in dev_dependencies.
void _cleanPubspecCustomLint({required bool dryRun}) {
  final File pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) return;

  final String content = pubspecFile.readAsStringSync();

  // Only match custom_lint inside the dev_dependencies section
  final String? cleaned = _removeDevDep(content, 'custom_lint');

  if (cleaned == null) return;

  _logTerminal('');

  // Skip prompts in non-interactive mode (CI, piped input)
  if (!stdin.hasTerminal) {
    _logTerminal(
      '${_Colors.dim}  Non-interactive: skipping pubspec.yaml '
      'cleanup (remove custom_lint manually)${_Colors.reset}',
    );
    return;
  }

  stdout.write(
    '${_Colors.cyan}Remove custom_lint from pubspec.yaml '
    'dev_dependencies? [y/N]: ${_Colors.reset}',
  );
  final String response = stdin.readLineSync()?.toLowerCase().trim() ?? '';

  if (response != 'y' && response != 'yes') {
    _logTerminal(
      '${_Colors.dim}  Skipped pubspec.yaml cleanup${_Colors.reset}',
    );
    return;
  }

  if (dryRun) {
    _logTerminal(
      '${_Colors.dim}  (dry-run) Would remove custom_lint from '
      'pubspec.yaml${_Colors.reset}',
    );
    return;
  }

  pubspecFile.writeAsStringSync(cleaned);
  _logTerminal(
    '${_Colors.green}Removed custom_lint from pubspec.yaml${_Colors.reset}',
  );
  _logTerminal(
    '${_Colors.dim}  Run dart pub get to update dependencies${_Colors.reset}',
  );
}

/// Removes a dependency line from the dev_dependencies section only.
/// Returns the modified content, or null if the dependency was not found.
String? _removeDevDep(String content, String packageName) {
  final RegExp devDepsHeader = RegExp(
    r'^dev_dependencies:\s*$',
    multiLine: true,
  );
  final Match? devMatch = devDepsHeader.firstMatch(content);

  if (devMatch == null) return null;

  // Find the section boundaries
  final String afterDevDeps = content.substring(devMatch.end);
  final Match? nextSection = _topLevelKeyPattern.firstMatch(afterDevDeps);
  final String devSection = nextSection != null
      ? afterDevDeps.substring(0, nextSection.start)
      : afterDevDeps;

  // Match the dependency line within dev_dependencies
  final RegExp depLine = RegExp(
    '^\\ +${RegExp.escape(packageName)}:[^\\n]*\\n?',
    multiLine: true,
  );

  if (!depLine.hasMatch(devSection)) return null;

  // Remove only within the dev_dependencies section
  final String cleanedSection = devSection.replaceAll(depLine, '');
  final String before = content.substring(0, devMatch.end);
  final String after = nextSection != null
      ? afterDevDeps.substring(nextSection.start)
      : '';

  return '$before$cleanedSection$after';
}

/// Converts v4 ignore comments to v5 format in .dart files.
///
/// Changes `// ignore: rule_name` to `// ignore: saropa_lints/rule_name`.
/// Only converts rules that exist in [allRules].
/// Returns a map of file path to number of conversions made.
Map<String, int> _convertIgnoreComments(Set<String> allRules, bool dryRun) {
  final Map<String, int> results = <String, int>{};

  for (final String dirName in const ['lib', 'test', 'bin']) {
    final Directory dir = Directory(dirName);
    if (!dir.existsSync()) continue;

    for (final FileSystemEntity entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final int count = _convertIgnoreCommentsInFile(entity, allRules, dryRun);
      if (count > 0) {
        results[entity.path] = count;
      }
    }
  }

  return results;
}

/// Matches a full ignore directive: `// ignore: rule_a, rule_b, rule_c`
/// or `// ignore_for_file: rule_a, rule_b`.
final RegExp _ignoreDirectivePattern = RegExp(
  r'(//\s*ignore(?:_for_file)?\s*:\s*)([\w_/,\s]+)',
);

/// Converts ignore comments in a single file. Returns count of conversions.
///
/// Handles multi-rule ignore comments like `// ignore: a, b, c`.
int _convertIgnoreCommentsInFile(File file, Set<String> allRules, bool dryRun) {
  final String content = file.readAsStringSync();
  int count = 0;

  final String newContent = content.replaceAllMapped(_ignoreDirectivePattern, (
    Match match,
  ) {
    final String prefix = match.group(1)!;
    final String ruleList = match.group(2)!;

    final String converted = ruleList.splitMapJoin(
      RegExp(r'[\w_/]+'),
      onMatch: (Match m) {
        final String name = m.group(0)!;
        if (name.startsWith('saropa_lints/')) return name;
        if (allRules.contains(name)) {
          count++;
          return 'saropa_lints/$name';
        }
        return name;
      },
    );

    return '$prefix$converted';
  });

  if (count > 0 && !dryRun) {
    file.writeAsStringSync(newContent);
  }

  return count;
}

/// Extract rule overrides from analysis_options_custom.yaml.
///
/// Supports multiple formats:
/// ```yaml
/// # Custom rule overrides (survives --reset)
/// avoid_print: false  # Allow print in this project
/// - avoid_null_assertion: false # With hyphen prefix
///   - require_error_widget: false # Indented with hyphen
/// prefer_const_constructors: true
/// ```
///
/// These overrides are always applied, even when using --reset.
Map<String, bool> _extractOverridesFromFile(File file, Set<String> allRules) {
  final Map<String, bool> overrides = <String, bool>{};

  if (!file.existsSync()) {
    return overrides;
  }

  final content = file.readAsStringSync();

  // Match rule entries with optional hyphen, indentation, and trailing comments:
  // - rule_name: true/false # optional comment
  //   rule_name: true/false
  // rule_name: false
  final rulePattern = RegExp(
    r'^\s*-?\s*([\w_]+):\s*(true|false)',
    multiLine: true,
  );

  for (final match in rulePattern.allMatches(content)) {
    final ruleName = match.group(1)!;
    final enabled = match.group(2) == 'true';

    // Only include rules we know about
    if (allRules.contains(ruleName)) {
      overrides[ruleName] = enabled;
    }
  }

  return overrides;
}

/// Create the analysis_options_custom.yaml file with a helpful header.
///
/// Includes the STYLISTIC RULES section with all opinionated rules
/// defaulting to false, organized by category.
void _createCustomOverridesFile(File file) {
  final stylisticSection = _buildStylisticSection();
  final packageSection = _buildPackageSection();

  final content =
      '''
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                    SAROPA LINTS CUSTOM CONFIG                             ║
# ║                                                                           ║
# ║  Settings in this file are ALWAYS applied, even when using --reset.      ║
# ║  Use this for project-specific customizations that should persist.       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────────────────────
# ANALYSIS SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
#
# max_issues: Maximum non-ERROR issues shown in the Problems tab.
#   After this limit, rules keep running but remaining issues go to the
#   report log only (reports/<timestamp>_saropa_lint_report.log).
#   - Default: 500
#   - Set to 0 for unlimited (all issues in Problems tab)
#   - Override per-run: SAROPA_LINTS_MAX=200 dart analyze
#
# output: Where violations are sent.
#   - "both"  (default) — Problems tab + report file
#   - "file"  — Report file only (nothing in Problems tab)
#   - Override per-run: SAROPA_LINTS_OUTPUT=file dart analyze

max_issues: 500
output: both

# ─────────────────────────────────────────────────────────────────────────────
# PLATFORM SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
# Disable platforms your project doesn't target.
# Rules specific to disabled platforms will be automatically disabled.
# Only ios and android are enabled by default.
#
# EXAMPLES:
#   - Web-only project: set ios, android, macos, windows, linux to false; web to true
#   - All platforms: set all to true
#   - Desktop app: set macos, windows, linux to true

platforms:
  ios: true
  android: true
  macos: false
  web: false
  windows: false
  linux: false

$packageSection$stylisticSection# ─────────────────────────────────────────────────────────────────────────────
# RULE OVERRIDES
# ─────────────────────────────────────────────────────────────────────────────
# FORMAT: rule_name: true/false
#
# EXAMPLES:
#   - avoid_print: false                # Allow print statements
#   - avoid_null_assertion: false       # Allow ! operator
#   - prefer_const_constructors: true   # Force-enable regardless of tier
#
# Add your custom rule overrides below:

''';

  file.writeAsStringSync(content);
}

/// Ensure max_issues setting exists in an existing custom config file.
///
/// Added in v4.9.1 - older files won't have this setting, so we add it
/// at the top of the file if missing.
void _ensureMaxIssuesSetting(File file) {
  var content = file.readAsStringSync();

  final hasMaxIssues = RegExp(
    r'^max_issues:\s*\d+',
    multiLine: true,
  ).hasMatch(content);
  final hasOutput = RegExp(
    r'^output:\s*\w+',
    multiLine: true,
  ).hasMatch(content);

  if (hasMaxIssues && hasOutput) return; // Both settings present

  if (!hasMaxIssues) {
    // Neither setting exists — add the full block
    content = _addAnalysisSettingsBlock(content);
    file.writeAsStringSync(content);
    _logTerminal(
      '${_Colors.green}✓ Added analysis settings to ${file.path}${_Colors.reset}',
    );
    return;
  }

  // max_issues exists but output is missing — add output after max_issues
  if (!hasOutput) {
    content = _addOutputSetting(content);
    file.writeAsStringSync(content);
    _logTerminal(
      '${_Colors.green}✓ Added output setting to ${file.path}${_Colors.reset}',
    );
  }
}

/// Add the full analysis settings block (max_issues + output).
String _addAnalysisSettingsBlock(String content) {
  final settingBlock = '''
# ─────────────────────────────────────────────────────────────────────────────
# ANALYSIS SETTINGS (added in v4.9.1, updated v4.12.2)
# ─────────────────────────────────────────────────────────────────────────────
#
# max_issues: Maximum non-ERROR issues shown in the Problems tab.
#   After this limit, rules keep running but remaining issues go to the
#   report log only (reports/<timestamp>_saropa_lint_report.log).
#   - Default: 500
#   - Set to 0 for unlimited (all issues in Problems tab)
#   - Override per-run: SAROPA_LINTS_MAX=200 dart analyze
#
# output: Where violations are sent.
#   - "both"  (default) — Problems tab + report file
#   - "file"  — Report file only (nothing in Problems tab)
#   - Override per-run: SAROPA_LINTS_OUTPUT=file dart analyze

max_issues: 500
output: both

''';

  final headerEndMatch = RegExp(r'╚[═]+╝\n*').firstMatch(content);

  if (headerEndMatch != null) {
    final insertPos = headerEndMatch.end;
    return content.substring(0, insertPos) +
        '\n' +
        settingBlock +
        content.substring(insertPos);
  }

  return settingBlock + content;
}

/// Add just the output setting after an existing max_issues line.
String _addOutputSetting(String content) {
  final maxIssuesMatch = RegExp(
    r'^(max_issues:\s*\d+.*)\n',
    multiLine: true,
  ).firstMatch(content);

  if (maxIssuesMatch == null) return content;

  final insertPos = maxIssuesMatch.end;
  const outputBlock = '''
# output: Where violations are sent.
#   - "both"  (default) — Problems tab + report file
#   - "file"  — Report file only (nothing in Problems tab)
#   - Override per-run: SAROPA_LINTS_OUTPUT=file dart analyze
output: both

''';

  return content.substring(0, insertPos) +
      outputBlock +
      content.substring(insertPos);
}

/// Ensure platforms setting exists in an existing custom config file.
///
/// Older files won't have this setting, so we add it after the
/// max_issues setting if missing.
void _ensurePlatformsSetting(File file) {
  final content = file.readAsStringSync();

  // Check if platforms section already exists
  if (RegExp(r'^platforms:', multiLine: true).hasMatch(content)) {
    return; // Already has the setting
  }

  const settingBlock = '''
# ─────────────────────────────────────────────────────────────────────────────
# PLATFORM SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
# Disable platforms your project doesn't target.
# Only ios and android are enabled by default.

platforms:
  ios: true
  android: true
  macos: false
  web: false
  windows: false
  linux: false

''';

  // Insert after max_issues line if present, else after header
  final maxIssuesMatch = RegExp(r'max_issues:\s*\d+\n*').firstMatch(content);
  String newContent;

  if (maxIssuesMatch != null) {
    final insertPos = maxIssuesMatch.end;
    newContent =
        content.substring(0, insertPos) +
        '\n' +
        settingBlock +
        content.substring(insertPos);
  } else {
    final headerEndMatch = RegExp(r'╚[═]+╝\n*').firstMatch(content);
    if (headerEndMatch != null) {
      final insertPos = headerEndMatch.end;
      newContent =
          content.substring(0, insertPos) +
          '\n' +
          settingBlock +
          content.substring(insertPos);
    } else {
      newContent = settingBlock + content;
    }
  }

  file.writeAsStringSync(newContent);
  _logTerminal(
    '${_Colors.green}✓ Added platforms setting to ${file.path}${_Colors.reset}',
  );
}

/// Ensure packages setting exists in an existing custom config file.
///
/// Older files won't have this setting, so we add it after the
/// platforms setting if missing.
void _ensurePackagesSetting(File file) {
  final content = file.readAsStringSync();

  // Check if packages section already exists
  if (RegExp(r'^packages:', multiLine: true).hasMatch(content)) {
    return; // Already has the setting
  }

  final packageEntries = tiers.allPackages
      .map((p) => '  $p: ${tiers.defaultPackages[p]}')
      .join('\n');

  final settingBlock =
      '''
# ─────────────────────────────────────────────────────────────────────────────
# PACKAGE SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
# Disable packages your project doesn't use.
# Rules specific to disabled packages will be automatically disabled.
# All packages are enabled by default for backward compatibility.
#
# EXAMPLES:
#   - Riverpod-only project: set bloc, provider, getx to false
#   - No local DB: set isar, hive, sqflite to false
#   - No Firebase: set firebase to false

packages:
$packageEntries

''';

  // Insert after platforms section if present
  final platformsEndMatch = RegExp(
    r'^platforms:\s*\n(?:\s+\w+:\s*(?:true|false)\s*\n)*',
    multiLine: true,
  ).firstMatch(content);

  String newContent;

  if (platformsEndMatch != null) {
    final insertPos = platformsEndMatch.end;
    newContent =
        content.substring(0, insertPos) +
        '\n' +
        settingBlock +
        content.substring(insertPos);
  } else {
    // Fallback: insert after max_issues
    final maxIssuesMatch = RegExp(r'max_issues:\s*\d+\n*').firstMatch(content);
    if (maxIssuesMatch != null) {
      final insertPos = maxIssuesMatch.end;
      newContent =
          content.substring(0, insertPos) +
          '\n' +
          settingBlock +
          content.substring(insertPos);
    } else {
      newContent = settingBlock + content;
    }
  }

  file.writeAsStringSync(newContent);
  _logTerminal(
    '${_Colors.green}✓ Added packages setting to ${file.path}${_Colors.reset}',
  );
}

/// Builds the PACKAGE SETTINGS section for analysis_options_custom.yaml.
String _buildPackageSection() {
  final buffer = StringBuffer();
  buffer.writeln(
    '# ─────────────────────────────────────────────────────────────────────────────',
  );
  buffer.writeln('# PACKAGE SETTINGS');
  buffer.writeln(
    '# ─────────────────────────────────────────────────────────────────────────────',
  );
  buffer.writeln("# Disable packages your project doesn't use.");
  buffer.writeln(
    '# Rules specific to disabled packages will be automatically disabled.',
  );
  buffer.writeln(
    '# All packages are enabled by default for backward compatibility.',
  );
  buffer.writeln('#');
  buffer.writeln('# EXAMPLES:');
  buffer.writeln(
    '#   - Riverpod-only project: set bloc, provider, getx to false',
  );
  buffer.writeln('#   - No local DB: set isar, hive, sqflite to false');
  buffer.writeln('#   - No Firebase: set firebase to false');
  buffer.writeln('');
  buffer.writeln('packages:');
  for (final package in tiers.allPackages) {
    final enabled = tiers.defaultPackages[package] ?? true;
    buffer.writeln('  $package: $enabled');
  }
  buffer.writeln('');
  return buffer.toString();
}

/// Builds the STYLISTIC RULES section content for analysis_options_custom.yaml.
///
/// Lists all stylistic rules organized by category with problem message
/// comments. Preserves existing true/false values from [existingValues].
/// Preserves [reviewed] markers from [reviewedRules].
/// Skips rules in [skipRules] (found elsewhere in the file).
/// New rules default to `false`.
String _buildStylisticSection({
  Map<String, bool> existingValues = const <String, bool>{},
  Set<String> reviewedRules = const <String>{},
  Set<String> skipRules = const <String>{},
}) {
  final buffer = StringBuffer();
  buffer.writeln(
    '# ─────────────────────────────────────────────────────────────────────────────',
  );
  buffer.writeln('# STYLISTIC RULES');
  buffer.writeln(
    '# ─────────────────────────────────────────────────────────────────────────────',
  );
  // ┌─────────────────────────────────────────────────────────────────────────┐
  // │ IMPORTANT: The [reviewed] markers below track interactive walkthrough  │
  // │ progress. Do NOT remove them — they prevent re-prompting users for     │
  // │ rules they've already decided on. Use --reset-stylistic to clear all   │
  // │ markers and start the walkthrough from scratch.                        │
  // └─────────────────────────────────────────────────────────────────────────┘
  buffer.writeln(
    '# Opinionated formatting, ordering, and naming convention rules.',
  );
  buffer.writeln(
    '# These are NOT included in any tier - enable the ones that match your style.',
  );
  buffer.writeln('# Set to true to enable, false to disable.');
  buffer.writeln('#');
  buffer.writeln('# NOTE: Some rules conflict (e.g., prefer_single_quotes vs');
  buffer.writeln(
    '# prefer_double_quotes). Only enable one from each conflicting group.',
  );
  buffer.writeln('#');
  buffer.writeln(
    '# [reviewed] markers track walkthrough progress. Do NOT remove them.',
  );
  buffer.writeln(
    '# Use --reset-stylistic to clear markers and re-review all rules.',
  );
  buffer.writeln('');

  final categorizedRules = <String>{};

  for (final entry in _stylisticRuleCategories.entries) {
    final category = entry.key;
    final rules = entry.value;

    // Filter out rules not in tiers.stylisticRules (prevents stale entries)
    // and skip rules already in RULE OVERRIDES section
    final activeRules = rules
        .where((r) => tiers.stylisticRules.contains(r))
        .where((r) => !skipRules.contains(r))
        .toList();
    if (activeRules.isEmpty) continue;

    buffer.writeln('# --- $category ---');
    for (final rule in activeRules) {
      final enabled = existingValues[rule] ?? false;
      final msg = _getStylisticDescription(rule);
      final reviewed = reviewedRules.contains(rule);
      final marker = reviewed ? ' [reviewed]' : '';
      final comment = msg.isNotEmpty ? '  #$marker $msg' : '';
      buffer.writeln('$rule: $enabled$comment');
      categorizedRules.add(rule);
    }
    buffer.writeln('');
  }

  // Add any uncategorized stylistic rules (safety net for new rules)
  final uncategorized =
      tiers.stylisticRules
          .difference(categorizedRules)
          .difference(skipRules)
          .toList()
        ..sort();

  if (uncategorized.isNotEmpty) {
    buffer.writeln('# --- Other stylistic rules ---');
    for (final rule in uncategorized) {
      final enabled = existingValues[rule] ?? false;
      final msg = _getStylisticDescription(rule);
      final reviewed = reviewedRules.contains(rule);
      final marker = reviewed ? ' [reviewed]' : '';
      final comment = msg.isNotEmpty ? '  #$marker $msg' : '';
      buffer.writeln('$rule: $enabled$comment');
    }
    buffer.writeln('');
  }

  return buffer.toString();
}

/// Regex matching the STYLISTIC RULES section header.
final RegExp _stylisticSectionHeader = RegExp(
  r'# STYLISTIC RULES\s*\n',
  multiLine: true,
);

/// Regex matching the RULE OVERRIDES section header.
final RegExp _ruleOverridesSectionHeader = RegExp(
  r'# RULE OVERRIDES\s*\n',
  multiLine: true,
);

/// Ensure stylistic rules section exists and is complete in the custom
/// config file. Adds missing rules, preserves existing true/false values.
/// Skips rules that appear in the RULE OVERRIDES section.
void _ensureStylisticRulesSection(File file) {
  var content = file.readAsStringSync();

  // Find stylistic rules in the RULE OVERRIDES section (to skip them)
  final overrideValues = _extractOverrideSectionValues(content);
  var skipRules = overrideValues.keys.toSet().intersection(
    tiers.stylisticRules,
  );

  // Check if STYLISTIC RULES section exists
  final sectionMatch = _stylisticSectionHeader.firstMatch(content);

  if (sectionMatch == null) {
    _insertNewStylisticSection(file, content, skipRules);
    return;
  }

  // Section exists - parse existing values and reviewed markers
  final existingValues = _extractStylisticSectionValues(content);
  final reviewedRules = _extractReviewedRules(content);

  // Clean up obsolete rules no longer in tiers.stylisticRules
  _logRemovedStylisticRules(content);

  // Offer to move stylistic rules from RULE OVERRIDES to STYLISTIC section
  final moveResult = _promptMoveOverridesToStylistic(
    content,
    skipRules,
    overrideValues,
    existingValues,
  );
  content = moveResult.content;
  skipRules = moveResult.skipRules;

  // Rebuild the section with current rules, preserved values and markers
  final newSection = _buildStylisticSection(
    existingValues: existingValues,
    reviewedRules: reviewedRules,
    skipRules: skipRules,
  );

  final sectionStart = _findStylisticSectionStart(content);
  final sectionEnd = _findStylisticSectionEnd(content, sectionStart);

  final newContent =
      content.substring(0, sectionStart) +
      newSection +
      content.substring(sectionEnd);

  file.writeAsStringSync(newContent);
}

/// Insert a new STYLISTIC RULES section when none exists yet.
void _insertNewStylisticSection(
  File file,
  String content,
  Set<String> skipRules,
) {
  final newSection = _buildStylisticSection(skipRules: skipRules);
  final insertContent = '\n$newSection';

  // Find insertion point: before RULE OVERRIDES header
  final overridesHeaderMatch = RegExp(
    r'# ─+\n# RULE OVERRIDES',
    multiLine: true,
  ).firstMatch(content);

  String newContent;

  if (overridesHeaderMatch != null) {
    newContent =
        content.substring(0, overridesHeaderMatch.start) +
        insertContent +
        content.substring(overridesHeaderMatch.start);
  } else {
    newContent = content + insertContent;
  }

  file.writeAsStringSync(newContent);
  _logTerminal(
    '${_Colors.green}✓ Added stylistic rules section to ${file.path}${_Colors.reset}',
  );
}

/// Log warnings about obsolete stylistic rules being cleaned up during
/// section rebuild. Enabled rules get a yellow warning; disabled ones
/// get a dim info message.
void _logRemovedStylisticRules(String content) {
  final removedRules = _extractRemovedStylisticRules(content);

  if (removedRules.isEmpty) return;

  final enabledRemoved =
      removedRules.entries.where((e) => e.value).map((e) => e.key).toList()
        ..sort();
  final disabledRemoved =
      removedRules.entries.where((e) => !e.value).map((e) => e.key).toList()
        ..sort();

  if (enabledRemoved.isNotEmpty) {
    _logTerminal(
      '${_Colors.yellow}⚠ Removing ${enabledRemoved.length} obsolete '
      'stylistic rule(s) that were enabled:${_Colors.reset}',
    );
    for (final rule in enabledRemoved) {
      _logTerminal('${_Colors.dim}  - $rule${_Colors.reset}');
    }
  }

  if (disabledRemoved.isNotEmpty) {
    _logTerminal(
      '${_Colors.dim}  Cleaned up ${disabledRemoved.length} obsolete '
      'disabled stylistic rule(s)${_Colors.reset}',
    );
  }
}

/// Prompt the user to move stylistic rules from RULE OVERRIDES into the
/// STYLISTIC RULES section. Returns updated content and skipRules.
({String content, Set<String> skipRules}) _promptMoveOverridesToStylistic(
  String content,
  Set<String> skipRules,
  Map<String, bool> overrideValues,
  Map<String, bool> existingValues,
) {
  if (skipRules.isEmpty) {
    return (content: content, skipRules: skipRules);
  }

  _logTerminal('');
  _logTerminal(
    '${_Colors.yellow}Found ${skipRules.length} stylistic rule(s) '
    'in RULE OVERRIDES section:${_Colors.reset}',
  );
  for (final rule in skipRules.toList()..sort()) {
    _logTerminal('${_Colors.dim}  - $rule${_Colors.reset}');
  }

  bool shouldMove = false;

  if (stdin.hasTerminal) {
    stdout.write(
      '${_Colors.cyan}Move to STYLISTIC RULES section? [y/N]: '
      '${_Colors.reset}',
    );
    final response = stdin.readLineSync()?.toLowerCase().trim() ?? '';
    shouldMove = response == 'y' || response == 'yes';
  } else {
    _logTerminal(
      '${_Colors.dim}  Non-interactive: keeping in RULE OVERRIDES'
      '${_Colors.reset}',
    );
  }

  if (!shouldMove) {
    return (content: content, skipRules: skipRules);
  }

  final movedCount = skipRules.length;
  final movedValues = Map<String, bool>.fromEntries(
    overrideValues.entries.where((e) => skipRules.contains(e.key)),
  );
  final updatedContent = _removeRulesFromOverridesSection(content, skipRules);
  existingValues.addAll(movedValues);
  _logTerminal(
    '${_Colors.green}✓ Moved $movedCount rule(s) to '
    'STYLISTIC RULES section${_Colors.reset}',
  );

  return (content: updatedContent, skipRules: <String>{});
}

/// Find the start of the STYLISTIC RULES section (including the divider).
int _findStylisticSectionStart(String content) {
  // Look for the divider line before "# STYLISTIC RULES"
  final match = RegExp(
    r'# ─+\n# STYLISTIC RULES',
    multiLine: true,
  ).firstMatch(content);
  return match?.start ?? content.length;
}

/// Find the end of the STYLISTIC RULES section.
/// Ends at the next section divider or end of file.
int _findStylisticSectionEnd(String content, int sectionStart) {
  // Find the next section header (─── divider) after the STYLISTIC RULES
  // header itself. Skip the first two divider lines (the section's own header).
  final afterHeader = content.indexOf('\n', sectionStart);

  if (afterHeader == -1) return content.length;

  // Skip past the "# STYLISTIC RULES" line and its closing divider
  final afterSectionHeader = _stylisticSectionHeader.firstMatch(
    content.substring(afterHeader),
  );
  final searchFrom = afterSectionHeader != null
      ? afterHeader + afterSectionHeader.end
      : afterHeader;

  final nextDivider = RegExp(
    r'\n# ─+\n# ',
    multiLine: true,
  ).firstMatch(content.substring(searchFrom));

  if (nextDivider != null) {
    return searchFrom + nextDivider.start + 1; // +1 for the leading \n
  }

  return content.length;
}

/// Extract rule name → enabled values from the STYLISTIC RULES section only.
Map<String, bool> _extractStylisticSectionValues(String content) {
  final values = <String, bool>{};

  final sectionStart = _findStylisticSectionStart(content);
  final sectionEnd = _findStylisticSectionEnd(content, sectionStart);
  final sectionContent = content.substring(sectionStart, sectionEnd);

  final rulePattern = RegExp(r'^([\w_]+):\s*(true|false)', multiLine: true);

  for (final match in rulePattern.allMatches(sectionContent)) {
    final ruleName = match.group(1)!;
    final enabled = match.group(2) == 'true';
    if (tiers.stylisticRules.contains(ruleName)) {
      values[ruleName] = enabled;
    }
  }

  return values;
}

/// Extract rule names that have the [reviewed] marker in their comment.
///
/// Reviewed markers track which stylistic rules the user has already
/// decided on during the interactive walkthrough. Rules without [reviewed]
/// will be re-prompted on the next `init` run.
///
/// Marker format: `rule_name: true  # [reviewed] description`
Set<String> _extractReviewedRules(String content) {
  final reviewed = <String>{};

  final sectionStart = _findStylisticSectionStart(content);
  final sectionEnd = _findStylisticSectionEnd(content, sectionStart);
  final sectionContent = content.substring(sectionStart, sectionEnd);

  // Match lines like: rule_name: true/false  # [reviewed] ...
  final reviewedPattern = RegExp(
    r'^([\w_]+):\s*(?:true|false)\s*#.*\[reviewed\]',
    multiLine: true,
  );

  for (final match in reviewedPattern.allMatches(sectionContent)) {
    final ruleName = match.group(1)!;
    if (tiers.stylisticRules.contains(ruleName)) {
      reviewed.add(ruleName);
    }
  }

  return reviewed;
}

/// Strip all [reviewed] markers from the STYLISTIC RULES section only.
/// Used by --reset-stylistic to force re-walkthrough of all rules.
/// Scoped to the section to avoid stripping the text from user comments
/// in other sections.
String _stripReviewedMarkers(String content) {
  final sectionStart = _findStylisticSectionStart(content);
  final sectionEnd = _findStylisticSectionEnd(content, sectionStart);

  final before = content.substring(0, sectionStart);
  final section = content.substring(sectionStart, sectionEnd);
  final after = content.substring(sectionEnd);

  return before + section.replaceAll(RegExp(r' \[reviewed\]'), '') + after;
}

/// Extract rules from the STYLISTIC RULES section that no longer exist in
/// [tiers.stylisticRules]. Returns a map of removed rule name to its
/// enabled/disabled value so we can warn if user-enabled rules are dropped.
Map<String, bool> _extractRemovedStylisticRules(String content) {
  final removed = <String, bool>{};

  final sectionStart = _findStylisticSectionStart(content);
  final sectionEnd = _findStylisticSectionEnd(content, sectionStart);
  final sectionContent = content.substring(sectionStart, sectionEnd);

  final rulePattern = RegExp(r'^([\w_]+):\s*(true|false)', multiLine: true);

  for (final match in rulePattern.allMatches(sectionContent)) {
    final ruleName = match.group(1)!;
    final enabled = match.group(2) == 'true';
    if (!tiers.stylisticRules.contains(ruleName)) {
      removed[ruleName] = enabled;
    }
  }

  return removed;
}

/// Extract all rule name → enabled/disabled values from the RULE OVERRIDES
/// section. Returns empty map if the section doesn't exist.
Map<String, bool> _extractOverrideSectionValues(String content) {
  final values = <String, bool>{};

  final sectionMatch = _ruleOverridesSectionHeader.firstMatch(content);

  if (sectionMatch == null) return values;

  // Content after the RULE OVERRIDES header until end of file
  // (it's the last section)
  final afterSection = content.substring(sectionMatch.end);

  final rulePattern = RegExp(r'^([\w_]+):\s*(true|false)', multiLine: true);

  for (final match in rulePattern.allMatches(afterSection)) {
    values[match.group(1)!] = match.group(2) == 'true';
  }

  return values;
}

/// Remove specific rules from the RULE OVERRIDES section.
/// Returns the modified content string.
String _removeRulesFromOverridesSection(
  String content,
  Set<String> rulesToRemove,
) {
  final sectionMatch = _ruleOverridesSectionHeader.firstMatch(content);

  if (sectionMatch == null) return content;

  // Only modify content after the RULE OVERRIDES header
  final before = content.substring(0, sectionMatch.end);
  var after = content.substring(sectionMatch.end);

  for (final rule in rulesToRemove) {
    // Remove the line: "rule_name: true/false" with optional comment/newline
    after = after.replaceAll(
      RegExp('^$rule:\\s*(true|false).*\\n?', multiLine: true),
      '',
    );
  }

  return before + after;
}

/// Extract platform settings from analysis_options_custom.yaml.
///
/// Returns a map of platform name to enabled status.
/// Defaults to [tiers.defaultPlatforms] if not specified (ios and android
/// enabled, others disabled).
///
/// Supports format:
/// ```yaml
/// platforms:
///   ios: true
///   android: false
///   web: true
/// ```
Map<String, bool> _extractPlatformsFromFile(File file) {
  final Map<String, bool> platforms = Map<String, bool>.of(
    tiers.defaultPlatforms,
  );

  if (!file.existsSync()) return platforms;

  final content = file.readAsStringSync();

  // Find the platforms: section
  final sectionMatch = RegExp(
    r'^platforms:\s*$',
    multiLine: true,
  ).firstMatch(content);

  if (sectionMatch == null) return platforms;

  // Extract indented entries after platforms:
  final afterSection = content.substring(sectionMatch.end);

  final platformPattern = RegExp(
    r'^\s+(ios|android|macos|web|windows|linux):\s*(true|false)',
    multiLine: true,
  );

  for (final match in platformPattern.allMatches(afterSection)) {
    // Stop if we hit a non-indented line (next section)
    final beforeMatch = afterSection.substring(0, match.start);
    if (RegExp(r'^\S', multiLine: true).hasMatch(beforeMatch)) break;

    final name = match.group(1)!;
    final enabled = match.group(2) == 'true';
    platforms[name] = enabled;
  }

  return platforms;
}

/// Extract package settings from analysis_options_custom.yaml.
///
/// Returns a map of package name to enabled status.
/// Defaults to [tiers.defaultPackages] if not specified (all enabled).
///
/// Supports format:
/// ```yaml
/// packages:
///   bloc: true
///   riverpod: false
///   firebase: true
/// ```
Map<String, bool> _extractPackagesFromFile(File file) {
  final Map<String, bool> packages = Map<String, bool>.of(
    tiers.defaultPackages,
  );

  if (!file.existsSync()) return packages;

  final content = file.readAsStringSync();

  // Find the packages: section
  final sectionMatch = RegExp(
    r'^packages:\s*$',
    multiLine: true,
  ).firstMatch(content);

  if (sectionMatch == null) return packages;

  // Extract indented entries after packages:
  final afterSection = content.substring(sectionMatch.end);

  final packagePattern = RegExp(
    r'^\s+([\w_]+):\s*(true|false)',
    multiLine: true,
  );

  for (final match in packagePattern.allMatches(afterSection)) {
    // Stop if we hit a non-indented line (next section)
    final beforeMatch = afterSection.substring(0, match.start);
    if (RegExp(r'^\S', multiLine: true).hasMatch(beforeMatch)) break;

    final name = match.group(1)!;
    final enabled = match.group(2) == 'true';

    // Only include packages we know about
    if (tiers.defaultPackages.containsKey(name)) {
      packages[name] = enabled;
    }
  }

  return packages;
}

/// Generate the plugins YAML section with proper formatting.
///
/// Organizes rules by tier with problem message comments.
String _generatePluginsYaml({
  required String tier,
  required String packageVersion,
  required Set<String> enabledRules,
  required Set<String> disabledRules,
  required Map<String, bool> userCustomizations,
  required Set<String> allRules,
  required bool includeStylistic,
  required Map<String, bool> platformSettings,
  required Map<String, bool> packageSettings,
}) {
  final StringBuffer buffer = StringBuffer();
  final customizedRuleNames = userCustomizations.keys.toSet();

  buffer.writeln('plugins:');
  buffer.writeln('  saropa_lints:');
  // version: is REQUIRED — without it the Dart analyzer silently ignores
  // the plugin and dart analyze reports zero issues.
  if (packageVersion != 'unknown') {
    buffer.writeln('    version: "$packageVersion"');
  } else {
    buffer.writeln('    # version: unknown — run dart pub get to resolve');
  }
  buffer.writeln(
    '    # ═══════════════════════════════════════════════════════════════════',
  );
  buffer.writeln('    # SAROPA LINTS CONFIGURATION');
  buffer.writeln(
    '    # ═══════════════════════════════════════════════════════════════════',
  );
  buffer.writeln(
    '    # Regenerate with: dart run saropa_lints:init --tier $tier',
  );
  buffer.writeln(
    '    # Tier: $tier (${enabledRules.length} of ${allRules.length} rules enabled)',
  );
  buffer.writeln(
    '    # Lint rules are disabled by default. Set to true to enable.',
  );
  buffer.writeln(
    '    # User customizations are preserved unless --reset is used',
  );
  buffer.writeln('    #');
  buffer.writeln('    # Tiers (cumulative):');
  buffer.writeln(
    '    #   1. essential    - Critical: crashes, security, memory leaks',
  );
  buffer.writeln(
    '    #   2. recommended  - Essential + accessibility, performance',
  );
  buffer.writeln(
    '    #   3. professional - Recommended + architecture, testing',
  );
  buffer.writeln('    #   4. comprehensive - Professional + thorough coverage');
  buffer.writeln(
    '    #   5. pedantic     - All rules (pedantic, highly opinionated)',
  );
  buffer.writeln(
    '    #   +  stylistic    - Opt-in only (formatting, ordering)',
  );
  buffer.writeln('    #');

  // Show platform status
  final disabledPlatforms = platformSettings.entries
      .where((e) => !e.value)
      .map((e) => e.key)
      .toList();

  if (disabledPlatforms.isNotEmpty) {
    buffer.writeln('    # Disabled platforms: ${disabledPlatforms.join(', ')}');
    buffer.writeln('    #');
  }

  // Show package status
  final disabledPackages = packageSettings.entries
      .where((e) => !e.value)
      .map((e) => e.key)
      .toList();

  if (disabledPackages.isNotEmpty) {
    buffer.writeln('    # Disabled packages: ${disabledPackages.join(', ')}');
    buffer.writeln('    #');
  }

  buffer.writeln(
    '    # Settings (max_issues, platforms, packages) are in analysis_options_custom.yaml',
  );
  buffer.writeln(
    '    # ═══════════════════════════════════════════════════════════════════',
  );
  buffer.writeln('');
  buffer.writeln('    diagnostics:');

  // Section 1: User customizations (always at top, preserved)
  if (userCustomizations.isNotEmpty) {
    buffer.writeln(_sectionHeader('USER CUSTOMIZATIONS', '~'));
    buffer.writeln(
      '      # These rules have been manually configured and will be preserved',
    );
    buffer.writeln(
      '      # when regenerating. Use --reset to discard these customizations.',
    );
    buffer.writeln('');

    final List<String> sortedCustomizations = userCustomizations.keys.toList()
      ..sort();
    for (final String rule in sortedCustomizations) {
      final bool enabled = userCustomizations[rule]!;
      final String msg = _getProblemMessage(rule);
      final String severity = _getRuleSeverity(rule);
      buffer.writeln('      $rule: $enabled  # [$severity] $msg');
    }
    buffer.writeln('');
  }

  // Group rules by their tier
  final Map<RuleTier, List<String>> enabledByTier = {};
  final Map<RuleTier, List<String>> disabledByTier = {};

  for (final tier in RuleTier.values) {
    enabledByTier[tier] = [];
    disabledByTier[tier] = [];
  }

  // Categorize enabled rules by tier
  for (final String rule in enabledRules.difference(customizedRuleNames)) {
    final ruleTier = _getRuleTierFromMetadata(rule);
    enabledByTier[ruleTier]!.add(rule);
  }

  // Categorize disabled rules by tier
  for (final String rule in disabledRules.difference(customizedRuleNames)) {
    final ruleTier = _getRuleTierFromMetadata(rule);
    disabledByTier[ruleTier]!.add(rule);
  }

  // Section 2: Enabled rules organized by tier
  buffer.writeln(_sectionHeader('ENABLED RULES ($tier tier)', '='));
  buffer.writeln('');

  // Output enabled tiers in order
  for (final tierLevel in [
    RuleTier.essential,
    RuleTier.recommended,
    RuleTier.professional,
    RuleTier.comprehensive,
    RuleTier.pedantic,
  ]) {
    final rules = enabledByTier[tierLevel]!..sort();
    if (rules.isEmpty) continue;

    final tierName = _tierToString(tierLevel).toUpperCase();
    final tierNum = _tierIndex(tierLevel) + 1;
    buffer.writeln('      #');
    buffer.writeln(
      '      # --- TIER $tierNum: $tierName (${rules.length} rules) ---',
    );
    buffer.writeln('      #');
    for (final String rule in rules) {
      final String msg = _getProblemMessage(rule);
      final String severity = _getRuleSeverity(rule);
      buffer.writeln('      $rule: true  # [$severity] $msg');
    }
    buffer.writeln('');
  }

  // Section 3: Stylistic rules (separate section)
  final stylisticEnabled = enabledByTier[RuleTier.stylistic]!..sort();
  final stylisticDisabled = disabledByTier[RuleTier.stylistic]!..sort();

  if (stylisticEnabled.isNotEmpty || stylisticDisabled.isNotEmpty) {
    buffer.writeln(_sectionHeader('STYLISTIC RULES (opt-in)', '~'));
    buffer.writeln('      # Formatting, ordering, naming conventions.');
    buffer.writeln(
      '      # Enable with: dart run saropa_lints:init --tier <tier> --stylistic',
    );
    buffer.writeln('');

    if (stylisticEnabled.isNotEmpty) {
      buffer.writeln('      #');
      buffer.writeln(
        '      # ┌─────────────────────────────────────────────────────────────────┐',
      );
      buffer.writeln(
        '      # │  ✓ ENABLED STYLISTIC (${stylisticEnabled.length} rules)${' ' * (43 - stylisticEnabled.length.toString().length)}│',
      );
      buffer.writeln(
        '      # └─────────────────────────────────────────────────────────────────┘',
      );
      buffer.writeln('      #');
      for (final String rule in stylisticEnabled) {
        final String msg = _getProblemMessage(rule);
        buffer.writeln('      $rule: true  # $msg');
      }
      buffer.writeln('');
    }

    if (stylisticDisabled.isNotEmpty) {
      buffer.writeln('      #');
      buffer.writeln(
        '      # ┌─────────────────────────────────────────────────────────────────┐',
      );
      buffer.writeln(
        '      # │  ✗ DISABLED STYLISTIC (${stylisticDisabled.length} rules)${' ' * (42 - stylisticDisabled.length.toString().length)}│',
      );
      buffer.writeln(
        '      # └─────────────────────────────────────────────────────────────────┘',
      );
      buffer.writeln('      #');
      for (final String rule in stylisticDisabled) {
        final String msg = _getProblemMessage(rule);
        buffer.writeln('      $rule: false  # $msg');
      }
      buffer.writeln('');
    }
  }

  // Section 4: Disabled rules by tier (rules above selected tier)
  final hasDisabledNonStylistic = [
    RuleTier.essential,
    RuleTier.recommended,
    RuleTier.professional,
    RuleTier.comprehensive,
    RuleTier.pedantic,
  ].any((t) => disabledByTier[t]!.isNotEmpty);

  if (hasDisabledNonStylistic) {
    buffer.writeln(_sectionHeader('DISABLED RULES (above $tier tier)', '-'));
    buffer.writeln('      # These rules are in higher tiers. To enable:');
    buffer.writeln('      #   1. Choose a higher tier with --tier <tier>');
    buffer.writeln(
      '      #   2. Or manually set to true in USER CUSTOMIZATIONS above',
    );
    buffer.writeln('');

    // Output disabled tiers (from highest to lowest)
    for (final tierLevel in [
      RuleTier.pedantic,
      RuleTier.comprehensive,
      RuleTier.professional,
      RuleTier.recommended,
      RuleTier.essential,
    ]) {
      final rules = disabledByTier[tierLevel]!..sort();
      if (rules.isEmpty) continue;

      final tierName = _tierToString(tierLevel).toUpperCase();
      final tierNum = _tierIndex(tierLevel) + 1;
      buffer.writeln('      #');
      buffer.writeln(
        '      # ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐',
      );
      buffer.writeln(
        '      #   TIER $tierNum: $tierName (${rules.length} rules disabled)',
      );
      buffer.writeln(
        '      # └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘',
      );
      buffer.writeln('      #');
      for (final String rule in rules) {
        final String msg = _getProblemMessage(rule);
        final String severity = _getRuleSeverity(rule);
        buffer.writeln('      $rule: false  # [$severity] $msg');
      }
      buffer.writeln('');
    }
  }

  return buffer.toString();
}

/// Generate a clear, visible section header for YAML.
String _sectionHeader(String title, String char) {
  final String upperTitle = title.toUpperCase();
  const int width = 72;

  if (char == '=') {
    // ENABLED RULES - Double-line box
    return '''
      #
      # ${'═' * width}
      #   ✓ $upperTitle
      # ${'═' * width}
      #''';
  } else if (char == '~') {
    // STYLISTIC or USER CUSTOMIZATIONS - Wavy pattern
    return '''
      #
      # ${'~' * width}
      #   ◆ $upperTitle
      # ${'~' * width}
      #''';
  } else {
    // DISABLED RULES - Dashed pattern
    return '''
      #
      # ${'-' * width}
      #   ✗ $upperTitle
      # ${'-' * width}
      #''';
  }
}

/// Replace the plugins section in existing content, preserving everything else.
String _replacePluginsSection(String existingContent, String newPlugins) {
  if (existingContent.isEmpty) {
    return newPlugins;
  }

  // Find plugins: section
  final Match? customLintMatch = _pluginsSectionPattern.firstMatch(
    existingContent,
  );

  if (customLintMatch == null) {
    // No existing plugins section - append to end
    return '$existingContent\n$newPlugins';
  }

  // Find the end of the plugins section (next top-level key or end of file)
  final String beforePlugins = existingContent.substring(
    0,
    customLintMatch.start,
  );
  final String afterPluginsStart = existingContent.substring(
    customLintMatch.end,
  );

  // Find next top-level section (line starting with a word followed by colon, no indentation)
  final Match? nextSection = _topLevelKeyPattern.firstMatch(afterPluginsStart);

  final String afterPlugins = nextSection != null
      ? afterPluginsStart.substring(nextSection.start)
      : '';

  return '$beforePlugins$newPlugins\n$afterPlugins';
}

/// Struct for parsed CLI arguments.
class CliArgs {
  const CliArgs({
    required this.showHelp,
    required this.dryRun,
    required this.reset,
    required this.includeStylistic,
    required this.stylisticAll,
    required this.noStylistic,
    required this.resetStylistic,
    required this.fixIgnores,
    required this.outputPath,
    required this.tier,
  });

  final bool showHelp;
  final bool dryRun;
  final bool reset;

  /// --stylistic: triggers interactive walkthrough (was bulk-enable in v4).
  final bool includeStylistic;

  /// --stylistic-all: bulk-enable all stylistic rules (old --stylistic
  /// behavior, useful for CI/non-interactive).
  final bool stylisticAll;

  /// --no-stylistic: skip the stylistic walkthrough entirely.
  final bool noStylistic;

  /// --reset-stylistic: clear all [reviewed] markers and re-walkthrough.
  final bool resetStylistic;

  final bool fixIgnores;
  final String outputPath;
  final String? tier;
}

/// Parse CLI arguments into a struct.
CliArgs _parseArguments(List<String> args) {
  final bool showHelp = args.contains('--help') || args.contains('-h');
  final bool dryRun = args.contains('--dry-run');
  final bool reset = args.contains('--reset');
  final bool includeStylistic = args.contains('--stylistic');
  final bool stylisticAll = args.contains('--stylistic-all');
  final bool noStylistic = args.contains('--no-stylistic');
  final bool resetStylistic = args.contains('--reset-stylistic');
  final bool fixIgnores = args.contains('--fix-ignores');

  String outputPath = 'analysis_options.yaml';
  int outputIndex = args.indexOf('--output');

  if (outputIndex == -1) {
    outputIndex = args.indexOf('-o');
  }

  if (outputIndex != -1) {
    if (outputIndex + 1 < args.length &&
        !args[outputIndex + 1].startsWith('-')) {
      outputPath = args[outputIndex + 1];
    } else {
      print(
        'Warning: --output requires a file path. '
        'Using default: $outputPath',
      );
    }
  }

  String? requestedTier;
  int tierIndex = args.indexOf('--tier');

  if (tierIndex == -1) {
    tierIndex = args.indexOf('-t');
  }

  if (tierIndex != -1) {
    if (tierIndex + 1 < args.length && !args[tierIndex + 1].startsWith('-')) {
      requestedTier = args[tierIndex + 1];
    } else {
      // --tier without a value: warn and fall through to prompt/default
      print(
        'Warning: --tier requires a value (1-5 or tier name). '
        'Will prompt for selection.',
      );
    }
  }

  return CliArgs(
    showHelp: showHelp,
    dryRun: dryRun,
    reset: reset,
    includeStylistic: includeStylistic,
    stylisticAll: stylisticAll,
    noStylistic: noStylistic,
    resetStylistic: resetStylistic,
    fixIgnores: fixIgnores,
    outputPath: outputPath,
    tier: requestedTier,
  );
}

void _logTerminal(String message) {
  print(message);
  _logBuffer.writeln(message);
}

/// Display "what's new" from CHANGELOG.md (non-blocking, fail-safe).
void _showWhatsNew(String version, String? packageDir) {
  if (version == 'unknown' || packageDir == null) return;

  final lines = formatWhatsNew(
    packageDir: packageDir,
    version: version,
    colors: AnsiColors(
      bold: _Colors.bold,
      cyan: _Colors.cyan,
      dim: _Colors.dim,
      reset: _Colors.reset,
    ),
  );

  for (final line in lines) {
    _logTerminal(line);
  }
}

String? _resolveTier(String? input) {
  if (input == null) return null;

  final int? numericTier = int.tryParse(input);

  if (numericTier != null) {
    for (final MapEntry<String, int> entry in tierIds.entries) {
      if (entry.value == numericTier) {
        return entry.key;
      }
    }
    return null;
  }

  final String normalized = input.toLowerCase();

  if (tierIds.containsKey(normalized)) {
    return normalized;
  }

  return null;
}

// ---------------------------------------------------------------------------
// Interactive stylistic rules walkthrough
// ---------------------------------------------------------------------------

/// Result of running the stylistic walkthrough.
class _WalkthroughResult {
  const _WalkthroughResult({
    required this.reviewed,
    required this.enabled,
    required this.disabled,
    required this.skipped,
    required this.aborted,
  });

  final int reviewed;
  final int enabled;
  final int disabled;
  final int skipped;
  final bool aborted;
}

/// Run the interactive stylistic rules walkthrough.
///
/// Walks through unreviewed stylistic rules category by category,
/// showing code examples and prompting the user to enable or disable
/// each rule. Saves decisions immediately to [customFile].
///
/// Returns early if non-interactive.
_WalkthroughResult _runStylisticWalkthrough({
  required File customFile,
  required Map<String, bool> packageSettings,
  required Map<String, bool> platformSettings,
  required bool resetStylistic,
}) {
  if (!stdin.hasTerminal) {
    _logTerminal(
      '${_Colors.dim}Non-interactive: skipping stylistic '
      'walkthrough${_Colors.reset}',
    );
    return const _WalkthroughResult(
      reviewed: 0,
      enabled: 0,
      disabled: 0,
      skipped: 0,
      aborted: false,
    );
  }

  final content = customFile.readAsStringSync();

  // Get existing values and reviewed markers
  final existingValues = _extractStylisticSectionValues(content);
  var reviewedRules = resetStylistic
      ? <String>{}
      : _extractReviewedRules(content);

  // If --reset-stylistic, strip markers from the file first
  if (resetStylistic && content.contains('[reviewed]')) {
    customFile.writeAsStringSync(_stripReviewedMarkers(content));
    _logTerminal(
      '${_Colors.yellow}Cleared all [reviewed] markers${_Colors.reset}',
    );
  }

  // Filter out rules irrelevant to this project
  final disabledByPackage = tiers.getRulesDisabledByPackages(packageSettings);
  final disabledByPlatform = tiers.getRulesDisabledByPlatforms(
    platformSettings,
  );
  var irrelevantRules = disabledByPackage.union(disabledByPlatform);

  // Skip widget-specific stylistic rules for pure Dart projects.
  // packageSettings already detected Flutter from pubspec.yaml in main().
  if (packageSettings['flutter'] != true) {
    irrelevantRules = irrelevantRules.union(tiers.flutterStylisticRules);
  }

  // Build the list of rules to walk through (unreviewed + relevant)
  final rulesToReview = tiers.stylisticRules
      .difference(reviewedRules)
      .difference(irrelevantRules);

  if (rulesToReview.isEmpty) {
    _logTerminal(
      '${_Colors.green}All stylistic rules already '
      'reviewed.${_Colors.reset}',
    );
    _logTerminal(
      '${_Colors.dim}Use --reset-stylistic to '
      're-review.${_Colors.reset}',
    );
    return const _WalkthroughResult(
      reviewed: 0,
      enabled: 0,
      disabled: 0,
      skipped: 0,
      aborted: false,
    );
  }

  _logTerminal('');
  _logTerminal(
    '${_Colors.bold}${_Colors.cyan}'
    '── Stylistic Rules Walkthrough ──${_Colors.reset}',
  );
  _logTerminal(
    '${_Colors.dim}${rulesToReview.length} rules to review '
    '(${irrelevantRules.intersection(tiers.stylisticRules).length} '
    'skipped as irrelevant to project)${_Colors.reset}',
  );
  _logTerminal('');
  _logTerminal(
    '${_Colors.dim}  y = enable  n = disable  s = skip  '
    'a = enable all in category  q = quit & save${_Colors.reset}',
  );
  _logTerminal('');

  final metadata = _getRuleMetadata();
  int enabled = 0;
  int disabled = 0;
  int skipped = 0;
  bool aborted = false;

  // Walk through categories in order
  final categoryEntries = _stylisticRuleCategories.entries.toList();
  final categorizedRuleNames = <String>{};
  for (final rules in _stylisticRuleCategories.values) {
    categorizedRuleNames.addAll(rules);
  }
  final hasUncategorized = rulesToReview
      .difference(categorizedRuleNames)
      .isNotEmpty;
  final totalCategories =
      categoryEntries
          .where((e) => e.value.any((r) => rulesToReview.contains(r)))
          .length +
      (hasUncategorized ? 1 : 0);
  int categoryIndex = 0;
  int ruleOffset = 0;
  final int totalRules = rulesToReview.length;

  for (final entry in categoryEntries) {
    final category = entry.key;
    final categoryRules = entry.value
        .where((r) => rulesToReview.contains(r))
        .toList();
    if (categoryRules.isEmpty) continue;

    categoryIndex++;
    final isConflicting = category.contains('conflicting');

    if (isConflicting) {
      final result = _walkthroughConflicting(
        category: category,
        rules: categoryRules,
        metadata: metadata,
        existingValues: existingValues,
        categoryIndex: categoryIndex,
        totalCategories: totalCategories,
        ruleOffset: ruleOffset,
        totalRules: totalRules,
      );
      if (result == null) {
        aborted = true;
        break;
      }
      ruleOffset += categoryRules.length;
      enabled += result.enabled;
      disabled += result.disabled;
      skipped += result.skipped;
      _writeStylisticDecisions(customFile, result.decisions);
      reviewedRules = reviewedRules.union(result.decisions.keys.toSet());
    } else {
      final result = _walkthroughCategory(
        category: category,
        rules: categoryRules,
        metadata: metadata,
        existingValues: existingValues,
        categoryIndex: categoryIndex,
        totalCategories: totalCategories,
        ruleOffset: ruleOffset,
        totalRules: totalRules,
      );
      if (result == null) {
        aborted = true;
        break;
      }
      ruleOffset += categoryRules.length;
      enabled += result.enabled;
      disabled += result.disabled;
      skipped += result.skipped;
      _writeStylisticDecisions(customFile, result.decisions);
      reviewedRules = reviewedRules.union(result.decisions.keys.toSet());
    }
  }

  // Handle uncategorized rules
  if (!aborted) {
    final uncategorizedToReview = rulesToReview.difference(
      categorizedRuleNames,
    );
    if (uncategorizedToReview.isNotEmpty) {
      final result = _walkthroughCategory(
        category: 'Other stylistic rules',
        rules: uncategorizedToReview.toList()..sort(),
        metadata: metadata,
        existingValues: existingValues,
        categoryIndex: totalCategories,
        totalCategories: totalCategories,
        ruleOffset: ruleOffset,
        totalRules: totalRules,
      );
      if (result == null) {
        aborted = true;
      } else {
        enabled += result.enabled;
        disabled += result.disabled;
        skipped += result.skipped;
        _writeStylisticDecisions(customFile, result.decisions);
      }
    }
  }

  final totalReviewed = enabled + disabled;
  _logTerminal('');
  _logTerminal(
    '${_Colors.bold}Walkthrough '
    '${aborted ? 'paused' : 'complete'}:${_Colors.reset} '
    '$totalReviewed reviewed '
    '(${_Colors.green}$enabled enabled${_Colors.reset}, '
    '${_Colors.red}$disabled disabled${_Colors.reset}, '
    '${_Colors.dim}$skipped skipped${_Colors.reset})',
  );

  if (aborted) {
    _logTerminal(
      '${_Colors.dim}Run init again to resume from where you '
      'left off.${_Colors.reset}',
    );
  }

  return _WalkthroughResult(
    reviewed: totalReviewed,
    enabled: enabled,
    disabled: disabled,
    skipped: skipped,
    aborted: aborted,
  );
}

/// Result from walking through a single category.
class _CategoryResult {
  const _CategoryResult({
    required this.enabled,
    required this.disabled,
    required this.skipped,
    required this.decisions,
  });

  final int enabled;
  final int disabled;
  final int skipped;

  /// Rule name to enabled/disabled decision.
  /// Skipped rules are included with their current value preserved.
  final Map<String, bool> decisions;
}

/// Walk through a non-conflicting category rule by rule.
/// Returns null if user chose to quit.
_CategoryResult? _walkthroughCategory({
  required String category,
  required List<String> rules,
  required Map<String, _RuleMetadata> metadata,
  required Map<String, bool> existingValues,
  required int categoryIndex,
  required int totalCategories,
  required int ruleOffset,
  required int totalRules,
}) {
  _logTerminal(
    '${_Colors.bold}${_Colors.cyan}'
    '── $category ($categoryIndex of $totalCategories) '
    '──${_Colors.reset}',
  );
  _logTerminal('');

  int enabled = 0;
  int disabled = 0;
  int skipped = 0;
  final decisions = <String, bool>{};
  bool enableAllRemaining = false;

  for (int i = 0; i < rules.length; i++) {
    final rule = rules[i];
    final meta = metadata[rule];

    if (enableAllRemaining) {
      decisions[rule] = true;
      enabled++;
      _logTerminal('  ${_Colors.green}+ $rule${_Colors.reset}');
      continue;
    }

    // Display rule info with progress
    final ruleNum = ruleOffset + i + 1;
    final pct = (ruleNum * 100 / totalRules).round();
    final progress =
        '${_Colors.dim}($ruleNum/$totalRules — $pct%)${_Colors.reset}';
    final fixTag = (meta != null && meta.hasFix)
        ? '  ${_Colors.green}[quick fix]${_Colors.reset}'
        : '';
    _logTerminal('  ${_Colors.bold}$rule${_Colors.reset}$fixTag  $progress');
    _logTerminal('');

    if (meta != null) {
      // Show code examples if available (GOOD first for readability)
      if (meta.exampleGood != null) {
        _logTerminal(
          '  ${_Colors.green}GOOD:${_Colors.reset} '
          '${meta.exampleGood}',
        );
      }
      if (meta.exampleBad != null) {
        _logTerminal(
          '  ${_Colors.red}BAD:${_Colors.reset}  '
          '${meta.exampleBad}',
        );
      }
      if (meta.exampleBad != null || meta.exampleGood != null) {
        _logTerminal('');
      }

      // Show description
      final desc = meta.correctionMessage.isNotEmpty
          ? _stripRulePrefix(meta.correctionMessage)
          : _stripRulePrefix(meta.problemMessage);
      if (desc.isNotEmpty) {
        _logTerminal('  $desc');
        _logTerminal('');
      }
    }

    // Prompt
    final after = rules.length - i - 1;
    final aLabel = after > 0 ? '[a] enable this + $after more  ' : '';
    stdout.write(
      '  ${_Colors.cyan}[y] enable  [n] disable  '
      '[s] skip (keeps current)  '
      '$aLabel'
      '[q] quit: ${_Colors.reset}',
    );

    final rawInput = stdin.readLineSync();
    _logTerminal('');
    if (rawInput == null) return null; // EOF → quit
    final input = rawInput.trim().toLowerCase();

    switch (input) {
      case 'y':
      case 'yes':
        decisions[rule] = true;
        enabled++;
      case 'n':
      case 'no':
        decisions[rule] = false;
        disabled++;
      case 's':
      case 'skip':
      case '':
        // Mark as reviewed with current value so it won't be re-prompted
        decisions[rule] = existingValues[rule] ?? false;
        skipped++;
      case 'a':
      case 'all':
        decisions[rule] = true;
        enabled++;
        enableAllRemaining = true;
      case 'q':
      case 'quit':
        return null;
      default:
        _logTerminal(
          '  ${_Colors.yellow}Unknown "$input", '
          'skipping${_Colors.reset}',
        );
        // Mark as reviewed with current value so it won't be re-prompted
        decisions[rule] = existingValues[rule] ?? false;
        skipped++;
    }
  }

  return _CategoryResult(
    enabled: enabled,
    disabled: disabled,
    skipped: skipped,
    decisions: decisions,
  );
}

/// Walk through a conflicting category as a multiple-choice selection.
/// Returns null if user chose to quit.
_CategoryResult? _walkthroughConflicting({
  required String category,
  required List<String> rules,
  required Map<String, _RuleMetadata> metadata,
  required Map<String, bool> existingValues,
  required int categoryIndex,
  required int totalCategories,
  required int ruleOffset,
  required int totalRules,
}) {
  final ruleNum = ruleOffset + 1;
  final pct = (ruleNum * 100 / totalRules).round();
  final progress =
      '${_Colors.dim}($ruleNum/$totalRules — $pct%)${_Colors.reset}';
  _logTerminal(
    '${_Colors.bold}${_Colors.cyan}'
    '── $category ($categoryIndex of $totalCategories) '
    '──${_Colors.reset}  $progress',
  );
  _logTerminal('');

  // Display all options with numbers
  for (int i = 0; i < rules.length; i++) {
    final rule = rules[i];
    final meta = metadata[rule];
    _logTerminal('  ${_Colors.bold}${i + 1}. $rule${_Colors.reset}');
    if (meta?.exampleGood != null) {
      _logTerminal('     ${meta!.exampleGood}');
    } else if (meta != null) {
      final desc = _stripRulePrefix(meta.correctionMessage).isNotEmpty
          ? _stripRulePrefix(meta.correctionMessage)
          : _stripRulePrefix(meta.problemMessage);
      _logTerminal('     $desc');
    }
    _logTerminal('');
  }

  // Prompt
  final nums = List.generate(rules.length, (i) => '${i + 1}').join('/');
  stdout.write(
    '  ${_Colors.cyan}Choose [$nums] or [s] skip (keeps current)  '
    '[q] quit: ${_Colors.reset}',
  );

  final rawInput = stdin.readLineSync();
  _logTerminal('');

  if (rawInput == null) return null; // EOF → quit
  final input = rawInput.trim().toLowerCase();

  if (input == 'q' || input == 'quit') return null;

  final decisions = <String, bool>{};
  int enabled = 0;
  int disabled = 0;
  int skipped = 0;

  if (input == 's' || input == 'skip' || input.isEmpty) {
    // Mark all rules in group as reviewed with current values
    for (final rule in rules) {
      decisions[rule] = existingValues[rule] ?? false;
    }
    skipped += rules.length;
  } else {
    final choice = int.tryParse(input);
    if (choice != null && choice >= 1 && choice <= rules.length) {
      // Enable the chosen rule, disable all others
      for (int i = 0; i < rules.length; i++) {
        if (i == choice - 1) {
          decisions[rules[i]] = true;
          enabled++;
        } else {
          decisions[rules[i]] = false;
          disabled++;
        }
      }
    } else {
      _logTerminal(
        '  ${_Colors.yellow}Unknown "$input", '
        'skipping${_Colors.reset}',
      );
      // Mark all rules in group as reviewed with current values
      for (final rule in rules) {
        decisions[rule] = existingValues[rule] ?? false;
      }
      skipped += rules.length;
    }
  }

  return _CategoryResult(
    enabled: enabled,
    disabled: disabled,
    skipped: skipped,
    decisions: decisions,
  );
}

/// Write walkthrough decisions to the custom yaml file.
///
/// Updates rule values and adds [reviewed] markers in the STYLISTIC
/// RULES section. Only modifies rules present in [decisions].
void _writeStylisticDecisions(File customFile, Map<String, bool> decisions) {
  if (decisions.isEmpty) return;

  var content = customFile.readAsStringSync();

  // Scope replacements to the STYLISTIC RULES section only, so a rule
  // that also appears in RULE OVERRIDES is not accidentally modified.
  final sectionStart = _findStylisticSectionStart(content);
  final sectionEnd = _findStylisticSectionEnd(content, sectionStart);

  for (final entry in decisions.entries) {
    final rule = entry.key;
    final enabled = entry.value;

    // Match the rule line: rule_name: true/false  # ...
    final rulePattern = RegExp(
      '^(${RegExp.escape(rule)}):\\s*(true|false)(\\s*#.*)?\\s*\$',
      multiLine: true,
    );

    // Search only within the STYLISTIC RULES section
    final sectionContent = content.substring(sectionStart, sectionEnd);
    final match = rulePattern.firstMatch(sectionContent);
    if (match != null) {
      // Preserve description after [reviewed] marker
      final existingComment = match.group(3)?.trim() ?? '';

      // Strip old marker if present, keep description
      final descPart = existingComment
          .replaceFirst(RegExp(r'^#\s*'), '')
          .replaceFirst(RegExp(r'\[reviewed\]\s*'), '')
          .trim();

      final newComment = descPart.isNotEmpty
          ? '  # [reviewed] $descPart'
          : '  # [reviewed]';

      // Offset match positions back to full-content coordinates
      content = content.replaceRange(
        sectionStart + match.start,
        sectionStart + match.end,
        '$rule: $enabled$newComment',
      );
    }
  }

  customFile.writeAsStringSync(content);
}

/// Prompts the user to select a tier interactively.
///
/// Defaults to the tier found in the existing analysis_options.yaml,
/// or 'essential' for fresh setups. In non-interactive mode (piped input,
/// CI), uses the default without prompting.
String _promptForTier() {
  final String defaultTier = _detectExistingTier() ?? 'essential';

  if (!stdin.hasTerminal) {
    _logTerminal(
      '${_Colors.dim}Non-interactive: using default tier '
      '($defaultTier)${_Colors.reset}',
    );
    return defaultTier;
  }

  _logTerminal('${_Colors.bold}Select a tier:${_Colors.reset}');
  _logTerminal('');

  for (final String name in tierOrder) {
    final int id = tierIds[name]!;
    final int count = tiers.getRulesForTier(name).length;
    final String desc = tierDescriptions[name] ?? '';
    final String label = _tierColor(name.padRight(13));
    final String countStr = '${_Colors.dim}(~$count rules)${_Colors.reset}';
    final String isDefault = name == defaultTier
        ? ' ${_Colors.cyan}(default)${_Colors.reset}'
        : '';
    _logTerminal('  $id. $label $countStr  $desc$isDefault');
  }

  _logTerminal('');
  stdout.write(
    '${_Colors.cyan}Enter tier (1-5) '
    '[default: ${tierIds[defaultTier]}]: ${_Colors.reset}',
  );

  final String input = stdin.readLineSync()?.trim() ?? '';

  if (input.isEmpty) return defaultTier;

  final String? resolved = _resolveTier(input);

  if (resolved != null) return resolved;

  _logTerminal(
    '${_Colors.yellow}Invalid selection "$input", '
    'using $defaultTier${_Colors.reset}',
  );
  return defaultTier;
}

/// Reads the existing analysis_options.yaml and returns the tier name
/// from the `# Tier: <name>` comment, or null if not found.
String? _detectExistingTier() {
  final file = File('analysis_options.yaml');

  if (!file.existsSync()) return null;

  final match = RegExp(r'# Tier:\s*(\w+)').firstMatch(file.readAsStringSync());

  if (match == null) return null;

  final tier = match.group(1)!.toLowerCase();
  return tierIds.containsKey(tier) ? tier : null;
}

void _printUsage() {
  print('''

Saropa Lints Configuration Generator

Generates analysis_options.yaml with explicit rule configuration
for the native analyzer plugin system.

IMPORTANT: This tool preserves:
  - All non-plugins sections (analyzer, linter, formatter, etc.)
  - User customizations in plugins.saropa_lints.diagnostics (unless --reset)

Usage: dart run saropa_lints:init [options]

Options:
  -t, --tier <tier>     Tier level (1-5 or name, prompts if omitted)
  -o, --output <file>   Output file (default: analysis_options.yaml)
  --stylistic           Interactive stylistic rules walkthrough (default)
  --stylistic-all       Bulk-enable all stylistic rules (CI/non-interactive)
  --no-stylistic        Skip stylistic rules walkthrough entirely
  --reset-stylistic     Clear reviewed markers and re-walkthrough all rules
  --fix-ignores         Auto-convert v4 ignore comments without prompting
  --reset               Discard user customizations and reset to tier defaults
  --dry-run             Preview output without writing
  -h, --help            Show this help message

Tiers:
${tierOrder.map((String t) => '  ${tierIds[t]}. $t\n     ${tierDescriptions[t]}').join('\n')}

Examples:
  dart run saropa_lints:init                          # Prompts for tier + walkthrough
  dart run saropa_lints:init --tier comprehensive
  dart run saropa_lints:init --tier 4
  dart run saropa_lints:init --tier essential --reset
  dart run saropa_lints:init --stylistic-all            # Bulk-enable all stylistic
  dart run saropa_lints:init --no-stylistic             # Skip stylistic walkthrough
  dart run saropa_lints:init --reset-stylistic          # Re-review all stylistic rules
  dart run saropa_lints:init --dry-run

After generating, run `dart analyze` to verify.
''');
}
