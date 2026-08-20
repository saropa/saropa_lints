/// YAML generation and file writing for analysis_options.yaml.
library;

import 'package:saropa_lints/saropa_lints.dart' show RuleTier;
import 'package:saropa_lints/src/init/rule_metadata.dart';
import 'package:saropa_lints/src/string_slice_utils.dart';

/// Matches the `plugins:` section header in YAML.
final RegExp _pluginsSectionPattern = RegExp(r'^plugins:\s*$', multiLine: true);

/// Matches any top-level YAML key (for finding section boundaries).
final RegExp topLevelKeyPattern = RegExp(r'^\w+:', multiLine: true);

/// Sentinel bracketing a `plugins:` block that is intentionally disabled.
/// Mirrors `DISABLE_BEGIN_MARKER`/`DISABLE_END_MARKER` in
/// `extension/src/setup.ts` and the detection substring
/// `kIntegrationOffSentinel` in `lib/src/native/config_loader.dart` — all
/// three describe the same commented-out block. Keep the text identical
/// across all three so the extension's restore/disable toggle and the
/// analyzer's kill switch keep recognizing a block this writer produced.
const String pluginsDisabledBeginMarker =
    '# >>> saropa_lints integration turned OFF by the VS Code extension — toggle "Lint integration" On to restore >>>';
const String pluginsDisabledEndMarker =
    '# <<< saropa_lints end of disabled integration block <<<';

/// Matches the begin sentinel line of a disabled `plugins:` block.
final RegExp _pluginsDisabledBeginPattern = RegExp(
  r'^# >>> saropa_lints integration turned OFF.*$',
  multiLine: true,
);

/// Matches the end sentinel line of a disabled `plugins:` block.
final RegExp _pluginsDisabledEndPattern = RegExp(
  r'^# <<< saropa_lints end of disabled integration block <<<\s*$',
  multiLine: true,
);

/// Wraps a generated `plugins:` block ([pluginsYaml]) in the disabled
/// sentinels, commenting every non-blank line. Mirrors the extension's
/// `disablePluginsIntegration` transform in `setup.ts` so a file written by
/// either side has the exact same on-disk shape, and either side's
/// restore/re-disable logic can operate on it.
String wrapPluginsYamlAsDisabled(String pluginsYaml) {
  final List<String> commented = pluginsYaml
      .split('\n')
      .map((String line) => line.isEmpty ? line : '# $line')
      .toList();
  return '$pluginsDisabledBeginMarker\n${commented.join('\n')}\n$pluginsDisabledEndMarker\n';
}

