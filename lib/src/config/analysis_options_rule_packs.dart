/// Parse `plugins.saropa_lints.rule_packs.enabled` from analysis_options text.
///
/// Shared by the native plugin config loader and init / write_config.
library;

/// Extracts pack ids from `rule_packs:` → `enabled:` under the plugin block.
///
/// Backward compatibility: accepts legacy `migration_packs` as a read-only alias.
/// If both keys exist, canonical `rule_packs` wins.
List<String> parseRulePacksEnabledList(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final primary = _parseEnabledListForKey(normalized, 'rule_packs');
  if (primary.isNotEmpty) return primary;
  return _parseEnabledListForKey(normalized, 'migration_packs');
}

List<String> _parseEnabledListForKey(String content, String key) {
  final lines = content.split('\n');
  final keyPattern = RegExp('^\\s*${RegExp.escape(key)}:\\s*(?:#.*)?\$');
  final enabledPattern = RegExp(r'^\s*enabled:\s*(?:#.*)?$');
  final itemPattern = RegExp(
    '^\\s*-\\s*["\\\']?([A-Za-z0-9_]+)["\\\']?\\s*(?:#.*)?\$',
  );

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!keyPattern.hasMatch(line)) continue;
    final keyIndent = _leadingSpaces(line);

    var enabledIndex = -1;
    var enabledIndent = -1;
    for (var j = i + 1; j < lines.length; j++) {
      final next = lines[j];
      final trimmed = next.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final indent = _leadingSpaces(next);
      if (indent <= keyIndent) break;
      if (enabledPattern.hasMatch(next)) {
        enabledIndex = j;
        enabledIndent = indent;
      }
      break;
    }
    if (enabledIndex == -1) continue;

    final out = <String>[];
    for (var k = enabledIndex + 1; k < lines.length; k++) {
      final row = lines[k];
      final trimmed = row.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final indent = _leadingSpaces(row);
      if (indent <= enabledIndent) break;
      final match = itemPattern.firstMatch(row);
      final id = match?.group(1);
      if (id != null) out.add(id);
    }
    return out;
  }
  return const [];
}

/// Counts leading whitespace (spaces and tabs).
///
/// YAML spec forbids tabs for indentation, but real-world files use them.
/// Counting only spaces broke block detection on tab-indented content —
/// both header and children computed indent=0, collapsing the hierarchy.
/// Matches the `_leadingWhitespace()` helper in `runtime_tier_cap.dart`.
int _leadingSpaces(String value) {
  var count = 0;
  while (count < value.length) {
    final c = value.codeUnitAt(count);
    // ASCII space (32) or tab (9).
    if (c != 32 && c != 9) break;
    count++;
  }
  return count;
}
