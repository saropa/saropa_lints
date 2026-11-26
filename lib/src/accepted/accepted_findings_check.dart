/// `scan --check-accepted`: judges every `saropa_accepted.yaml` under the scan
/// target, one block per list, and renders the JSON and text reports.
///
/// Every list is checked, not only the one at the target, because each file
/// is matched against its own package's list ([acceptedRootFor]). Checking a
/// single list would leave a nested package's entries unchecked while the
/// editor applies them.
library;

import 'dart:convert' show JsonEncoder;

import 'package:path/path.dart' as p;

import 'accepted_findings_list.dart';
import 'accepted_findings_report.dart';
import 'accepted_findings_roots.dart';

/// Verdicts for one list file.
class AcceptedListCheck {
  const AcceptedListCheck({
    required this.root,
    required this.listPath,
    required this.statuses,
    required this.problems,
  });

  /// Canonical package root the list belongs to (for a stray list, its
  /// folder). Entry paths are relative to it.
  final String root;

  /// Absolute path of the list file, so the extension can put markers on it.
  final String listPath;
  final List<AcceptedEntryStatus> statuses;

  /// Parse and validation problems, plus entries naming another package's
  /// file. Each hides nothing.
  final List<AcceptedProblem> problems;

  /// Whether this list should fail CI: any stale entry or any problem.
  bool get fails => problems.isNotEmpty || statuses.any((s) => s.isStale);
}

/// Checks every list under [target]. [scannedFiles] are absolute paths the
/// run really scanned (worker-skipped files already removed); [split] and
/// [lists] are the ones the run filtered with, so hidden counts and the
/// judged lists are the same objects the normal output used.
List<AcceptedListCheck> checkAcceptedLists({
  required String target,
  required AcceptedListSet lists,
  required AcceptedSplit split,
  required Iterable<String> scannedFiles,
  required Set<String> rulesRun,
  required bool complete,
}) {
  final found = discoverAcceptedLists(target);
  final scanned = _scannedByRoot(scannedFiles);
  final checks = <AcceptedListCheck>[
    for (final root in found.roots)
      if (lists.listAt(root) case final list when list.exists)
        _checkOne(
          root,
          list,
          statusesFor: (own) => evaluateAcceptedEntries(
            list: list,
            entries: own,
            hiddenByEntry: split.hiddenByEntryAt(root),
            scannedFiles: scanned[rootKey(root)] ?? const {},
            rulesRun: rulesRun,
            projectRoot: root,
            complete: complete,
          ),
        ),
    for (final stray in found.strayLists) _strayCheck(stray),
  ];
  // Stable order so CI logs and the extension's markers do not reshuffle.
  checks.sort((a, b) => a.listPath.compareTo(b.listPath));
  return checks;
}

/// Scanned files grouped by package root key, as package-relative paths.
/// Grouped per package because an outer list's entry for
/// `example/lib/a.dart` is never consulted once `example/` is a package.
Map<String, Set<String>> _scannedByRoot(Iterable<String> files) {
  final out = <String, Set<String>>{};
  for (final f in files) {
    final root = acceptedRootFor(f);
    final rel = root == null ? null : relativeToProject(f, root);
    if (rel != null) (out[rootKey(root!)] ??= {}).add(rel);
  }
  return out;
}

/// Splits [list]'s entries into those its package owns (judged by
/// [statusesFor]) and those naming a file of a nested package (problems).
AcceptedListCheck _checkOne(
  String root,
  AcceptedFindingsList list, {
  required List<AcceptedEntryStatus> Function(List<AcceptedEntry> own)
  statusesFor,
}) {
  final own = <AcceptedEntry>[];
  final foreign = <AcceptedProblem>[];
  for (final e in list.entries) {
    final owner = acceptedRootFor('$root/${e.file}');
    // The file sits in a nested package, whose own list is the only one any
    // producer reads for it: this entry can never hide anything.
    if (owner != null && rootKey(owner) != rootKey(root)) {
      final where = relativeToProject(owner, root) ?? owner;
      foreign.add(
        AcceptedProblem(
          line: e.line,
          message:
              '${e.file} belongs to the package in $where/, which uses its '
              'own $kAcceptedFindingsFileName. Move the entry there, with a '
              'path relative to that package.',
        ),
      );
    } else {
      own.add(e);
    }
  }
  final problems = [...list.problems, ...foreign]
    ..sort((a, b) => a.line.compareTo(b.line));
  return AcceptedListCheck(
    root: root,
    listPath: list.path,
    statuses: statusesFor(own),
    problems: problems,
  );
}

