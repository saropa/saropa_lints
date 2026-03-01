// ignore_for_file: depend_on_referenced_packages

/// Configuration for the [BannedUsageRule].
///
/// Populated from `analysis_options_custom.yaml` under `banned_usage: entries:`.
/// When empty, the rule is a no-op (no reports). Loaded once at plugin start via
/// [loadBannedUsageConfig] from `config_loader`. Rule reads [bannedUsageEntries]
/// at run time; no race because analysis is single-threaded per plugin.
///
/// **Config format:** See [loadBannedUsageConfig]. Parsing is line-based and
/// does not support full YAML; list items must use `- identifier: 'id'` and
/// optional `reason: '...'` on the next line.
library;

/// A single banned identifier entry.
class BannedUsageEntry {
  const BannedUsageEntry({
    required this.identifier,
    required this.reason,
    this.allowedFiles,
  });

  final String identifier;
  final String reason;
  final List<String>? allowedFiles;

  /// Whole-word match: [name] equals [identifier] (e.g. `print` matches
  /// `print` but not `_print` or `println`).
  bool matchesName(String name) => name == identifier;
}

/// Configured bans. Set by [loadBannedUsageConfig] from config_loader.
List<BannedUsageEntry> bannedUsageEntries = [];

/// Parse `banned_usage:` section from content and populate [bannedUsageEntries].
/// Called from config_loader during plugin start.
///
/// Expects format:
/// ```yaml
/// banned_usage:
///   entries:
///     - identifier: 'print'
///       reason: 'Use Logger instead'
/// ```
void loadBannedUsageConfig(String? content) {
  bannedUsageEntries = [];
  if (content == null || content.isEmpty) return;

  final sectionMatch = RegExp(
    r'^banned_usage:\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (sectionMatch == null) return;

  final afterSection = content.substring(sectionMatch.end);
  final entriesMatch = RegExp(
    r'^\s+entries:\s*$',
    multiLine: true,
  ).firstMatch(afterSection);
  if (entriesMatch == null) return;

  final lines = afterSection.substring(entriesMatch.end).split('\n');
  String? currentId;
  String? currentReason;

  final idPattern = RegExp(
    '^\\s*-\\s*identifier:\\s*["\']?([^"\'\\s]+)["\']?\\s*\$',
  );
  final reasonPattern = RegExp('^\\s+reason:\\s*["\']?(.+?)["\']?\\s*\$');
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final idMatch = idPattern.firstMatch(line);
    if (idMatch != null) {
      if (currentId != null && currentReason != null) {
        bannedUsageEntries.add(
          BannedUsageEntry(identifier: currentId, reason: currentReason),
        );
      }
      currentId = idMatch.group(1);
      currentReason = 'Banned by project configuration.';
      continue;
    }
    final reasonMatch = reasonPattern.firstMatch(line);
    if (reasonMatch != null && currentId != null) {
      currentReason = reasonMatch.group(1)!.trim();
    }
  }
  if (currentId != null && currentReason != null) {
    bannedUsageEntries.add(
      BannedUsageEntry(identifier: currentId, reason: currentReason),
    );
  }
}
