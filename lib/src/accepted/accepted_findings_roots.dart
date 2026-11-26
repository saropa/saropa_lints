/// Which `saropa_accepted.yaml` applies to a file, and how CLI producers
/// filter findings with one list per package.
///
/// The single rule, shared by the analyzer plugin, `scan`, the scan daemon,
/// the language server, `audit` and `scan --check-accepted`: a file is matched
/// against the list next to its nearest `pubspec.yaml`. Before this existed
/// the plugin used that rule while every CLI producer loaded one list at the
/// scan target's root, so in a nested package (`example/`) or a second
/// workspace folder an entry hid a finding in one surface and not another.
library;

import 'dart:io' show Directory, File, FileSystemEntity, Platform;

import 'package:path/path.dart' as p;

import '../project_context.dart' show ProjectContext;
import '../scan/scan_diagnostic.dart';
import 'accepted_findings_list.dart';
import 'accepted_findings_report.dart' show AcceptedFilterResult;

/// The package root whose list applies to [filePath]: the nearest directory
/// at or above the file that holds a `pubspec.yaml`, in canonical form
/// ([canonicalRoot]). Null when no package encloses the file, in which case
/// no list applies. Memoized per directory by [ProjectContext], so calling it
/// once per finding costs a map hit after the first file of a folder.
String? acceptedRootFor(String filePath) {
  final root = ProjectContext.findProjectRoot(p.absolute(filePath));
  return root == null ? null : canonicalRoot(root);
}

/// The package root a list file inside [dir] would belong to. The lookup
/// starts at the list's own path, not [dir], because [acceptedRootFor] walks
/// up from a file's parent: passing [dir] itself would skip a `pubspec.yaml`
/// sitting in [dir].
String? acceptedRootForDir(String dir) =>
    acceptedRootFor(p.join(dir, kAcceptedFindingsFileName));

