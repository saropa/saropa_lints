/// Project detection: package version, source, and dependency scanning.
library;

import 'dart:developer' as dev;
import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/tiers.dart' as tiers;

/// Get saropa_lints rootUri from .dart_tool/package_config.json.
/// Returns null if not found.
String? getSaropaLintsRootUri() {
  try {
    final packageConfigFile = File('.dart_tool/package_config.json');
    if (!packageConfigFile.existsSync()) return null;

    final content = packageConfigFile.readAsStringSync();
    final match = RegExp(
      r'"name":\s*"saropa_lints"[^}]*"rootUri":\s*"([^"]+)"',
    ).firstMatch(content);

    return match?.group(1);
  } catch (e, st) {
    dev.log(
      'Failed to read saropa_lints rootUri from package_config',
      error: e,
      stackTrace: st,
    );
  }

  return null;
}

/// Convert rootUri to absolute file path.
String? rootUriToPath(String rootUri) {
  if (rootUri.startsWith('file://')) {
    return Uri.parse(rootUri).toFilePath();
  } else if (rootUri.startsWith('../')) {
    final dartToolDir = Directory('.dart_tool').absolute.path;
    return Directory('$dartToolDir/$rootUri').absolute.path;
  }

  return null;
}

/// Get package version by reading pubspec.yaml from package location.
String getPackageVersion() {
  try {
    final rootUri = getSaropaLintsRootUri();
    if (rootUri == null) return 'unknown';

    final packageDir = rootUriToPath(rootUri);
    if (packageDir == null) return 'unknown';

    final pubspecFile = File('$packageDir/pubspec.yaml');
    if (!pubspecFile.existsSync()) return 'unknown';

    final content = pubspecFile.readAsStringSync();
    final match = RegExp(
      r'^version:\s*(.+)$',
      multiLine: true,
    ).firstMatch(content);
    return match?.group(1)?.trim() ?? 'unknown';
  } catch (e, st) {
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
Map<String, bool> detectProjectPackages(LogWriter log) {
  // Start with all disabled — only enable what we find
  final detected = <String, bool>{
    for (final pkg in tiers.allPackages) pkg: false,
  };

  try {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) return detected;

    final content = pubspecFile.readAsStringSync();

    final isFlutter = content.contains('flutter:') ||
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

    log.terminal(
      '${InitColors.dim}Auto-detected packages from pubspec.yaml: '
      '${detected.entries.where((e) => e.value).map((e) => e.key).join(', ')}'
      '${isFlutter ? ' (Flutter project)' : ' (pure Dart)'}${InitColors.reset}',
    );
  } catch (e, st) {
    dev.log(
      'Could not read project pubspec for package detection',
      error: e,
      stackTrace: st,
    );
    return Map<String, bool>.of(tiers.defaultPackages);
  }

  return detected;
}
