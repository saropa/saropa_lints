/// Detects stale `// ignore:` comments that suppress diagnostics which no
/// longer fire on the target line.
///
/// The scan CLI does not honor `// ignore:` directives — rules report
/// diagnostics regardless — so we can compare the set of ignore comments
/// against the actual diagnostics to identify stale suppressions.
///
/// Two Dart conventions are handled:
/// - Standalone `// ignore:` on its own line: suppresses the NEXT line.
/// - Inline `// ignore:` at the end of a code line: suppresses THAT line.
library;

import 'dart:convert';
import 'dart:io';

import 'package:saropa_lints/src/rule_name_utils.dart' show allSaropaRuleNames;

import 'scan_diagnostic.dart';

/// A single stale ignore finding: an ignore directive whose suppressed rule
/// did not produce a diagnostic on the target line.
class StaleIgnore {
  const StaleIgnore({
    required this.filePath,
    required this.commentLine,
    required this.targetLine,
    required this.ruleName,
    required this.commentText,
  });

  /// Path to the file containing the stale ignore.
  final String filePath;

  /// 1-based line number where the `// ignore:` comment appears.
  final int commentLine;

  /// 1-based line number the ignore was intended to suppress (same line for
  /// inline ignores, next line for standalone ignores).
  final int targetLine;

  /// The saropa rule name referenced in the ignore directive.
  final String ruleName;

  /// The full text of the ignore comment (trimmed).
  final String commentText;

  @override
  String toString() =>
      '$filePath:$commentLine  $ruleName  (target line '
      '$targetLine)  $commentText';
}

