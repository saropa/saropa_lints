# Bug: Violations duplicated on consecutive re-analysis of the same file

## Status: Fixed

## Summary

`ImpactTracker` accumulates duplicate violations when the analyzer re-analyzes
the same file multiple times in succession. The deduplication guard in
`ProgressTracker._clearFileData()` only fires when the re-analyzed file differs
from the current file, so consecutive re-analyses of the same file bypass the
clear entirely.

A report for the contacts project shows individual violations repeated 10-15
times — the "hundreds of errors" are mostly duplicates of a few dozen unique
violations.

## Root cause

The guard in `ProgressTracker.recordFile()` (line ~424):

```dart
final wasNew = _seenFiles.add(path);
if (!wasNew && path != _currentFile) {
  _clearFileData(path);
  _currentFile = path;
}
```

This clears stale data only when `path != _currentFile`. On the first
re-analysis of file A (after analyzing file B), `_currentFile` is B, so the
clear fires correctly. But on the second and subsequent re-analyses of file A,
`_currentFile` is already A, so the clear is skipped. Each pass adds another
copy of every violation.

### Reproduction sequence

| Step | `_currentFile` | `wasNew` | `path != _current` | `_clearFileData` | Violations for A |
|------|----------------|----------|---------------------|-------------------|------------------|
| Analyze A (first time) | (null) -> A | true | n/a | No (new file) | 4 |
| Analyze B | A -> B | true | n/a | No (new file) | 4 |
| Re-analyze A (pass 2) | B -> A | false | true | **Yes** | 4 (cleared + re-added) |
| Re-analyze A (pass 3) | A | false | **false** | No | **8** (4 duplicated) |
| Re-analyze A (pass 4) | A | false | **false** | No | **12** |
| ... | A | false | false | No | **4N** |

The analyzer can re-visit a file many times during a session (dependency
invalidation, save events, workspace refresh). Each pass without an intervening
different file adds another full copy of that file's violations.

## Observed behavior

Sample from `contacts` project report (2026-02-07):

| File:Line | Rule | Occurrences |
|-----------|------|-------------|
| `contact_tab.dart:112` | `avoid_closure_memory_leak` | ~15 |
| `contact_tab.dart:134` | `avoid_closure_memory_leak` | ~15 |
| `contact_tab.dart:337` | `avoid_redundant_async` | ~15 |
| `contact_group_add_contact.dart:80` | `avoid_context_in_async_static` | ~10 |
| `map_explorer_screen.dart:61` | `avoid_redundant_async` | ~6 |

The same file:line:rule triple repeated 6-15 times. The number of repetitions
roughly matches how many times the analyzer re-visited each file.

## Impact

- **Inflated counts**: "Total issues: 705" may be ~50-80 unique violations
- **Unusable violation list**: the ALL VIOLATIONS section is mostly noise
- **Wrong TOP RULES ranking**: rules that hit frequently-reanalyzed files rank
  artificially high
- **Wrong TOP FILES ranking**: files reanalyzed most often rank highest,
  regardless of actual issue density
- **Bloated report files**: 15x duplication wastes disk and makes reports hard
  to read

## Proposed fix

### Option A: Always clear before re-recording (recommended)

Remove the `path != _currentFile` guard. Always call `_clearFileData` for
non-new files:

```dart
final wasNew = _seenFiles.add(path);
if (!wasNew) {
  _clearFileData(path);
}
_currentFile = path;
```

**Pros**: Simple, correct, no new data structures.
**Cons**: `_clearFileData` fires on every rule invocation for re-analyzed files
(~N times per file where N = number of enabled rules). But `_clearFileData` is
cheap after the first call — once violations are removed, subsequent calls find
nothing to clear.

Wait — this is wrong. Within a single analysis pass, multiple rules run on the
same file. Each rule calls `recordFile()`. If we always clear on `!wasNew`, the
second rule would clear the first rule's violations for that file.

The actual problem is distinguishing "same file, different rule in the same
pass" from "same file, new analysis pass." Currently `_currentFile` serves this
purpose but fails for consecutive re-analysis.

### Option B: Track per-file analysis generation (recommended)

Add a generation counter that increments each time a file starts a new analysis
pass. Use it to detect when violations from a previous pass need clearing:

