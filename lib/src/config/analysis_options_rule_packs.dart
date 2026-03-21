/// Parse `plugins.saropa_lints.rule_packs.enabled` from analysis_options text.
///
/// Shared by the native plugin config loader and init / write_config.
library;

/// Extracts pack ids from `rule_packs:` → `enabled:` under the plugin block.
List<String> parseRulePacksEnabledList(String content) {
  final normalized =
      content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final m = RegExp(
    r'rule_packs:\s*\n\s*enabled:\s*\n((?:\s+-\s+\w+\s*\n)+)',
    multiLine: true,
  ).firstMatch(normalized);
  if (m == null) return const [];
  final block = m.group(1)!;
  return RegExp(r'-\s+(\w+)')
      .allMatches(block)
      .map((Match x) => x.group(1)!)
      .toList();
}