/// Absolute, normalized, forward-slash form of [root] without a trailing
/// slash. Producers get roots from different sources (finding paths, a
/// directory walk, a `.` CLI argument), so every root is put in this one form
/// before it is compared or printed.
String canonicalRoot(String root) {
  final s = p.normalize(p.absolute(root)).replaceAll('\\', '/');
  return s.length > 1 && s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

/// Map key for a canonical root. Windows paths are case-insensitive and tools
/// disagree on drive-letter casing, so the key is lower-cased there; the
/// original casing is kept for display.
String rootKey(String canonical) =>
    Platform.isWindows ? canonical.toLowerCase() : canonical;

/// Lists loaded once per package root for one producer run (one scan, one
/// daemon request, one LSP analysis). Producers create a fresh set per run so
/// a list edit applies on the next run without a restart.
class AcceptedListSet {
  /// [known] overrides the rule registry used for validation (tests).
  AcceptedListSet({this.known});

  final Set<String>? known;
  final Map<String, ({String root, AcceptedFindingsList list})> _byKey = {};

  /// The list for canonical [root], loaded on first use.
  AcceptedFindingsList listAt(String root) {
    final canonical = canonicalRoot(root);
    return _byKey
        .putIfAbsent(
          rootKey(canonical),
          () => (
            root: canonical,
            list: AcceptedFindingsList.load(canonical, known: known),
          ),
        )
        .list;
  }

  /// Every list loaded so far, existing or not, with its root.
  Iterable<({String root, AcceptedFindingsList list})> get loaded =>
      _byKey.values;

  /// Loaded lists that exist and have problems, for the producers' one-line
  /// "invalid entries hide nothing" warning.
  Iterable<AcceptedFindingsList> get withProblems =>
      _byKey.values.map((r) => r.list).where((l) => l.problems.isNotEmpty);
}

/// Findings split by the list of each finding's own package.
class AcceptedSplit {
  AcceptedSplit._(this.kept, this.byRoot);

  /// Findings no entry covers, in input order.
  final List<ScanDiagnostic> kept;

  /// Per root key ([rootKey]): what that root's list hid. Only roots whose
  /// list hid something appear.
  final Map<String, AcceptedFilterResult> byRoot;

  /// Every hidden finding with its entry, across all lists (audit output).
  List<({ScanDiagnostic diagnostic, AcceptedEntry entry})> get hidden => [
    for (final r in byRoot.values) ...r.hidden,
  ];

  /// Hidden counts per entry key for the list at canonical [root]. Keyed per
  /// root because two packages can each accept the same rule in the same
  /// relative path (`lib/main.dart`), which share an entry key.
  Map<String, int> hiddenByEntryAt(String root) =>
      byRoot[rootKey(canonicalRoot(root))]?.hiddenByEntry ?? const {};
}

/// Splits [diagnostics] by the list at each finding's package root
/// ([acceptedRootFor]). [lists] is reused when given so a caller that also
/// warns about broken lists or runs the check reads each file once.
AcceptedSplit filterAcceptedByNearestRoot(
  List<ScanDiagnostic> diagnostics, {
  AcceptedListSet? lists,
}) {
  final set = lists ?? AcceptedListSet();
  final kept = <ScanDiagnostic>[];
  final hidden =
      <String, List<({ScanDiagnostic diagnostic, AcceptedEntry entry})>>{};
  for (final d in diagnostics) {
    final root = acceptedRootFor(d.filePath);
    // A finding outside every package, or in one that accepted nothing, is
    // kept without path work.
    final list = root == null ? null : set.listAt(root);
    final rel = (list == null || list.isEmpty)
        ? null
        : relativeToProject(d.filePath, root!);
    final entry = rel == null ? null : list!.entryFor(rel, d.ruleName);
    if (entry == null) {
      kept.add(d);
    } else {
      (hidden[rootKey(root!)] ??= []).add((diagnostic: d, entry: entry));
    }
  }
  return AcceptedSplit._(kept, {
    for (final e in hidden.entries)
      e.key: AcceptedFilterResult(const [], e.value),
  });
}

/// Directory names never walked when looking for lists: dependency caches
/// (`.dart_tool`, `.pub-cache`, `ios/.symlinks`, `node_modules`, `Pods`),
/// build output (`build`, and Flutter's `ephemeral` plugin links, which sit
/// under a dot directory), and VCS/editor state. Each can hold copies of
/// other packages' `pubspec.yaml` and lists that this project does not own.
const Set<String> _skippedDirNames = {'build', 'node_modules', 'Pods'};

/// Lists and package roots under [target], for `scan --check-accepted`.
///
/// [roots] holds every package root inside [target] plus the package that
/// encloses [target] itself (a scan of `lib/` still checks its package's
/// list). [strayLists] holds list files with no `pubspec.yaml` beside them:
/// no producer ever reads those, so the check reports them instead of
/// letting them look effective.
({List<String> roots, List<String> strayLists}) discoverAcceptedLists(
  String target,
) {
  final start = FileSystemEntity.isDirectorySync(target)
      ? target
      : p.dirname(target);
  final roots = <String, String>{};
  void addRoot(String r) => roots.putIfAbsent(rootKey(r), () => r);
  final enclosing = acceptedRootForDir(start);
  if (enclosing != null) addRoot(enclosing);
  final stray = <String>[];
  _walk(Directory(start), (dir) {
    final hasPubspec = File(p.join(dir, 'pubspec.yaml')).existsSync();
    if (hasPubspec) addRoot(canonicalRoot(dir));
    final list = p.join(dir, kAcceptedFindingsFileName);
    // A list beside no pubspec.yaml is never read, even when a package
    // encloses its folder: that package's list is the one at its pubspec.
    if (!hasPubspec && File(list).existsSync()) {
      stray.add(canonicalRoot(list));
    }
  });
  return (roots: roots.values.toList(), strayLists: stray);
}

/// Depth-first walk calling [visit] for [dir] and each subdirectory, without
/// following links (a link can point back up the tree or into a dependency)
/// and without entering [_skippedDirNames] or dot directories.
void _walk(Directory dir, void Function(String dir) visit) {
  visit(dir.path);
  final List<FileSystemEntity> children;
  try {
    children = dir.listSync(followLinks: false);
  } on Object {
    // Unreadable directory (permissions): nothing below it can be checked.
    return;
  }
  for (final child in children) {
    if (child is! Directory) continue;
    final name = p.basename(child.path);
    if (name.startsWith('.') || _skippedDirNames.contains(name)) continue;
    _walk(child, visit);
  }
}