```dart
static int _generation = 0;
static final Map<String, int> _fileGeneration = {};

static void recordFile(String path) {
  final wasNew = _seenFiles.add(path);

  if (wasNew) {
    _fileGeneration[path] = _generation;
    _handleNewFile(path, DateTime.now());
    return;
  }

  // Same file, check if this is a new analysis pass or just another rule
  if (path != _currentFile) {
    // Different file than the last rule processed — new pass for this file
    _generation++;
    _clearFileData(path);
    _fileGeneration[path] = _generation;
  }
  // else: same file as last rule — same pass, don't clear

  _currentFile = path;
}
```

This preserves the existing behavior for the common case (multiple rules on the
same file in one pass) while still correctly detecting re-analysis.

**Problem**: This still has the same gap — if file A is re-analyzed twice in a
row, `path == _currentFile` on the second re-analysis.

### Option C: Deduplicate in ImpactTracker (recommended)

Don't change the recording path at all. Instead, deduplicate when reading:

```dart
class ImpactTracker {
  // Change from List to Set with identity based on file:line:rule
  static final Map<LintImpact, Set<ViolationRecord>> _violations = { ... };

  static void record({ ... }) {
    _violations[impact]!.add(ViolationRecord( ... ));
    // Set.add is a no-op for duplicates
  }
}

class ViolationRecord {
  // Add equality based on file + line + rule
  @override
  bool operator ==(Object other) =>
      other is ViolationRecord &&
      file == other.file &&
      line == other.line &&
      rule == other.rule;

  @override
  int get hashCode => Object.hash(file, line, rule);
}
```

**Pros**: Correct regardless of how many times a file is re-analyzed. No changes
to `ProgressTracker` flow. Deduplication is guaranteed at the data structure
level.

**Cons**: Changes `ViolationRecord` equality semantics (currently value objects
without custom equality). `Set` ordering may differ from `List` insertion order
(use `LinkedHashSet` to preserve order). The `removeViolationsForFile` method
needs to iterate the set instead of using `removeWhere` on a list.

### Option D: Deduplicate in ProgressTracker counts too

Option C fixes `ImpactTracker` but `ProgressTracker._issuesByFile` and
`_issuesByRule` counts would still be inflated. The same approach is needed
there:

In `ProgressTracker.recordViolation()`, check if this exact violation was
already counted for the current file. Use a per-file set of `(rule, line)`
tuples:

```dart
static final Map<String, Set<String>> _fileViolationKeys = {};

static void recordViolation({
  required String severity,
  required String ruleName,
  int line = 0,
}) {
  final key = '$ruleName:$line';
  final fileKeys = _fileViolationKeys[_currentFile!] ??= {};
  if (!fileKeys.add(key)) return; // Already counted

  // ... existing counting logic
}
```

## Recommendation

Implement **Option C + D** together:

1. Add `==` and `hashCode` to `ViolationRecord` based on `file + line + rule`
2. Change `ImpactTracker._violations` values from `List` to `LinkedHashSet`
3. Add `_fileViolationKeys` dedup set to `ProgressTracker.recordViolation()`
4. Clear `_fileViolationKeys[path]` in `_clearFileData()`

This is the safest approach because it doesn't change the `recordFile` flow
(which handles session detection, progress tracking, and other concerns). It
adds a dedup layer at the point where data is stored.

## Files to modify

| File | Change |
|------|--------|
| `lib/src/saropa_lint_rule.dart` | Add `==`/`hashCode` to `ViolationRecord`. Change `ImpactTracker._violations` to `LinkedHashSet`. Add `_fileViolationKeys` to `ProgressTracker`. Clear in `_clearFileData()` and `reset()`. |

## Test plan

1. Verify unique violation count matches expected (no duplicates)
2. Verify `_clearFileData` still correctly resets counts on legitimate
   re-analysis (file changed and re-saved)
3. Verify report "Total issues" matches the number of unique violation lines
4. Verify TOP RULES and TOP FILES rankings reflect actual issue density

## Related

- [report_session_management.md](report_session_management.md) — session
  boundary detection (separate but overlapping concern, fixed)
- [priority_impact_assessment.md](priority_impact_assessment.md) — report
  prioritization feature (blocked by this bug)
