/// In-editor hook for the accepted-findings list.
///
/// The analyzer plugin reports straight to the Problems panel, so the list
/// must be applied inside the reporter (see `SaropaDiagnosticReporter` in
/// `saropa_lint_rule.dart`). CLI producers do NOT use this: they filter
/// their output afterwards (`accepted_findings_report.dart`) so the stale
/// check can still see every finding an entry hid.
library;

import 'dart:io' show FileStat, FileSystemEntityType;

import '../native/plugin_logger.dart' show PluginLogger;
import 'accepted_findings_list.dart';
import 'accepted_findings_roots.dart' show acceptedRootFor;

/// Holds the loaded lists for the running analyzer plugin.
///
/// One analysis server analyzes several projects (a multi-root workspace, a
/// monorepo, a package with a nested `example/`), so there is no single list:
/// each analyzed file is matched against the list of its own project root,
/// the nearest directory holding a `pubspec.yaml`.
class AcceptedFindingsRuntime {
  AcceptedFindingsRuntime._();

  static bool _enabled = false;

  /// One cached list per project root. Bounded by the number of projects
  /// the server analyzes, so it is never evicted.
  static final Map<String, _RootList> _byRoot = {};

  /// How often a list file is re-stat'ed. The check runs only when a
  /// diagnostic is about to be reported, so this bounds file-system calls to
  /// one per root per interval instead of one per finding.
  static const Duration recheckInterval = Duration(seconds: 2);

  /// Turns the hook on. Called from the config loader for the in-server
  /// plugin only; safe to call repeatedly. No root is taken on purpose: the
  /// config loader runs once for the first project seen, which says nothing
  /// about the projects of later files.
  static void enable() => _enabled = true;

  /// Whether the hook is on. False in CLI producers, which lets the reporter
  /// skip location work entirely there.
  static bool get isEnabled => _enabled;

  /// Clears all state (tests).
  static void reset() {
    _enabled = false;
    _byRoot.clear();
  }

  /// The entry hiding [rule] at absolute [filePath], or null. The list is
  /// the one at the file's own project root, re-read first when it changed on
  /// disk (at most once per [recheckInterval]).
  static AcceptedEntry? match(String filePath, String rule) {
    if (!_enabled) return null;
    // The same root rule every CLI producer uses (accepted_findings_roots),
    // so an entry hides a finding in the editor exactly where it hides it in
    // scan, audit and the daemon. Memoized per directory, so this is a map
    // hit on the reporting path rather than a directory walk.
    final root = acceptedRootFor(filePath);
    // No pubspec.yaml above the file: there is no project to hold a list.
    if (root == null) return null;
    final list = _listFor(root);
    // Skip path normalization when the project has accepted nothing.
    if (list.isEmpty) return null;
    final rel = relativeToProject(filePath, root);
    return rel == null ? null : list.entryFor(rel, rule);
  }

  /// The current list for [root], loading or reloading it as needed.
  static AcceptedFindingsList _listFor(String root) {
    final cached = _byRoot[root];
    if (cached == null) return (_byRoot[root] = _load(root)).list;
    if (cached.sinceCheck.elapsed < recheckInterval) return cached.list;
    cached.sinceCheck.reset();
    // A changed mtime covers edit, creation and deletion (null mtime).
    if (_modifiedOf(cached.list.path) == cached.modified) return cached.list;
    return (_byRoot[root] = _load(root)).list;
  }

  /// Reads the list at [root] and reports its problems once per load.
  static _RootList _load(String root) {
    final list = AcceptedFindingsList.load(root);
    // The plugin has no UI of its own; problems go to the plugin log and are
    // surfaced in the editor by the extension's check command.
    if (list.problems.isNotEmpty) {
      PluginLogger.log(
        '${list.path} has ${list.problems.length} problem(s); '
        'invalid entries hide nothing. Run '
        '`dart run saropa_lints scan --check-accepted` for details.',
      );
    }
    return _RootList(list, _modifiedOf(list.path));
  }

  /// mtime of [path], or null when it is not a file.
  static DateTime? _modifiedOf(String path) {
    final stat = FileStat.statSync(path);
    return stat.type == FileSystemEntityType.file ? stat.modified : null;
  }
}

/// The cached list of one project root.
class _RootList {
  _RootList(this.list, this.modified);

  final AcceptedFindingsList list;

  /// mtime of the list file at load, or null when it did not exist. Compared
  /// on recheck so an edit is picked up without restarting the server.
  final DateTime? modified;

  /// Time since the file was last stat'ed.
  final Stopwatch sinceCheck = Stopwatch()..start();
}
