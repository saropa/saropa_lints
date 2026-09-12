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

  // Bound the sub-key search to this section's own indented block. Without
  // the bound, a `safe_to_ignore:` belonging to a *later* top-level section
  // would be silently adopted as this rule's allowlist. A top-level key is
  // any line starting in column 0 with something other than whitespace or a
  // `#` comment, so the block ends at the first such line.
  final afterSection = _sectionBlock(content.substring(sectionMatch.end));

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

/// The indented body of a top-level YAML section, given everything that
/// follows the section's own header line. Stops at the first line that begins
/// a new top-level key — i.e. starts in column 0 with a non-whitespace,
/// non-`#` character — so a sibling section's sub-keys are never mistaken for
/// this section's.
String _sectionBlock(String afterSectionHeader) {
  final lines = afterSectionHeader.split('\n');
  final kept = <String>[];
  // Skip index 0: it is the remainder of the header line itself (empty,
  // since the header regex anchors to end-of-line), not a body line.
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty) {
      kept.add(line);
      continue;
    }
    final first = line.codeUnitAt(0);
    final startsIndented = first == 0x20 || first == 0x09; // space or tab
    if (!startsIndented && !line.startsWith('#')) break;
    kept.add(line);
  }
  // Lead with a newline so the first kept line still has a line start for
  // `^\s+safe_to_ignore:` to anchor against. (`lines.first` is always empty:
  // the header regex ends the match at a line end, so nothing of the header
  // line survives into the substring.)
  return '\n${kept.join('\n')}';
}
