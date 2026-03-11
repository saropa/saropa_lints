/// V4/V7 migration detection and conversion.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/config_writer.dart'
    show topLevelKeyPattern;
import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';

/// Matches the `custom_lint:` section header (v4 format) in YAML.
final RegExp _customLintSectionPattern = RegExp(
  r'^custom_lint:\s*$',
  multiLine: true,
);

/// Matches v4 rule entries.
final RegExp _v4RuleEntryPattern = RegExp(
  r'^\s+-?\s*([\w_]+):\s*(true|false)',
  multiLine: true,
);

/// Matches `- custom_lint` line in the `analyzer: plugins:` section.
final RegExp _analyzerCustomLintLine = RegExp(
  r'^\s+-\s*custom_lint\s*$',
  multiLine: true,
);



// ---------------------------------------------------------------------------
// V4 (custom_lint) auto-migration
// ---------------------------------------------------------------------------

/// Detects whether the YAML content contains a v4 `custom_lint:` section.
bool detectV4Config(String yamlContent) {
  return _customLintSectionPattern.hasMatch(yamlContent);
}

/// Extracts rule settings from a v4 `custom_lint:` section.
///
/// Handles both v4 formats:
/// - Plain: `rule_name: true`
/// - List:  `- rule_name: true`
///
/// Only returns rules that exist in [allRules].
Map<String, bool> extractV4Rules(String yamlContent, Set<String> allRules) {
  final Map<String, bool> rules = <String, bool>{};

  final Match? sectionMatch = _customLintSectionPattern.firstMatch(yamlContent);

  if (sectionMatch == null) return rules;

  // Get content from custom_lint: until next top-level key or EOF
  final String afterSection = yamlContent.substring(sectionMatch.end);
  final Match? nextTopLevel = topLevelKeyPattern.firstMatch(afterSection);
  final String sectionContent = nextTopLevel != null
      ? afterSection.substring(0, nextTopLevel.start)
      : afterSection;

  for (final Match match in _v4RuleEntryPattern.allMatches(sectionContent)) {
    final rawName = match.group(1);
    if (rawName == null) continue;
    final String ruleName = rawName.toLowerCase();
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
String removeCustomLintSection(String content) {
  final Match? sectionMatch = _customLintSectionPattern.firstMatch(content);

  if (sectionMatch == null) return content;

  final String before = content.substring(0, sectionMatch.start);
  final String afterStart = content.substring(sectionMatch.end);
  final Match? nextTopLevel = topLevelKeyPattern.firstMatch(afterStart);
  final String after =
      nextTopLevel != null ? afterStart.substring(nextTopLevel.start) : '';

  return '${before.trimRight()}\n\n$after'.trimRight() + '\n';
}

/// Removes `- custom_lint` from the `analyzer: plugins:` section.
/// Also removes the `plugins:` sub-key if it becomes empty.
String removeAnalyzerCustomLintPlugin(String content) {
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
void cleanPubspecCustomLint({required bool dryRun}) {
  final File pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) return;

  final String content = pubspecFile.readAsStringSync();

  // Only match custom_lint inside the dev_dependencies section
  final String? cleaned = removeDevDep(content, 'custom_lint');

  if (cleaned == null) return;

  log.terminal('');

  // Skip prompts in non-interactive mode (CI, piped input)
  if (!stdin.hasTerminal) {
    log.terminal(
      '${InitColors.dim}  Non-interactive: skipping pubspec.yaml '
      'cleanup (remove custom_lint manually)${InitColors.reset}',
    );
    return;
  }

  stdout.write(
    '${InitColors.cyan}Remove custom_lint from pubspec.yaml '
    'dev_dependencies? [y/N]: ${InitColors.reset}',
  );
  final String response = stdin.readLineSync()?.toLowerCase().trim() ?? '';

  if (response != 'y' && response != 'yes') {
    log.terminal(
      '${InitColors.dim}  Skipped pubspec.yaml cleanup${InitColors.reset}',
    );
    return;
  }

  if (dryRun) {
    log.terminal(
      '${InitColors.dim}  (dry-run) Would remove custom_lint from '
      'pubspec.yaml${InitColors.reset}',
    );
    return;
  }

  pubspecFile.writeAsStringSync(cleaned);
  log.terminal(
    '${InitColors.green}Removed custom_lint from pubspec.yaml${InitColors.reset}',
  );
  log.terminal(
    '${InitColors.dim}  Run dart pub get to update dependencies${InitColors.reset}',
  );
}

/// Removes a dependency line from the dev_dependencies section only.
/// Returns the modified content, or null if the dependency was not found.
String? removeDevDep(String content, String packageName) {
  final RegExp devDepsHeader = RegExp(
    r'^dev_dependencies:\s*$',
    multiLine: true,
  );
  final Match? devMatch = devDepsHeader.firstMatch(content);

  if (devMatch == null) return null;

  // Find the section boundaries
  final String afterDevDeps = content.substring(devMatch.end);
  final Match? nextSection = topLevelKeyPattern.firstMatch(afterDevDeps);
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
  final String after =
      nextSection != null ? afterDevDeps.substring(nextSection.start) : '';

  return '$before$cleanedSection$after';
}

/// Converts v4 ignore comments to v5 format in .dart files.
///
/// Changes `// ignore: rule_name` to `// ignore: saropa_lints/rule_name`.
/// Only converts rules that exist in [allRules].
/// Returns a map of file path to number of conversions made.
Map<String, int> convertIgnoreComments(Set<String> allRules, bool dryRun) {
  final Map<String, int> results = <String, int>{};

  for (final String dirName in const ['lib', 'test', 'bin']) {
    final Directory dir = Directory(dirName);
    if (!dir.existsSync()) continue;

    for (final FileSystemEntity entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final int count = convertIgnoreCommentsInFile(entity, allRules, dryRun);
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
int convertIgnoreCommentsInFile(File file, Set<String> allRules, bool dryRun) {
  final String content = file.readAsStringSync();
  int count = 0;

  final String newContent = content.replaceAllMapped(_ignoreDirectivePattern, (
    Match match,
  ) {
    final prefix = match.group(1);
    final ruleList = match.group(2);
    if (prefix == null || ruleList == null) return match.group(0) ?? '';

    final String converted = ruleList.splitMapJoin(
      RegExp(r'[\w_/]+'),
      onMatch: (Match m) {
        final name = m.group(0);
        if (name == null) return '';
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
