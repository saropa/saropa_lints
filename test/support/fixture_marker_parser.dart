// Parses `// LINT:`, `// LINT_MESSAGE:`, `// LINT_NOT:`, and `// LINT_COUNT:`
// markers from fixture source code.
//
// `// LINT: rule_name` declares that a diagnostic from `rule_name` is expected
// on the next non-marker line. An optional `// LINT_MESSAGE: substring` on the
// line immediately following adds a message-content assertion.
//
// `// LINT_NOT: rule_name` declares that the rule must NOT fire on the next
// line — a declarative false-positive guard.
//
// `// LINT_COUNT: rule_name N` declares that exactly N diagnostics from
// `rule_name` must fire across the entire fixture — catches both false
// positives (too many) and false negatives (too few).
//
// All markers require `//` at the start of the (trimmed) line so they cannot
// false-match inside string literals or multi-line comments.
library;

/// Parsed positive expectation from `// LINT:` with optional `// LINT_MESSAGE:`.
class FixtureExpectation {
  const FixtureExpectation({
    required this.ruleName,
    required this.targetLine,
    this.messageSubstring,
  });

  /// The rule code expected to fire (from `// LINT: <rule>`).
  final String ruleName;

  /// 1-based line number where the diagnostic should appear — the first
  /// non-marker line after the `// LINT:` / `// LINT_MESSAGE:` block.
  final int targetLine;

  /// When non-null, the diagnostic's `problemMessage` must contain this
  /// substring (from `// LINT_MESSAGE: <substring>`).
  final String? messageSubstring;

  @override
  String toString() {
    final msg = messageSubstring != null ? ' message≈"$messageSubstring"' : '';
    return 'LINT:$ruleName@$targetLine$msg';
  }
}

/// Parsed negative expectation from `// LINT_NOT:` — rule must NOT fire here.
class FixtureNegation {
  const FixtureNegation({required this.ruleName, required this.targetLine});

  /// The rule code that must NOT fire (from `// LINT_NOT: <rule>`).
  final String ruleName;

  /// 1-based line number where the diagnostic must NOT appear.
  final int targetLine;

  @override
  String toString() => 'LINT_NOT:$ruleName@$targetLine';
}

/// Parsed count expectation from `// LINT_COUNT: rule_name N`.
class FixtureCount {
  const FixtureCount({required this.ruleName, required this.expectedCount});

  /// The rule code whose total diagnostic count is being asserted.
  final String ruleName;

  /// Expected number of diagnostics from this rule across the entire fixture.
  final int expectedCount;

  @override
  String toString() => 'LINT_COUNT:$ruleName=$expectedCount';
}

/// Matches `// LINT: rule_name` — anchored to line start (after optional
/// whitespace) so it cannot match inside string literals.
final _lintPattern = RegExp(r'^\s*//\s*LINT:\s*(\S+)');

/// Matches `// LINT_MESSAGE: <substring>` (captures everything after the tag).
final _messagePattern = RegExp(r'^\s*//\s*LINT_MESSAGE:\s*(.+)');

/// Matches `// LINT_NOT: rule_name` — negative assertion marker.
final _lintNotPattern = RegExp(r'^\s*//\s*LINT_NOT:\s*(\S+)');

/// Matches `// LINT_COUNT: rule_name N` — whole-fixture count assertion.
final _lintCountPattern = RegExp(r'^\s*//\s*LINT_COUNT:\s*(\S+)\s+(\d+)');

/// Normalizes line endings and splits into lines for consistent parsing
/// across Windows and Unix fixture files.
List<String> _splitLines(String source) =>
    source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

/// Parses `// LINT:` and `// LINT_MESSAGE:` markers from [source].
///
/// Returns one [FixtureExpectation] per `// LINT:` marker found. When the line
/// immediately following a `// LINT:` is a `// LINT_MESSAGE:`, the message
/// substring is captured and the target line shifts down by one.
List<FixtureExpectation> parseFixtureMarkers(String source) {
  final results = <FixtureExpectation>[];
  final lines = _splitLines(source);

  for (var i = 0; i < lines.length; i++) {
    final lintMatch = _lintPattern.firstMatch(lines[i]);
    if (lintMatch == null) continue;

    final ruleName = lintMatch.group(1)!;
    String? messageSubstring;
    // The target line is the first line after all contiguous markers.
    var targetIndex = i + 1;

    // Check whether the next line is a LINT_MESSAGE marker.
    if (targetIndex < lines.length) {
      final msgMatch = _messagePattern.firstMatch(lines[targetIndex]);
      if (msgMatch != null) {
        messageSubstring = msgMatch.group(1)!.trim();
        targetIndex++;
      }
    }

    results.add(
      FixtureExpectation(
        ruleName: ruleName,
        // Convert 0-based index to 1-based line number.
        targetLine: targetIndex + 1,
        messageSubstring: messageSubstring,
      ),
    );
  }

  return results;
}

/// Parses `// LINT_NOT: rule_name` markers from [source].
///
/// Returns one [FixtureNegation] per marker. The target line is the line
/// immediately following the marker (1-based).
List<FixtureNegation> parseFixtureNegations(String source) {
  final results = <FixtureNegation>[];
  final lines = _splitLines(source);

  for (var i = 0; i < lines.length; i++) {
    final match = _lintNotPattern.firstMatch(lines[i]);
    if (match == null) continue;

    results.add(
      FixtureNegation(
        ruleName: match.group(1)!,
        // Target is the next line (1-based).
        targetLine: i + 2,
      ),
    );
  }

  return results;
}

/// Parses `// LINT_COUNT: rule_name N` markers from [source].
///
/// Returns one [FixtureCount] per marker. Unlike LINT/LINT_NOT, these are
/// not position-based — they assert a total count across the entire fixture.
List<FixtureCount> parseFixtureCounts(String source) {
  final results = <FixtureCount>[];
  final lines = _splitLines(source);

  for (var i = 0; i < lines.length; i++) {
    final match = _lintCountPattern.firstMatch(lines[i]);
    if (match == null) continue;

    final count = int.tryParse(match.group(2)!);
    if (count == null) continue;

    results.add(FixtureCount(ruleName: match.group(1)!, expectedCount: count));
  }

  return results;
}
