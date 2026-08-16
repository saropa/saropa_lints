// ignore_for_file: depend_on_referenced_packages

import '../src/tiers.dart' as tiers;

/// Utilities for matching unknown rule names against the saropa_lints registry.
/// Used by both the require_ignore_comment_plugin_prefix rule and its quick fix
/// to suggest corrections for typo'd or renamed rule names.

/// All registered saropa_lints rule names, cached once at startup.
final Set<String> allSaropaRuleNames = tiers.getAllDefinedRules();

/// Returns the closest registered rule name if its edit distance is within
/// a proportional threshold, or null if nothing is close enough.
///
/// Threshold scales with name length: short names (≤10 chars) allow ≤2 edits,
/// medium names (≤20) allow ≤3, longer names allow ≤5. This prevents short
/// names from matching unrelated rules that happen to share a common prefix.
String? closestRuleName(String unknown) {
  // Proportional threshold — stricter for short names to avoid false matches.
  final int maxDistance = unknown.length <= 10
      ? 2
      : unknown.length <= 20
      ? 3
      : 5;
  String? best;
  int bestDist = maxDistance + 1;

  for (final rule in allSaropaRuleNames) {
    // Skip candidates that differ too much in length to ever be ≤ max.
    final lengthDiff = (rule.length - unknown.length).abs();
    if (lengthDiff > maxDistance) continue;

    final dist = editDistance(unknown, rule);
    if (dist < bestDist) {
      bestDist = dist;
      best = rule;
    }
  }
  return best;
}

/// Standard Levenshtein edit distance — O(m × n) where m and n are
/// string lengths. Adequate here because rule names are short (~30 chars)
/// and the call is made at most once per diagnostic, not per token.
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Single-row DP — only need the previous row at each step.
  final int m = a.length;
  final int n = b.length;
  List<int> prev = List<int>.generate(n + 1, (i) => i);
  List<int> curr = List<int>.filled(n + 1, 0);

  for (int i = 1; i <= m; i++) {
    curr[0] = i;
    for (int j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        prev[j] + 1,
        curr[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((a, b) => a < b ? a : b);
    }
    // Swap rows.
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}
