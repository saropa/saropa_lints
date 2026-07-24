/// YAML generation and file writing for analysis_options.yaml.
library;

import 'package:saropa_lints/saropa_lints.dart' show RuleTier;
import 'package:saropa_lints/src/init/rule_metadata.dart';
import 'package:saropa_lints/src/string_slice_utils.dart';

/// Matches the `plugins:` section header in YAML.
final RegExp _pluginsSectionPattern = RegExp(r'^plugins:\s*$', multiLine: true);

/// Matches any top-level YAML key (for finding section boundaries).
final RegExp topLevelKeyPattern = RegExp(r'^\w+:', multiLine: true);

/// Generate the plugins YAML section with proper formatting.
///
/// Organizes rules by tier with problem message comments.
String generatePluginsYaml({
  required String tier,
  required String packageVersion,
  required Set<String> enabledRules,
  required Map<String, bool> userCustomizations,
  required Set<String> allRules,
  required Map<String, bool> platformSettings,
  required Map<String, bool> packageSettings,
  List<String> rulePacksEnabled = const [],
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
  buffer.writeln('    log_level: info # off | error | warning | info | debug');
  if (rulePacksEnabled.isNotEmpty) {
    final sorted = List<String>.of(rulePacksEnabled)..sort();
    buffer.writeln('    rule_packs:');
    buffer.writeln('      enabled:');
    for (final String id in sorted) {
      buffer.writeln('        - $id');
    }
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
    buffer.writeln(sectionHeader('USER CUSTOMIZATIONS', '~'));
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
      final bool? enabled = userCustomizations[rule];
      if (enabled == null) continue;
      final String msg = getProblemMessage(rule);
      final String severity = getRuleSeverity(rule);
      buffer.writeln('      $rule: $enabled  # [$severity] $msg');
    }
    buffer.writeln('');
  }

  // Group enabled rules by their tier
  final Map<RuleTier, List<String>> enabledByTier = {};

  for (final tier in RuleTier.values) {
    enabledByTier[tier] = [];
  }

  for (final String rule in enabledRules.difference(customizedRuleNames)) {
    final ruleTier = getRuleTierFromMetadata(rule);
    (enabledByTier[ruleTier] ??= []).add(rule);
  }

  // Section 2: Enabled rules organized by tier
  buffer.writeln(sectionHeader('ENABLED RULES ($tier tier)', '='));
  buffer.writeln('');

  // Output enabled tiers in order
  for (final tierLevel in [
    RuleTier.essential,
    RuleTier.recommended,
    RuleTier.professional,
    RuleTier.comprehensive,
    RuleTier.pedantic,
  ]) {
    final rules = enabledByTier[tierLevel];
    if (rules == null || rules.isEmpty) continue;
    rules.sort();

    final tierName = tierToString(tierLevel).toUpperCase();
    final tierNum = tierIndex(tierLevel) + 1;
    buffer.writeln('      #');
    buffer.writeln(
      '      # --- TIER $tierNum: $tierName (${rules.length} rules) ---',
    );
    buffer.writeln('      #');
    for (final String rule in rules) {
      final String msg = getProblemMessage(rule);
      final String severity = getRuleSeverity(rule);
      buffer.writeln('      $rule: true  # [$severity] $msg');
    }
    buffer.writeln('');
  }

  // Section 3: Enabled stylistic rules (opt-in, no false entries needed)
  final stylisticEnabled = (enabledByTier[RuleTier.stylistic] ?? [])..sort();

  if (stylisticEnabled.isNotEmpty) {
    buffer.writeln(sectionHeader('STYLISTIC RULES (opt-in)', '~'));
    buffer.writeln('      # Formatting, ordering, naming conventions.');
    buffer.writeln(
      '      # Enable with: dart run saropa_lints:init --tier <tier> --stylistic-all',
    );
    buffer.writeln('');

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
      final String msg = getProblemMessage(rule);
      buffer.writeln('      $rule: true  # $msg');
    }
    buffer.writeln('');
  }

  return buffer.toString();
}

