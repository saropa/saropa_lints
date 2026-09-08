/// User-configurable allowlist additions for `avoid_ignoring_return_values`.
///
/// Populated from `analysis_options_custom.yaml` under
/// `avoid_ignoring_return_values: safe_to_ignore:`. Lets a project add its own
/// method names that are safe to call without using the return value — the
/// built-in allowlist only covers stdlib collection mutators and IO methods.
/// Loaded once at plugin start via [loadAvoidIgnoringReturnValuesConfig] from
/// config_loader, mirroring [loadBannedUsageConfig]'s line-based parsing style.
/// Rule reads [userSafeToIgnoreMethods] at run time; no race because analysis
/// is single-threaded per plugin.
///
/// **Config format:** Parsing is line-based and does not support full YAML;
/// each entry must be a simple `- methodName` list item.
library;

/// User-configured safe-to-ignore method names. Set by
/// [loadAvoidIgnoringReturnValuesConfig]. Empty by default (no-op) so a
/// project that never adds this section sees no behavior change.
Set<String> userSafeToIgnoreMethods = <String>{};

/// Parse `avoid_ignoring_return_values: safe_to_ignore:` section from content
/// and populate [userSafeToIgnoreMethods]. Called from config_loader during
/// plugin start.
///
/// Expects format:
/// ```yaml
/// avoid_ignoring_return_values:
///   safe_to_ignore:
///     - appendNamePart
///     - myCustomMethod
/// ```
void loadAvoidIgnoringReturnValuesConfig(String? content) {
  if (content == null || content.trim().isEmpty) {
    userSafeToIgnoreMethods = <String>{};
    return;
  }

  // Find the top-level section key.
  final sectionMatch = RegExp(
    r'^avoid_ignoring_return_values:\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (sectionMatch == null) {
    userSafeToIgnoreMethods = <String>{};
    return;
  }

  final afterSection = content.substring(sectionMatch.end);

  // Find the `safe_to_ignore:` sub-key.
  final listMatch = RegExp(
    r'^\s+safe_to_ignore:\s*$',
    multiLine: true,
  ).firstMatch(afterSection);
  if (listMatch == null) {
    userSafeToIgnoreMethods = <String>{};
    return;
  }

  // Build locally, assign once — avoids a window where the set is empty
  // if config is reloaded while analysis is in flight (e.g. hot-reload).
  final result = <String>{};
  final lines = afterSection.substring(listMatch.end).split('\n');
  final itemPattern = RegExp(
    r'''^\s+-\s+['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?\s*$''',
  );
  for (final line in lines) {
    final trimmed = line.trim();
    // Skip blank lines and YAML comments between list items.
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final match = itemPattern.firstMatch(line);
    // Stop at the first non-list, non-comment line (end of section).
    if (match == null) break;
    // Each list item is one method name to exempt from the rule.
    final name = match.group(1);
    if (name != null) result.add(name);
  }
  userSafeToIgnoreMethods = result;
}
