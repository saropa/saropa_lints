/// Project detection: package version, source, and dependency scanning.
library;

import 'dart:developer' as dev;
import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/tiers.dart' as tiers;

/// Get saropa_lints rootUri from `<projectRoot>/.dart_tool/package_config.json`.
///
/// [projectRoot] is the absolute path to the consumer project. When null,
/// falls back to a relative lookup (which only works when `Directory.current`
/// IS the consumer project — true for the saropa_lints CLI commands, but
/// NOT true when the analyzer plugin isolate invokes this helper). Passing
/// an explicit [projectRoot] is required from the plugin path — otherwise
/// the report header prints `Version: unknown` and users can't tell which
/// saropa_lints version produced their diagnostics.
///
/// Returns null if not found.
String? getSaropaLintsRootUri({String? projectRoot}) {
  try {
    final String configPath = projectRoot != null && projectRoot.isNotEmpty
        ? '$projectRoot/.dart_tool/package_config.json'
        : '.dart_tool/package_config.json';
    final packageConfigFile = File(configPath);
    if (!packageConfigFile.existsSync()) return null;

    final content = packageConfigFile.readAsStringSync();
    final match = RegExp(
      r'"name":\s*"saropa_lints"[^}]*"rootUri":\s*"([^"]+)"',
    ).firstMatch(content);

    return match?.group(1);
  } on Object catch (e, st) {
    dev.log(
      'Failed to read saropa_lints rootUri from package_config',
      error: e,
      stackTrace: st,
    );
  }

  return null;
}

/// Converts a `package_config.json` [rootUri] to an absolute filesystem path.
///
/// For `file://` URIs, uses [Uri.tryParse] so malformed values return null
/// instead of throwing (see `prefer_try_parse_for_dynamic_data`).
///
/// For `../` relative URIs (hosted pub cache entries), resolves against
/// `<projectRoot>/.dart_tool/` when [projectRoot] is supplied, falling
/// back to the current directory otherwise — same cwd trap that affects
/// [getSaropaLintsRootUri].
String? rootUriToPath(String rootUri, {String? projectRoot}) {
  if (rootUri.startsWith('file://')) {
    final uri = Uri.tryParse(rootUri);
    return uri?.toFilePath();
  } else if (rootUri.startsWith('../')) {
    final String dartToolDir = projectRoot != null && projectRoot.isNotEmpty
        ? Directory('$projectRoot/.dart_tool').absolute.path
        : Directory('.dart_tool').absolute.path;
    return Directory('$dartToolDir/$rootUri').absolute.path;
  }

  return null;
}

/// Get package version by reading pubspec.yaml from package location.
///
/// Pass [projectRoot] (absolute path to the consumer project) from the
/// analyzer-plugin path — without it the lookup uses `Directory.current`,
/// which is rarely the consumer project inside a plugin isolate. The CLI
/// commands (`saropa_lints:init`, `saropa_lints:write_config`) invoke
/// this from a shell whose cwd IS the consumer project, so they can keep
/// calling with no argument.
String getPackageVersion({String? projectRoot}) {
  try {
    final rootUri = getSaropaLintsRootUri(projectRoot: projectRoot);
    if (rootUri == null) return 'unknown';

    final packageDir = rootUriToPath(rootUri, projectRoot: projectRoot);
    if (packageDir == null) return 'unknown';

    final pubspecFile = File('$packageDir/pubspec.yaml');
    if (!pubspecFile.existsSync()) return 'unknown';

    final content = pubspecFile.readAsStringSync();
    final match = RegExp(
      r'^version:\s*(.+)$',
      multiLine: true,
    ).firstMatch(content);
    return match?.group(1)?.trim() ?? 'unknown';
  } on Object catch (e, st) {
    dev.log(
      'Failed to read saropa_lints version from pubspec',
      error: e,
      stackTrace: st,
    );
  }

  return 'unknown';
}

/// Detect where the saropa_lints package is loaded from.
String getPackageSource() {
  final rootUri = getSaropaLintsRootUri();

  if (rootUri == null) return 'unknown';

  if (rootUri.startsWith('file://') || rootUri.startsWith('../')) {
    return 'local: $rootUri';
  } else if (rootUri.contains('.pub-cache')) {
    return 'pub.dev';
  }

  return rootUri;
}

/// Detect which packages the host project uses from its pubspec.yaml.
///
/// Reads the project's pubspec.yaml (not the saropa_lints package's),
/// parses dependencies + dev_dependencies, and returns a map of
/// saropa_lints package names to whether they were found.
/// [targetDir] is the absolute path to the project being configured.
/// If [logLine] is null, no terminal output is produced (for headless use).
Map<String, bool> detectProjectPackages(
  LogWriter log, {
  required String targetDir,
  void Function(String)? logLine,
}) {
  final report = logLine ?? log.terminal;
  // Start with all disabled — only enable what we find
  final detected = <String, bool>{
    for (final pkg in tiers.allPackages) pkg: false,
  };

  try {
    final pubspecFile = File('$targetDir/pubspec.yaml');
    if (!pubspecFile.existsSync()) return detected;

    final content = pubspecFile.readAsStringSync();

    final isFlutter =
        content.contains('flutter:') ||
        content.contains('flutter_test:') ||
        content.contains('sdk: flutter');

    final deps = <String>{};
    final depMatches = RegExp(r'^\s+(\w+):').allMatches(content);
    for (final match in depMatches) {
      final dep = match.group(1);
      if (dep != null) deps.add(dep);
    }

    // Map detected deps to saropa_lints package names.
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

    if (!isFlutter) {
      for (final pkg in ['flutter_hooks', 'flame']) {
        detected[pkg] = false;
      }
    }

    report(
      '${InitColors.dim}Auto-detected packages from pubspec.yaml: '
      '${detected.entries.where((e) => e.value).map((e) => e.key).join(', ')}'
      '${isFlutter ? ' (Flutter project)' : ' (pure Dart)'}${InitColors.reset}',
    );
  } on Object catch (e, st) {
    dev.log(
      'Could not read project pubspec for package detection',
      error: e,
      stackTrace: st,
    );
    return Map<String, bool>.of(tiers.defaultPackages);
  }

  return detected;
}
