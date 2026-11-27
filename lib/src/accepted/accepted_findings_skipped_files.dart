/// `scan --check-accepted` only: scans the files that accepted-findings entries
/// name but normal discovery skips (`example/`, `bin/`, generated files,
/// `analyzer: exclude:`).
///
/// Without this an entry on such a file could never be judged: it stayed "not
/// checked" forever and went stale unnoticed, although the editor still reads
/// its list. Normal scan coverage is not changed.
library;

import 'dart:io' show Directory, File, FileSystemEntity, FileSystemException;

import 'package:path/path.dart' as p;

import '../scan/scan_config.dart';
import '../scan/scan_diagnostic.dart';
import '../scan/scan_runner.dart';
import 'accepted_findings_roots.dart';

/// What the extra scan saw.
class SkippedFilesScan {
  /// Findings in the extra files, still unfiltered.
  final List<ScanDiagnostic> diagnostics = [];

  /// Files whose rule walk really finished. A file that could not be resolved
  /// or was not reached is absent, so its entries stay "not checked".
  final List<String> files = [];

  /// Rules that ran on each of [files], keyed by
  /// `rootKey(canonicalRoot(file))`: a nested package can have its own config.
  final Map<String, Set<String>> rulesByFile = {};
}

/// The files named by entries of lists under [target] that are not in
/// [alreadyScanned] (absolute paths), grouped by their list's package root.
///
/// Only existing `.dart` files that really sit (links resolved) inside both
/// that package and [target] are returned, so a list can never make the check
/// read a file elsewhere, and a scoped run (`scan lib/`) stays scoped. Files
/// matching [excludeGlobs] (the user's own `--exclude-globs`) are left out.
Map<String, List<String>> acceptedSkippedFiles({
  required String target,
  required AcceptedListSet lists,
  required Iterable<String> alreadyScanned,
  List<String> excludeGlobs = const [],
}) {
  // A single-file or missing target has no discovery to fill in.
  if (!Directory(target).existsSync()) return const {};
  final realTarget = _realPath(target);
  if (realTarget == null) return const {};
  final seen = {for (final f in alreadyScanned) rootKey(canonicalRoot(f))};
  final out = <String, List<String>>{};
  for (final root in discoverAcceptedLists(target).roots) {
    final realRoot = _realPath(root);
    if (realRoot == null) continue;
    for (final entry in lists.listAt(root).entries) {
      final file = p.normalize(p.join(root, entry.file));
      if (!file.endsWith('.dart') || !FileSystemEntity.isFileSync(file)) {
        continue;
      }
      // An outer list naming a nested package's file is reported as a problem
      // by the check; scanning it would judge nothing.
      final owner = acceptedRootFor(file);
      if (owner == null || rootKey(owner) != rootKey(root)) continue;
      final real = _realPath(file);
      if (real == null ||
          !p.isWithin(realRoot, real) ||
          !p.isWithin(realTarget, real)) {
        continue;
      }
      if (ScanRunner.matchesAnyGlob(file, excludeGlobs, target)) continue;
      // `add` also drops a file named by several entries.
      if (seen.add(rootKey(canonicalRoot(file)))) {
        (out[root] ??= []).add(file);
      }
    }
  }
  return out;
}

/// [path] with links resolved, or null when it cannot be resolved (broken
/// link, permissions), in which case the caller must not read it.
String? _realPath(String path) {
  try {
    return File(path).resolveSymbolicLinksSync();
  } on FileSystemException {
    return null;
  }
}

/// Runs the resolved scan on [filesByRoot] (from [acceptedSkippedFiles]).
///
/// A package with its own saropa_lints config is scanned with it, so checking
/// from an outer folder judges its entries as checking that package directly
/// would; otherwise the target's config applies. [runnerFor] builds the runner
/// for a config folder and file list, carrying the CLI's flags.
Future<SkippedFilesScan> scanAcceptedSkippedFiles({
  required String target,
  required Map<String, List<String>> filesByRoot,
  required ScanRunner Function(String configRoot, List<String> files) runnerFor,
}) async {
  final byConfig = <String, List<String>>{};
  for (final MapEntry(key: root, value: files) in filesByRoot.entries) {
    final configRoot = loadScanConfig(root) != null ? root : target;
    (byConfig[configRoot] ??= []).addAll(files);
  }
  final out = SkippedFilesScan();
  // Sequential: rule enablement is process-wide state.
  for (final MapEntry(key: configRoot, value: files) in byConfig.entries) {
    final runner = runnerFor(configRoot, files);
    // Null means no usable config: the files stay "not checked".
    final found = await runner.runResolved();
    if (found == null) continue;
    out.diagnostics.addAll(found);
    for (final f in runner.walkedFiles) {
      out.files.add(f);
      out.rulesByFile[rootKey(canonicalRoot(f))] = runner.ranRuleNames;
    }
  }
  return out;
}
