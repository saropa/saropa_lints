/// Applies the accepted-findings list to scan output and judges which
/// entries are stale.
///
/// Used by every CLI producer (`scan`, `scan_daemon` for scan-on-save, the
/// LSP server, `audit`). These run rules in-process with no accepted-list
/// hook in the reporter, so the full finding set is available here and the
/// stale check can see what each entry hid.
library;

import 'dart:io' show File, FileSystemEntity;

import '../scan/scan_diagnostic.dart';
import '../scan/scan_json.dart'
    show kScanJsonDiagnostics, scanDiagnosticsToJson;
import '../scan/stale_ignore_detector.dart' show commentIgnoredLines;
import 'accepted_findings_list.dart';

/// Result of splitting findings into shown and hidden.
class AcceptedFilterResult {
  const AcceptedFilterResult(
    this.kept,
    this.hidden, [
    this.aboveMax = const [],
  ]);

  /// Findings that stay reported: not covered, or above an entry's `max`.
  final List<ScanDiagnostic> kept;

  /// Findings an entry covers, paired with that entry.
  final List<({ScanDiagnostic diagnostic, AcceptedEntry entry})> hidden;

  /// Findings an entry matches but does not hide because its `max` was
  /// already used up. Each is also in [kept].
  final List<({ScanDiagnostic diagnostic, AcceptedEntry entry})> aboveMax;

  /// Above-`max` finding count per entry key.
  Map<String, int> get aboveMaxByEntry => _countByEntry(aboveMax);

  /// Hidden finding count per entry key ([AcceptedEntry.key]).
  Map<String, int> get hiddenByEntry => _countByEntry(hidden);

  static Map<String, int> _countByEntry(
    List<({ScanDiagnostic diagnostic, AcceptedEntry entry})> matches,
  ) {
    final counts = <String, int>{};
    for (final m in matches) {
      counts[m.entry.key] = (counts[m.entry.key] ?? 0) + 1;
    }
    return counts;
  }
}

/// The findings among [matches] (all matched by one list) that must stay
/// reported although an entry covers them.
///
/// Within each entry that has a `max`, the first `max` distinct source
/// positions (offset, then line and column) are hidden, so the result does not
/// depend on the order rules or files were visited. Repeats of one position
/// (the same file listed twice in a run) share a verdict and count once. A
/// finding silenced by an `// ignore:` comment does not use up the count: some
/// producers filter those before this point and some do not, and all of them
/// must hide the same set. State lives only in this call, so analyzing a file
/// again starts from zero.
Set<ScanDiagnostic> findingsAboveMax(
  List<({ScanDiagnostic diagnostic, AcceptedEntry entry})> matches,
) {
  final byEntry = <String, List<ScanDiagnostic>>{};
  final maxByEntry = <String, int>{};
  for (final m in matches) {
    final max = m.entry.max;
    if (max == null) continue;
    maxByEntry[m.entry.key] = max;
    (byEntry[m.entry.key] ??= []).add(m.diagnostic);
  }
  final above = Set<ScanDiagnostic>.identity();
  for (final group in byEntry.entries) {
    above.addAll(_aboveInEntry(group.value, maxByEntry[group.key]!));
  }
  return above;
}

/// [findingsAboveMax] for one entry (one rule in one file).
Iterable<ScanDiagnostic> _aboveInEntry(
  List<ScanDiagnostic> group,
  int max,
) sync* {
  group.sort(_bySource);
  final ignored = _ignoredLines(group.first.filePath, group.first.ruleName);
  final hiddenPositions = <(int, int, int)>{};
  for (final d in group) {
    // Left reported, as the producer had it, and not counted.
    if (ignored.contains(d.line)) {
      yield d;
      continue;
    }
    final at = (d.offset, d.line, d.column);
    if (hiddenPositions.length < max) hiddenPositions.add(at);
    if (!hiddenPositions.contains(at)) yield d;
  }
}

int _bySource(ScanDiagnostic a, ScanDiagnostic b) {
  var c = a.offset.compareTo(b.offset);
  if (c == 0) c = a.line.compareTo(b.line);
  return c != 0 ? c : a.column.compareTo(b.column);
}

/// Lines of [path] where a comment ignores [rule]; empty when unreadable.
Set<int> _ignoredLines(String path, String rule) {
  try {
    return commentIgnoredLines(File(path).readAsStringSync(), rule);
  } on Object {
    return const {};
  }
}

/// Splits [diagnostics] given the entry matching each one (or null), keeping
/// input order. The single place the CLI producers decide hide or report.
AcceptedFilterResult partitionAccepted(
  List<ScanDiagnostic> diagnostics,
  List<AcceptedEntry?> entries,
) {
  final above = findingsAboveMax([
    for (var i = 0; i < diagnostics.length; i++)
      if (entries[i] case final entry?)
        (diagnostic: diagnostics[i], entry: entry),
  ]);
  final kept = <ScanDiagnostic>[];
  final hidden = <({ScanDiagnostic diagnostic, AcceptedEntry entry})>[];
  final aboveMax = <({ScanDiagnostic diagnostic, AcceptedEntry entry})>[];
  for (var i = 0; i < diagnostics.length; i++) {
    final d = diagnostics[i];
    final entry = entries[i];
    if (entry == null) {
      kept.add(d);
    } else if (above.contains(d)) {
      kept.add(d);
      aboveMax.add((diagnostic: d, entry: entry));
    } else {
      hidden.add((diagnostic: d, entry: entry));
    }
  }
  return AcceptedFilterResult(kept, hidden, aboveMax);
}