/// Generate a clear, visible section header for YAML.
String sectionHeader(String title, String char) {
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
String replacePluginsSection(String existingContent, String newPlugins) {
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

  // Find the end of the plugins section (next top-level key or end of file).
  // Fix: avoid_string_substring — use clamped slice/afterIndex extensions so
  // index out-of-range cannot throw RangeError even when match offsets shift
  // due to earlier edits.
  final String beforePlugins = existingContent.prefix(customLintMatch.start);
  final String afterPluginsStart = existingContent.afterIndex(
    customLintMatch.end,
  );

  // Find next top-level section (line starting with a word followed by colon, no indentation)
  final Match? nextSection = topLevelKeyPattern.firstMatch(afterPluginsStart);

  final String afterPlugins = nextSection != null
      ? afterPluginsStart.afterIndex(nextSection.start)
      : '';

  return '$beforePlugins$newPlugins\n$afterPlugins';
}

/// Non-Dart directories that the analysis server should not watch.
///
/// The plugin writes logs and reports to `reports/.saropa_lints/`. Without
/// excluding these, the analysis server's file watcher may see those writes
/// and restart the plugin isolate, creating a feedback loop that clears
/// diagnostics from the Problems tab hundreds of times per day.
const List<String> _nonDartExcludes = [
  'bugs/**',
  'doc/**',
  'docs/**',
  'output/**',
  'plans/**',
  'reports/**',
  'tmp/**',
];

/// Ensures common non-Dart directories are in the `analyzer > exclude` list.
///
/// Returns the content unchanged if all excludes are already present or if
/// no `analyzer:` section exists (we don't create one from scratch — the
/// user or `dart create` manages that).
String ensureNonDartExcludes(String content) {
  if (content.isEmpty) return content;

  // Flow-style exclude under `analyzer:` (e.g. `exclude: ["a/**"]`).
  // Inserting block entries after a flow line creates invalid YAML.
  // Scoped to the analyzer section so an unrelated `exclude: [...]`
  // under another top-level key does not cause a false early-return.
  // Capture indented lines AND blank lines under `analyzer:` so a
  // visual separator (blank line) inside the section doesn't terminate
  // the match early and hide a flow-style exclude below it.
  final analyzerSection = RegExp(
    r'^analyzer:\s*\n((?:(?:[ \t]+.*|)\n)*)',
    multiLine: true,
  ).firstMatch(content);
  if (analyzerSection != null) {
    final body = analyzerSection.group(1) ?? '';
    if (RegExp(r'^\s+exclude:\s*\[', multiLine: true).hasMatch(body)) {
      return content;
    }
  }

  final missing = <String>[];
  for (final exclude in _nonDartExcludes) {
    final dirName = exclude.replaceAll('/**', '');
    // Block-style: `- "reports/**"` or `- reports/**`
    final pattern = RegExp(
      '''\\s+-\\s+['"]?$dirName/''',
      multiLine: true,
    );
    if (!pattern.hasMatch(content)) {
      missing.add(exclude);
    }
  }
  if (missing.isEmpty) return content;

  // Match block-style `exclude:` with optional trailing whitespace or comment
  final excludeMatch = RegExp(
    r'^(\s+exclude:\s*)(?:#.*)?$',
    multiLine: true,
  ).firstMatch(content);

  if (excludeMatch != null) {
    final insertAt = excludeMatch.end;
    final lines = missing.map((e) => '    - "$e"').join('\n');
    return '${content.prefix(insertAt)}\n'
        '$lines\n'
        '${content.afterIndex(insertAt)}';
  }

  // No exclude section — look for `analyzer:` and add one
  final analyzerMatch = RegExp(
    r'^analyzer:\s*$',
    multiLine: true,
  ).firstMatch(content);

  if (analyzerMatch == null) return content;

  final afterAnalyzer = content.afterIndex(analyzerMatch.end);
  final firstLine = RegExp(r'^(\s+\S)', multiLine: true).firstMatch(
    afterAnalyzer,
  );
  if (firstLine == null) return content;

  final insertAt = analyzerMatch.end + firstLine.start;
  final lines = missing.map((e) => '    - "$e"').join('\n');
  return '${content.prefix(insertAt)}'
      '  exclude:\n'
      '$lines\n'
      '${content.afterIndex(insertAt)}';
}