/// Normalizes a file path for use as a lookup key so that backslash vs
/// forward slash differences and drive-letter casing on Windows do not
/// cause silent match failures between diagnostic paths and parsed-file
/// paths.
String _normalizePath(String path) {
  // Normalize separators to forward slashes (Windows backslashes).
  var normalized = path.replaceAll(r'\', '/');

  // Lowercase the drive letter on Windows (e.g., 'D:/foo' -> 'd:/foo')
  // so that 'd:/src/file.dart' and 'D:/src/file.dart' produce the same key.
  if (normalized.length >= 2 &&
      normalized[1] == ':' &&
      normalized.codeUnitAt(0) >= 0x41 && // 'A'
      normalized.codeUnitAt(0) <= 0x5A) {
    // 'Z'
    normalized =
        String.fromCharCode(normalized.codeUnitAt(0) + 32) +
        normalized.substring(1);
  }

  return normalized;
}

/// Matches `// ignore:` directives (not `// ignore_for_file:`). Captures
/// everything after the colon so individual rule names can be extracted.
/// Anchored to `//` so it won't match inside strings or block comments.
final RegExp _ignoreLinePattern = RegExp(r'//\s*ignore\s*:\s*(.+)');

/// Splits a comma-separated rule list into individual names, stripping the
/// `saropa_lints/` plugin prefix when present so the name matches the
/// diagnostic's `ruleName` field.
List<String> _extractRuleNames(String ruleList) {
  return ruleList
      .split(',')
      .map((s) => s.trim())
      // Strip trailing rationale comments after ` -- ` (double dash only).
      // Single-dash ` - ` was removed because it could falsely truncate
      // multi-rule ignore lists or rationale text that starts with a dash.
      // Saropa rule names use underscores, so hyphens in a comment always
      // belong to the rationale, never to a rule name.
      .map((s) {
        final dashIdx = s.indexOf(' --');
        if (dashIdx >= 0) return s.substring(0, dashIdx).trim();
        return s;
      })
      // Remove plugin prefix so we match against bare rule names.
      .map((s) => s.startsWith('saropa_lints/') ? s.substring(13) : s)
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Returns true when [line] contains only a comment (no code before `//`).
bool _isStandaloneComment(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('//');
}

/// Parsed ignore directive from a source file, before staleness is checked.
class _IgnoreEntry {
  _IgnoreEntry({
    required this.filePath,
    required this.commentLine,
    required this.targetLine,
    required this.ruleName,
    required this.commentText,
  });

  final String filePath;
  final int commentLine;
  final int targetLine;
  final String ruleName;
  final String commentText;
}

/// Parses all `// ignore:` directives referencing saropa_lints rules from
/// [content]. Returns one entry per rule name per ignore comment.
///
/// Only includes rules that exist in the saropa_lints registry — ignore
/// directives for core Dart lints or unknown names are skipped, since we
/// can only verify staleness for rules the scan actually runs.
List<_IgnoreEntry> _parseIgnoreComments(String content, String filePath) {
  final lines = content.split('\n');
  final entries = <_IgnoreEntry>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final match = _ignoreLinePattern.firstMatch(line);
    if (match == null) continue;

    // Skip doc comments (`///`). A dartdoc example showing
    // `// ignore: rule_name` would otherwise be detected as a real
    // ignore directive. String-literal detection is not handled here
    // because it is low risk and would require full parsing.
    if (line.trimLeft().startsWith('///')) continue;

    // Skip `// ignore_for_file:` — those require whole-file analysis and
    // are deferred to a future enhancement.
    if (line.contains('ignore_for_file')) continue;

    final commentLine = i + 1; // 1-based
    final ruleNames = _extractRuleNames(match.group(1)!);
    final commentText = line.trim();

    // Standalone comment (only `//` on the line): suppresses the next line.
    // Inline comment (code before `//`): suppresses the same line.
    final standalone = _isStandaloneComment(line);
    final targetLine = standalone ? commentLine + 1 : commentLine;

    for (final name in ruleNames) {
      // Only track saropa rules — we can't verify staleness for rules
      // outside the saropa_lints registry.
      if (!allSaropaRuleNames.contains(name)) continue;

      entries.add(
        _IgnoreEntry(
          filePath: filePath,
          commentLine: commentLine,
          targetLine: targetLine,
          ruleName: name,
          commentText: commentText,
        ),
      );
    }
  }
  return entries;
}

/// Detects stale `// ignore:` comments across the given [files] by comparing
/// them against [diagnostics] from a scan run.
///
/// A stale ignore is one where the scan did not produce a diagnostic for the
/// referenced rule on the target line — meaning the diagnostic no longer fires
/// and the ignore comment is dead weight.
List<StaleIgnore> detectStaleIgnores({
  required List<ScanDiagnostic> diagnostics,
  required List<String> files,
}) {
  // Build a lookup: (filePath, line) -> set of rule names that fired.
  // This makes per-ignore checking O(1) instead of scanning the full
  // diagnostics list for each ignore comment.
  // Paths are normalized so backslash/forward-slash and drive-letter
  // casing differences on Windows do not cause silent key mismatches.
  final firedRules = <String, Set<String>>{};
  for (final d in diagnostics) {
    // Key by "normalizedPath:line" for fast lookup.
    final key = '${_normalizePath(d.filePath)}:${d.line}';
    firedRules.putIfAbsent(key, () => <String>{}).add(d.ruleName);
  }

  final stale = <StaleIgnore>[];

  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;

    final content = file.readAsStringSync();
    final entries = _parseIgnoreComments(content, filePath);

    for (final entry in entries) {
      // Normalize to match the diagnostic-side keys built above.
      final key = '${_normalizePath(entry.filePath)}:${entry.targetLine}';
      final rulesOnLine = firedRules[key];

      // If no diagnostic with this rule name fired on the target line,
      // the ignore is stale.
      if (rulesOnLine == null || !rulesOnLine.contains(entry.ruleName)) {
        stale.add(
          StaleIgnore(
            filePath: entry.filePath,
            commentLine: entry.commentLine,
            targetLine: entry.targetLine,
            ruleName: entry.ruleName,
            commentText: entry.commentText,
          ),
        );
      }
    }
  }

  return stale;
}

/// Result of fixing stale ignores in a single file: tracks the count of
/// removed ignore directives and the rewritten file content.
class StaleIgnoreFixResult {
  const StaleIgnoreFixResult({
    required this.filePath,
    required this.removedCount,
  });