/// Splits [diagnostics] into kept and hidden. A no-op (everything kept) when
/// the list is empty, so projects without the file pay nothing.
AcceptedFilterResult filterAcceptedDiagnostics({
  required List<ScanDiagnostic> diagnostics,
  required AcceptedFindingsList list,
  required String projectRoot,
}) {
  if (list.isEmpty || diagnostics.isEmpty) {
    return AcceptedFilterResult(diagnostics, const []);
  }
  return partitionAccepted(diagnostics, [
    for (final d in diagnostics) _entryFor(d, list, projectRoot),
  ]);
}

/// The entry of [list] matching [d], or null.
AcceptedEntry? _entryFor(
  ScanDiagnostic d,
  AcceptedFindingsList list,
  String projectRoot,
) {
  final rel = relativeToProject(d.filePath, projectRoot);
  return rel == null ? null : list.entryFor(rel, d.ruleName);
}

// Check-run verdicts and their JSON/text reports (one block per list) live in
// accepted_findings_check.dart.

/// Per-entry verdict of a check run.
enum AcceptedEntryState {
  /// The entry hid at least one finding.
  active,

  /// The entry's file does not exist.
  staleFileMissing,

  /// The file was scanned and the rule ran, but the rule found nothing there.
  staleNoFinding,

  /// The file was not scanned or the rule did not run (scoped scan, disabled
  /// rule, lower tier, capped output). Never counted as stale.
  notChecked,
}

/// Verdict for one entry.
class AcceptedEntryStatus {
  const AcceptedEntryStatus(
    this.entry,
    this.state,
    this.hiddenCount, [
    this.aboveMaxCount = 0,
  ]);

  final AcceptedEntry entry;
  final AcceptedEntryState state;
  final int hiddenCount;

  /// Matching findings reported again because the entry's `max` was reached.
  final int aboveMaxCount;

  bool get isStale =>
      state == AcceptedEntryState.staleFileMissing ||
      state == AcceptedEntryState.staleNoFinding;
}

/// Judges every entry. Staleness is only claimed where the run could have
/// seen a finding: [scannedFiles] (project-relative) and [rulesRun] bound
/// what was checked, and [complete] false (output was capped, scan aborted)
/// downgrades "no finding" to [AcceptedEntryState.notChecked] because a
/// missing finding may just have been cut off. A missing file is stale
/// regardless of scope: no run can ever produce a finding in it.
List<AcceptedEntryStatus> evaluateAcceptedEntries({
  required AcceptedFindingsList list,
  required Map<String, int> hiddenByEntry,
  required Set<String> scannedFiles,
  required Set<String> rulesRun,
  required String projectRoot,
  bool complete = true,
  bool Function(String absPath)? fileExists,
  Iterable<AcceptedEntry>? entries,
  Map<String, int> aboveMaxByEntry = const {},
  // Overrides [rulesRun] for an entry whose file was scanned with another rule
  // set (a nested package's own config); null result keeps [rulesRun].
  Set<String>? Function(AcceptedEntry entry)? rulesRunFor,
}) {
  final exists = fileExists ?? FileSystemEntity.isFileSync;
  return [
    // [entries] narrows the judged set: the multi-package check passes the
    // list's entries minus those naming a file of another package, which it
    // reports as problems instead (see accepted_findings_check.dart).
    for (final e in entries ?? list.entries)
      AcceptedEntryStatus(
        e,
        _stateFor(
          e,
          hiddenByEntry[e.key] ?? 0,
          scannedFiles,
          rulesRunFor?.call(e) ?? rulesRun,
          complete,
          exists('$projectRoot/${e.file}'),
        ),
        hiddenByEntry[e.key] ?? 0,
        aboveMaxByEntry[e.key] ?? 0,
      ),
  ];
}

AcceptedEntryState _stateFor(
  AcceptedEntry e,
  int hidden,
  Set<String> scanned,
  Set<String> rulesRun,
  bool complete,
  bool fileExists,
) {
  if (hidden > 0) return AcceptedEntryState.active;
  if (!fileExists) return AcceptedEntryState.staleFileMissing;
  final checked =
      complete && scanned.contains(e.file) && rulesRun.contains(e.rule);
  return checked
      ? AcceptedEntryState.staleNoFinding
      : AcceptedEntryState.notChecked;
}

/// Diagnostic-shaped JSON for findings an entry hid, for
/// `audit --include-suppressed`. Same shape as a normal finding plus
/// `suppressedBy: accepted` and the entry's `acceptedKind` / `acceptedReason`,
/// so a consumer sees why each finding was accepted.
List<Map<String, Object?>> acceptedHiddenToJsonMaps(
  List<({ScanDiagnostic diagnostic, AcceptedEntry entry})> hidden,
) {
  final maps = scanDiagnosticsToJson([
    for (final h in hidden) h.diagnostic,
  ])[kScanJsonDiagnostics];
  if (maps is! List) return const [];
  return [
    for (var i = 0; i < hidden.length && i < maps.length; i++)
      <String, Object?>{
        ...(maps[i] as Map<String, Object?>),
        'suppressedBy': 'accepted',
        'acceptedKind': hidden[i].entry.kind,
        'acceptedReason': hidden[i].entry.reason,
      },
  ];
}