/// A list beside no `pubspec.yaml`: one problem, no entries judged.
AcceptedListCheck _strayCheck(String listPath) => AcceptedListCheck(
  root: p.posix.dirname(listPath),
  listPath: listPath,
  statuses: const [],
  problems: const [
    AcceptedProblem(
      line: 1,
      message:
          'No pubspec.yaml beside this file, so no package reads it and it '
          'hides nothing. Move its entries to the list next to the '
          'pubspec.yaml of their package.',
    ),
  ],
);

/// Whether a check run should fail CI: any list with a stale entry or a
/// problem.
bool acceptedCheckFails(List<AcceptedListCheck> checks) =>
    checks.any((c) => c.fails);

/// JSON for `scan --check-accepted --format json`. Version 2: one object per
/// list under `lists` (entry paths relative to that list's `projectRoot`;
/// `listPath` absolute so the extension can place markers directly), plus
/// totals. An empty `lists` means no list exists under the target.
String acceptedCheckToJsonString(List<AcceptedListCheck> checks) =>
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'version': 2,
      'lists': [
        for (final c in checks)
          <String, Object?>{
            'listPath': c.listPath,
            'projectRoot': c.root,
            'entries': [for (final s in c.statuses) _entryJson(s)],
            'problems': [
              for (final pr in c.problems)
                <String, Object>{'line': pr.line, 'message': pr.message},
            ],
            'summary': _summary([c]),
          },
      ],
      'summary': <String, Object>{
        'listCount': checks.length,
        ..._summary(checks),
      },
    });

Map<String, Object?> _entryJson(AcceptedEntryStatus s) => <String, Object?>{
  'rule': s.entry.rule,
  'file': s.entry.file,
  'kind': s.entry.kind,
  'reason': s.entry.reason,
  'line': s.entry.line,
  'state': s.state.name,
  'hiddenCount': s.hiddenCount,
};

/// Counts across [checks]; used per list and for the totals.
Map<String, Object> _summary(List<AcceptedListCheck> checks) {
  final statuses = [for (final c in checks) ...c.statuses];
  int count(AcceptedEntryState s) => statuses.where((x) => x.state == s).length;
  return <String, Object>{
    'entryCount': statuses.length,
    'active': count(AcceptedEntryState.active),
    'stale': statuses.where((s) => s.isStale).length,
    'notChecked': count(AcceptedEntryState.notChecked),
    'problemCount': checks.fold<int>(0, (a, c) => a + c.problems.length),
    'hiddenTotal': statuses.fold<int>(0, (a, s) => a + s.hiddenCount),
  };
}

/// Human-readable report lines for `scan --check-accepted`.
List<String> acceptedCheckToText(List<AcceptedListCheck> checks) {
  if (checks.isEmpty) {
    return ['No $kAcceptedFindingsFileName in any package under the target.'];
  }
  final out = <String>[];
  for (final c in checks) {
    out
      ..add('Accepted findings: ${c.listPath}')
      ..addAll(c.statuses.map(_statusLine))
      ..addAll(
        c.problems.map(
          (pr) =>
              '  line ${pr.line.toString().padLeft(4)}  INVALID  '
              '${pr.message}',
        ),
      )
      ..add('');
  }
  final totals = _summary(checks);
  final entries = totals['entryCount']! as int;
  out.add(
    '${checks.length} list${checks.length == 1 ? '' : 's'}, '
    '$entries entr${entries == 1 ? 'y' : 'ies'}, '
    '${totals['stale']} stale, ${totals['problemCount']} invalid.',
  );
  return out;
}

String _statusLine(AcceptedEntryStatus s) {
  final label = switch (s.state) {
    AcceptedEntryState.active => 'hides ${s.hiddenCount}',
    AcceptedEntryState.staleFileMissing => 'STALE (file missing)',
    AcceptedEntryState.staleNoFinding => 'STALE (no finding)',
    AcceptedEntryState.notChecked => 'not checked',
  };
  return '  line ${s.entry.line.toString().padLeft(4)}  '
      '${s.entry.rule}  ${s.entry.file}  — $label';
}
