/// Platform and package configuration management.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/tiers.dart' as tiers;

/// Ensure platforms setting exists in an existing custom config file.
///
/// Older files won't have this setting, so we add it after the
/// max_issues setting if missing.
void ensurePlatformsSetting(File file) {
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
  log.terminal(
    '${InitColors.green}✓ Added platforms setting to ${file.path}${InitColors.reset}',
  );
}

/// Ensure packages setting exists in an existing custom config file.
///
/// Older files won't have this setting, so we add it after the
/// platforms setting if missing.
void ensurePackagesSetting(File file) {
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
  log.terminal(
    '${InitColors.green}✓ Added packages setting to ${file.path}${InitColors.reset}',
  );
}

/// Builds the PACKAGE SETTINGS section for analysis_options_custom.yaml.
String buildPackageSection() {
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
Map<String, bool> extractPlatformsFromFile(File file) {
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

    final name = match.group(1);
    if (name == null) continue;
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
Map<String, bool> extractPackagesFromFile(File file) {
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

    final name = match.group(1);
    if (name == null) continue;
    final enabled = match.group(2) == 'true';

    // Only include packages we know about
    if (tiers.defaultPackages.containsKey(name)) {
      packages[name] = enabled;
    }
  }

  return packages;
}
