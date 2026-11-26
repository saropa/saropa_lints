/// Applies the accepted-findings list to scan output and judges which
/// entries are stale.
///
/// Used by every CLI producer (`scan`, `scan_daemon` for scan-on-save, the
/// LSP server, `audit`). These run rules in-process with no accepted-list
/// hook in the reporter, so the full finding set is available here and the
/// stale check can see what each entry hid.
library;

import 'dart:io' show FileSystemEntity;

import '../scan/scan_diagnostic.dart';
import '../scan/scan_json.dart'
    show kScanJsonDiagnostics, scanDiagnosticsToJson;
import 'accepted_findings_list.dart';

/// Result of splitting findings into shown and hidden.
class AcceptedFilterResult {
  const AcceptedFilterResult(this.kept, this.hidden);

  /// Findings no entry covers.
  final List<ScanDiagnostic> kept;

  /// Findings an entry covers, paired with that entry.
  final List<({ScanDiagnostic diagnostic, AcceptedEntry entry})> hidden;

  /// Hidden finding count per entry key ([AcceptedEntry.key]).
  Map<String, int> get hiddenByEntry {
    final counts = <String, int>{};
    for (final h in hidden) {
      counts[h.entry.key] = (counts[h.entry.key] ?? 0) + 1;
    }
    return counts;
  }
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
  final kept = <ScanDiagnostic>[];
  final hidden = <({ScanDiagnostic diagnostic, AcceptedEntry entry})>[];
  for (final d in diagnostics) {
    final rel = relativeToProject(d.filePath, projectRoot);
    final entry = rel == null ? null : list.entryFor(rel, d.ruleName);
    if (entry == null) {
      kept.add(d);
    } else {
      hidden.add((diagnostic: d, entry: entry));
    }
  }
  return AcceptedFilterResult(kept, hidden);
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
  const AcceptedEntryStatus(this.entry, this.state, this.hiddenCount);

  final AcceptedEntry entry;
  final AcceptedEntryState state;
  final int hiddenCount;

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
          rulesRun,
          complete,
          exists('$projectRoot/${e.file}'),
        ),
        hiddenByEntry[e.key] ?? 0,
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