  /// Path to the file that was modified.
  final String filePath;

  /// Number of stale ignore directives removed from this file.
  final int removedCount;
}

/// Removes stale ignore directives from the source files they appear in.
///
/// For each stale ignore:
/// - Standalone comment (entire line is `// ignore: ...`): removes the line.
/// - Inline comment (code before `// ignore: ...`): strips the ignore portion,
///   preserving the code.
/// - Multi-rule ignore where only SOME rules are stale: removes only the stale
///   rule names from the comma-separated list, keeping the non-stale ones.
///
/// Returns one [StaleIgnoreFixResult] per modified file. Files with no
/// modifications (e.g. all ignores already removed by a prior pass) are
/// excluded from the result.
List<StaleIgnoreFixResult> fixStaleIgnores(List<StaleIgnore> staleIgnores) {
  if (staleIgnores.isEmpty) return [];

  // Group by file so we process each file once, applying all removals in a
  // single pass from bottom to top (reverse line order prevents index shift).
  final byFile = <String, List<StaleIgnore>>{};
  for (final s in staleIgnores) {
    byFile.putIfAbsent(s.filePath, () => []).add(s);
  }

  final results = <StaleIgnoreFixResult>[];

  for (final entry in byFile.entries) {
    final result = _fixFileStaleIgnores(entry.key, entry.value);
    if (result != null) results.add(result);
  }

  return results;
}

/// Applies stale-ignore removals to a single file. Returns null if the file
/// could not be read or no changes were made.
StaleIgnoreFixResult? _fixFileStaleIgnores(
  String filePath,
  List<StaleIgnore> staleIgnores,
) {
  final file = File(filePath);
  if (!file.existsSync()) return null;

  final content = file.readAsStringSync();
  final lines = content.split('\n');
  var removedCount = 0;

  // Group stale ignores by comment line so multi-rule lines get one pass.
  final byCommentLine = <int, List<StaleIgnore>>{};
  for (final s in staleIgnores) {
    byCommentLine.putIfAbsent(s.commentLine, () => []).add(s);
  }

  // Process lines bottom-to-top so removing a line doesn't shift the indices
  // of lines we haven't processed yet.
  final sortedLines = byCommentLine.keys.toList()
    ..sort((a, b) => b.compareTo(a));

  for (final commentLine in sortedLines) {
    final staleOnLine = byCommentLine[commentLine]!;
    final lineIdx = commentLine - 1; // Convert 1-based to 0-based.
    if (lineIdx < 0 || lineIdx >= lines.length) continue;

    final removed = _processLine(lines, lineIdx, staleOnLine);
    removedCount += removed;
  }

  if (removedCount == 0) return null;

  // Write back with the same line-ending style. The split('\n') + join('\n')
  // preserves LF; if the original used CRLF, the \r is kept as part of each
  // line element (split only on \n).
  file.writeAsStringSync(lines.join('\n'));

  return StaleIgnoreFixResult(filePath: filePath, removedCount: removedCount);
}

/// Processes a single source line that contains stale ignore directives.
/// Mutates [lines] in place. Returns the number of stale rules removed.
int _processLine(
  List<String> lines,
  int lineIdx,
  List<StaleIgnore> staleOnLine,
) {
  final line = lines[lineIdx];
  final match = _ignoreLinePattern.firstMatch(line);
  if (match == null) return 0;

  // Parse all rule names on this ignore comment to decide whether we remove
  // the entire comment or just prune specific rules from the list.
  final allRuleNames = _extractRuleNames(match.group(1)!);
  final staleNames = staleOnLine.map((s) => s.ruleName).toSet();

  // Determine how many of the rules on this comment are stale.
  final staleOnThisComment = allRuleNames.where(staleNames.contains).toList();

  if (staleOnThisComment.length >= allRuleNames.length) {
    // ALL rules on this comment are stale — remove the entire ignore.
    _removeEntireIgnore(lines, lineIdx, line);
    // Return the count of stale rules on this comment, not 1, so the
    // per-file tally matches the number of StaleIgnore entries resolved.
    return staleOnThisComment.length;
  }

  // Only some rules are stale — prune them from the comma-separated list,
  // keeping the non-stale rules intact.
  return _pruneStaleRules(lines, lineIdx, line, match, staleOnThisComment);
}

