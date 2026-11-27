/// Evidence the stale-ignore check needs before it may call a `// ignore:`
/// comment stale.
///
/// The reporter drops a finding a comment covers before the scan ever sees
/// it, so "no finding on the target line" is not proof on its own: the
/// comment may be the very thing hiding it. [StaleIgnoreProbe] switches the
/// reporter into a mode that reports every finding and notes the ones a
/// comment would have hidden; [StaleIgnoreCoverage] carries what the scan
/// actually covered. A comment is stale only when both say so.
///
/// Kept free of heavy imports: the reporter (loaded by the analyzer plugin)
/// imports this file.
library;

/// Lookup key for a file path: forward slashes and a lowercase Windows drive
/// letter, so a path from the file list and the same path from the analyzer
/// compare equal.
String staleIgnorePathKey(String path) {
  final normalized = path.replaceAll(r'\', '/');
  // 'D:/src' and 'd:/src' are the same file on Windows.
  if (normalized.length >= 2 && normalized[1] == ':') {
    return normalized[0].toLowerCase() + normalized.substring(1);
  }
  return normalized;
}

/// Process-wide switch for the stale-ignore scan.
///
/// While active, the reporter skips every suppression (baseline, accepted
/// list, `// ignore_for_file:`, `// ignore:`, issue cap) so each finding
/// reaches the diagnostic list at its real line, and records the findings a
/// line-level `// ignore:` would have hidden. Only the scan CLI's stale modes
/// turn it on; they run in one process (no worker isolates), so a static is
/// visible to every rule.
abstract final class StaleIgnoreProbe {
  static bool _active = false;

  /// `file key\nrule` -> lines where a comment hid a finding of that rule.
  static final Map<String, Set<int>> _commentHidden = {};

  /// Rules with a comment-hidden finding whose position was unknown. Every
  /// comment for such a rule is unjudgeable.
  static final Set<String> _unlocated = {};

  /// Whether the reporter must report everything (see class doc).
  static bool get active => _active;

  /// Arms the probe with empty records.
  static void start() {
    _active = true;
    _commentHidden.clear();
    _unlocated.clear();
  }

  /// Disarms the probe and drops its records.
  static void stop() {
    _active = false;
    _commentHidden.clear();
    _unlocated.clear();
  }

  /// Notes that a `// ignore:` comment would have hidden a finding of [rule]
  /// at [line] of [path]. A null [path] means the position is unknown.
  static void recordCommentHidden(String rule, String? path, int line) {
    if (path == null) {
      _unlocated.add(rule);
      return;
    }
    _commentHidden
        .putIfAbsent('${staleIgnorePathKey(path)}\n$rule', () => <int>{})
        .add(line);
  }

  /// Snapshot of the records, for [StaleIgnoreCoverage].
  static ({Map<String, Set<int>> hidden, Set<String> unlocated}) snapshot() => (
    hidden: {
      for (final e in _commentHidden.entries) e.key: {...e.value},
    },
    unlocated: {..._unlocated},
  );
}

/// What one stale-ignore scan covered. Every check answers "may this comment
/// be judged?"; anything not positively covered is kept.
class StaleIgnoreCoverage {
  StaleIgnoreCoverage({
    required this.rulesRun,
    required Set<String> filesWalked,
    required Set<String> ruleFileFailures,
    Map<String, Set<int>> commentHidden = const {},
    Set<String> unlocatedRules = const {},
  }) : _filesWalked = {for (final f in filesWalked) staleIgnorePathKey(f)},
       _failures = ruleFileFailures,
       _commentHidden = commentHidden,
       _unlocated = unlocatedRules;

  /// Rules that registered visitors and ran. A rule outside this set (not in
  /// the tier, disabled, failed to register) proves nothing.
  final Set<String> rulesRun;

  /// Files whose walk finished (keys from [staleIgnorePathKey]).
  final Set<String> _filesWalked;

  /// `file key\nrule` pairs where the rule threw and stopped mid-file.
  final Set<String> _failures;

  /// See [StaleIgnoreProbe.recordCommentHidden].
  final Map<String, Set<int>> _commentHidden;
  final Set<String> _unlocated;

  /// Builds the failure key [ruleFileFailures] uses.
  static String failureKey(String path, String rule) =>
      '${staleIgnorePathKey(path)}\n$rule';

  /// How many of [paths] the scan walked to the end, for the CLI's "kept
  /// unjudged" note.
  int walkedCount(Iterable<String> paths) =>
      paths.where((f) => _filesWalked.contains(staleIgnorePathKey(f))).length;

  /// Whether a comment for [rule] in [path] may be judged at all.
  ///
  /// [ruleTargets] are the lines every `// ignore:` naming [rule] in that
  /// file points at. When a comment hid a finding on any OTHER line, the
  /// reporter honored a comment the line-based parser cannot place (e.g. one
  /// above a second comment line), so no comment for [rule] in the file can
  /// be safely called stale.
  bool canJudge(String path, String rule, Set<int> ruleTargets) {
    if (!rulesRun.contains(rule) || _unlocated.contains(rule)) return false;
    final key = staleIgnorePathKey(path);
    if (!_filesWalked.contains(key)) return false;
    if (_failures.contains('$key\n$rule')) return false;
    final hidden = _commentHidden['$key\n$rule'];
    return hidden == null || ruleTargets.containsAll(hidden);
  }
}
