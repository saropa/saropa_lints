/// User-configurable allowlist for `require_ios_accessibility_large_text`.
///
/// Populated from `analysis_options_custom.yaml` under
/// `require_ios_accessibility_large_text: scaling_aware:`. Lets a project
/// declare getter/method names that are known to apply Dynamic Type scaling
/// internally — the rule will not flag these even though they resolve to
/// non-const elements.
///
/// Loaded once at plugin start via [loadRequireIosAccessibilityLargeTextConfig]
/// from config_loader, mirroring [loadBannedUsageConfig]'s line-based parsing.
/// Rule reads [userScalingAwareMethods] at run time; no race because analysis
/// is single-threaded per plugin.
///
/// **Config format:** Parsing is line-based and does not support full YAML;
/// each entry must be a simple `- methodOrGetterName` list item.
library;

/// User-configured Dynamic-Type-scaling-aware method/getter names. Set by
/// [loadRequireIosAccessibilityLargeTextConfig]. Empty by default (no-op) so
/// a project that never adds this section sees no behavior change.
Set<String> userScalingAwareMethods = <String>{};

/// Parse `require_ios_accessibility_large_text: scaling_aware:` section from
/// content and populate [userScalingAwareMethods]. Called from config_loader
/// during plugin start.
///
/// Expects format:
/// ```yaml
/// require_ios_accessibility_large_text:
///   scaling_aware:
///     - size
///     - scaledFontSize
/// ```
void loadRequireIosAccessibilityLargeTextConfig(String? content) {
  if (content == null || content.trim().isEmpty) {
    userScalingAwareMethods = <String>{};
    return;
  }

  // Find the top-level section key.
  final sectionMatch = RegExp(
    r'^require_ios_accessibility_large_text:\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (sectionMatch == null) {
    userScalingAwareMethods = <String>{};
    return;
  }

  final afterSection = content.substring(sectionMatch.end);

  // Find the `scaling_aware:` sub-key.
  final listMatch = RegExp(
    r'^\s+scaling_aware:\s*$',
    multiLine: true,
  ).firstMatch(afterSection);
  if (listMatch == null) {
    userScalingAwareMethods = <String>{};
    return;
  }

  // Build locally, assign once — avoids a window where the set is empty
  // if config is reloaded while analysis is in flight.
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
    // Each list item is one getter/method name to treat as scaling-aware.
    final name = match.group(1);
    if (name != null) result.add(name);
  }
  userScalingAwareMethods = result;
}