/// Removes an entire ignore comment from the line. If the line is standalone
/// (only a comment), deletes the whole line. If inline, strips the comment
/// portion and preserves the code.
void _removeEntireIgnore(List<String> lines, int lineIdx, String line) {
  if (_isStandaloneComment(line)) {
    // Standalone comment — remove the entire line.
    lines.removeAt(lineIdx);
  } else {
    // Inline comment — strip everything from `// ignore:` onward, preserving
    // the code portion. Also trim trailing whitespace left behind.
    final commentStart = line.indexOf(_ignoreLinePattern);
    lines[lineIdx] = line.substring(0, commentStart).trimRight();
  }
}

/// Removes only the [staleRules] from a multi-rule ignore comment, keeping
/// the non-stale rules. Preserves the `// ignore:` prefix and any rationale
/// comments that follow the rule list.
int _pruneStaleRules(
  List<String> lines,
  int lineIdx,
  String line,
  RegExpMatch match,
  List<String> staleRules,
) {
  final ruleListRaw = match.group(1)!;

  // Rebuild the rule list without the stale names. We work on the raw
  // comma-separated segments to preserve spacing and any trailing rationale.
  final segments = ruleListRaw.split(',').map((s) => s.trim()).toList();
  final staleSet = staleRules.toSet();

  final kept = <String>[];
  for (final seg in segments) {
    // Strip the prefix for comparison but keep the original segment text.
    final bare = seg.startsWith('saropa_lints/') ? seg.substring(13) : seg;
    // Also strip trailing rationale for matching purposes.
    final bareName = _stripRationale(bare);
    if (!staleSet.contains(bareName)) {
      kept.add(seg);
    }
  }

  if (kept.isEmpty) {
    // Edge case: all rules pruned (shouldn't happen since caller checks,
    // but defensive). Remove the whole comment.
    _removeEntireIgnore(lines, lineIdx, line);
    return staleRules.length;
  }

  // Reconstruct the line with the pruned rule list.
  final ignoreStart = line.indexOf(_ignoreLinePattern);
  // Capture the prefix (code or whitespace before `// ignore:`).
  final prefix = line.substring(0, ignoreStart);
  final newRuleList = kept.join(', ');
  lines[lineIdx] = '$prefix// ignore: $newRuleList';

  return staleRules.length;
}

/// Strips trailing rationale text (` -- reason`) from a rule name segment
/// for comparison purposes. Only double-dash is stripped — see the comment
/// in [_extractRuleNames] for why single-dash was removed.
String _stripRationale(String segment) {
  final dashIdx = segment.indexOf(' --');
  if (dashIdx >= 0) return segment.substring(0, dashIdx).trim();
  return segment;
}

/// Serializes [staleIgnores] to the JSON format compatible with the scan
/// CLI's `--format json` output convention.
String staleIgnoresToJsonString(List<StaleIgnore> staleIgnores) {
  final list = staleIgnores
      .map(
        (s) => <String, Object>{
          'filePath': s.filePath,
          'commentLine': s.commentLine,
          'targetLine': s.targetLine,
          'ruleName': s.ruleName,
          'commentText': s.commentText,
        },
      )
      .toList();

  // Group by file for the summary, same pattern as scan diagnostics.
  final byFile = <String, int>{};
  final byRule = <String, int>{};
  for (final s in staleIgnores) {
    byFile[s.filePath] = (byFile[s.filePath] ?? 0) + 1;
    byRule[s.ruleName] = (byRule[s.ruleName] ?? 0) + 1;
  }

  return const JsonEncoder.withIndent('  ').convert(<String, Object>{
    'version': 1,
    'staleIgnores': list,
    'summary': <String, Object>{
      'totalCount': staleIgnores.length,
      'byFile': byFile,
      'byRule': byRule,
    },
  });
}
