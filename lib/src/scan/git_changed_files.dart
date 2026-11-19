/// Git-based changed-file detection for audit `--since` mode.
///
/// Calls `git diff --name-only` to find Dart files changed between a
/// ref and HEAD, so the audit can restrict its scope to recently-changed
/// code without rewriting the scan engine.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Returns the list of `.dart` files changed between [ref] and HEAD
/// in the repository at [repoPath].
///
/// Uses `--diff-filter=ACMR` (Added, Copied, Modified, Renamed) with
/// `-M` for rename detection, so renamed files report their new path.
/// Returns an empty list when the ref is invalid or git is not available.
/// Throws [ProcessException] on unexpected git failures.
List<String> gitChangedDartFiles(String repoPath, String ref) {
  // `--relative`: git prints paths relative to the repository root even when
  // run from a subdirectory, and they are joined onto [repoPath] below. For a
  // project that is not at the root (a monorepo package) that doubled the
  // subdirectory and matched no files, so `--since` audited nothing. It also
  // limits the diff to files under [repoPath], which is the project scanned.
  final result = Process.runSync('git', [
    'diff',
    '--name-only',
    '--relative',
    '--diff-filter=ACMR',
    '-M',
    '$ref..HEAD',
    '--',
    '*.dart',
  ], workingDirectory: repoPath);

  if (result.exitCode != 0) {
    final stderr = (result.stderr as String).trim();
    // Invalid ref or not a git repo — return empty rather than crashing.
    // Git words an unknown ref as "unknown revision" or, when a pathspec
    // follows it (as here), "bad revision".
    if (stderr.contains('unknown revision') ||
        stderr.contains('bad revision') ||
        stderr.contains('not a git repository')) {
      return [];
    }
    throw ProcessException(
      'git',
      ['diff', '--name-only', ref],
      stderr,
      result.exitCode,
    );
  }

  final stdout = (result.stdout as String).trim();
  if (stdout.isEmpty) return [];

  // Resolve repo-relative paths to absolute so the scan engine matches
  // them against its own file discovery.
  return stdout
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .map((line) => p.normalize(p.join(repoPath, line.trim())))
      .toList();
}