/// Generate the plugins YAML section with proper formatting.
///
/// Organizes rules by tier with problem message comments.
/// [compact] drops the per-rule description comments and the box-drawing
/// section headers, keeping only the `rule_name: true/false` lines that
/// actually control enablement (see `config_loader.dart`'s `diagnostics:`
/// parser — these lines are load-bearing, not just documentation, so they
/// can never be omitted). Pass true when the block being written is going
/// to end up wrapped in the disabled sentinel: nobody reads a commented-out
/// block's prose, so the ~2000-rule dump only needs to stay byte-for-byte
/// restorable, not human-readable. A live block keeps the full verbose form
/// since a user editing it directly benefits from the inline explanations.
String generatePluginsYaml({
  required String tier,
  required String packageVersion,
  required Set<String> enabledRules,
  required Map<String, bool> userCustomizations,
  required Set<String> allRules,
  required Map<String, bool> platformSettings,
  required Map<String, bool> packageSettings,
  List<String> rulePacksEnabled = const [],
  bool compact = false,
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
  // Two-lane split. Written commented-out; `light` is the actual default
  // when the key is absent (RSS-measured at +0.6% over plugin-off, vs +77.2%
  // for `full`) — the comment documents that explicitly so a user reading the
  // generated file is not misled by the commented-out value.
  // See plans/PLAN_two_lane_daemon_architecture.md.
  buffer.writeln(
    '    # lane: light # full | light (default when absent: light)',
  );
  buffer.writeln(
    '    # `light` runs ONLY error/warning rules that need no type resolution',
  );
  buffer.writeln(
    '    # in the analysis server (~200 of 2300). Everything else is reported',
  );
  buffer.writeln(
    '    # on save by the out-of-process scanner, so nothing is lost — but the',
  );
  buffer.writeln(
    '    # server stops holding the whole project\'s resolved type model.',
  );
  if (rulePacksEnabled.isNotEmpty) {
    final sorted = List<String>.of(rulePacksEnabled)..sort();
    buffer.writeln('    rule_packs:');
    buffer.writeln('      enabled:');
    for (final String id in sorted) {
      buffer.writeln('        - $id');
    }
  }
  if (compact) {
    buffer.writeln(
      '    # SAROPA LINTS — plugin disabled. Rule list kept below so a',
    );
    buffer.writeln(
      '    # future re-enable restores the exact $tier-tier configuration',
    );
    buffer.writeln(
      '    # instead of falling back to essential-only. Regenerate the full,',
    );
    buffer.writeln(
      '    # commented form with: dart run saropa_lints:init --tier $tier',
    );
  } else {
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
    buffer.writeln(
      '    #   4. comprehensive - Professional + thorough coverage',
    );
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
      buffer.writeln(
        '    # Disabled platforms: ${disabledPlatforms.join(', ')}',
      );
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
    buffer.writeln('    #');
    buffer.writeln(
      '    # MEMORY: this in-process plugin resolves types for every rule and',
    );
    buffer.writeln(
      '    # can retain several GB of resolved AST on large projects. The VS',
    );
    buffer.writeln(
      '    # Code extension\'s scan-on-save (out-of-process, ~3 GB fixed) covers',
    );
    buffer.writeln(
      '    # the same diagnostics for a fraction of the cost — see',
    );
    buffer.writeln(
      '    # plans/PLAN_scan_only_diagnostics.md. New projects get this block',
    );
    buffer.writeln(
      '    # commented out by default for that reason; delete the sentinel',
    );
    buffer.writeln('    # comment lines around it to run it live.');
    buffer.writeln(
      '    # ═══════════════════════════════════════════════════════════════════',
    );
  }
  buffer.writeln('');
  buffer.writeln('    diagnostics:');

  // Section 1: User customizations (always at top, preserved)
  if (userCustomizations.isNotEmpty) {
    if (compact) {
      buffer.writeln(
        '      # USER CUSTOMIZATIONS (preserved; --reset discards)',
      );
    } else {
      buffer.writeln(sectionHeader('USER CUSTOMIZATIONS', '~'));
      buffer.writeln(
        '      # These rules have been manually configured and will be preserved',
      );
      buffer.writeln(
        '      # when regenerating. Use --reset to discard these customizations.',
      );
    }
    buffer.writeln('');

    final List<String> sortedCustomizations = userCustomizations.keys.toList()
      ..sort();
    for (final String rule in sortedCustomizations) {
      final bool? enabled = userCustomizations[rule];
      if (enabled == null) continue;
      if (compact) {
        buffer.writeln('      $rule: $enabled');
        continue;
      }
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
  if (compact) {
    buffer.writeln('      # ENABLED RULES ($tier tier)');
  } else {
    buffer.writeln(sectionHeader('ENABLED RULES ($tier tier)', '='));
  }
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
      if (compact) {
        buffer.writeln('      $rule: true');
        continue;
      }
      final String msg = getProblemMessage(rule);
      final String severity = getRuleSeverity(rule);
      buffer.writeln('      $rule: true  # [$severity] $msg');
    }
    buffer.writeln('');
  }

  // Section 3: Enabled stylistic rules (opt-in, no false entries needed)
  final stylisticEnabled = (enabledByTier[RuleTier.stylistic] ?? [])..sort();

  if (stylisticEnabled.isNotEmpty) {
    if (compact) {
      buffer.writeln(
        '      # STYLISTIC RULES (opt-in, ${stylisticEnabled.length} rules)',
      );
    } else {
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
    }
    for (final String rule in stylisticEnabled) {
      if (compact) {
        buffer.writeln('      $rule: true');
        continue;
      }
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

  // A previously-disabled block (sentinel-wrapped) is not matched by
  // _pluginsSectionPattern since its `plugins:` line is commented out.
  // Replace the whole bracketed region so regeneration is idempotent
  // whether the block is currently live or disabled.
  final Match? disabledBegin = _pluginsDisabledBeginPattern.firstMatch(
    existingContent,
  );
  if (disabledBegin != null) {
    final Match? disabledEnd = _pluginsDisabledEndPattern.firstMatch(
      existingContent,
    );
    if (disabledEnd != null && disabledEnd.start > disabledBegin.start) {
      final String before = existingContent.prefix(disabledBegin.start);
      final String after = existingContent.afterIndex(disabledEnd.end);
      return '$before$newPlugins\n$after';
    }
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
    final pattern = RegExp('''\\s+-\\s+['"]?$dirName/''', multiLine: true);
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
    return '${content.prefix(insertAt)}\n$lines\n${content.afterIndex(insertAt)}';
  }

  // No exclude section — look for `analyzer:` and add one
  final analyzerMatch = RegExp(
    r'^analyzer:\s*$',
    multiLine: true,
  ).firstMatch(content);

  if (analyzerMatch == null) return content;

  final afterAnalyzer = content.afterIndex(analyzerMatch.end);
  final firstLine = RegExp(
    r'^(\s+\S)',
    multiLine: true,
  ).firstMatch(afterAnalyzer);
  if (firstLine == null) return content;

  final insertAt = analyzerMatch.end + firstLine.start;
  final lines = missing.map((e) => '    - "$e"').join('\n');
  return '${content.prefix(insertAt)}  exclude:\n$lines\n${content.afterIndex(insertAt)}';
}
