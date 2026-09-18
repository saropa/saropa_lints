/// Writes a GitHub Actions workflow that calls the `saropa/saropa_lints`
/// composite action (see `action.yml` at the repo root).
library;

// Filesystem output for `--emit-ci`. Mirrors composite_plugin_scaffold.dart's
// approach: a plain string template written verbatim, no templating engine.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart' show saropaLintsVersion;

/// Outcome of an [emitCiWorkflow] call, so the caller (init_runner.dart) can
/// report the right message without re-deriving what happened from the
/// filesystem.
enum EmitCiResult {
  /// File did not exist and `--dry-run` was not set: written to disk.
  written,

  /// File did not exist but `--dry-run` was set: nothing written.
  wouldWrite,

  /// File already exists: refused. `--emit-ci` never overwrites — a
  /// generated workflow a human has since hand-edited must not be silently
  /// clobbered, and the `managed-by` marker only means anything if we never
  /// touch a file we didn't just create.
  refusedExists,

  /// Writing failed (read-only directory, permissions). Nothing was written.
  writeFailed,
}

/// The enclosing git repository's root: the nearest directory, from [start]
/// upward, holding a `.git` entry (a directory, or a file in a worktree or
/// submodule). Null outside a repository.
///
/// GitHub only runs workflows from the repository root's `.github/workflows`,
/// so a Dart project in a subdirectory must have its workflow written there.
/// Mirrors `findRepoRoot` in the extension's `ciWorkflow.ts`.
Directory? findRepoRoot(Directory start) {
  Directory dir = start.absolute;
  for (;;) {
    if (FileSystemEntity.typeSync(p.join(dir.path, '.git')) !=
        FileSystemEntityType.notFound) {
      return dir;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

/// [projectDir]'s path inside its repository, POSIX-style, or null when it
/// is the repository root (or not in one). Becomes the action's
/// `working-directory` input. Mirrors `projectPathInRepo` in `ciWorkflow.ts`.
String? projectPathInRepo(Directory projectDir) {
  final Directory? repo = findRepoRoot(projectDir);
  if (repo == null) return null;
  final String rel = p.relative(
    p.normalize(projectDir.absolute.path),
    from: p.normalize(repo.path),
  );
  if (rel == '.') return null;
  return p.posix.joinAll(p.split(rel));
}

/// True when [projectDir] has no saropa_lints rule configuration, so the
/// generated `scan` would exit 2 unless the workflow names a tier.
///
/// Deliberately a substring check rather than a YAML parse: configuration
/// reaches analysis_options.yaml several ways — a tier `include:`, an
/// init-generated per-rule block, a `plugins:` section — and every one of them
/// mentions saropa_lints. Absence is the signal worth acting on.
///
/// Mirrors `needsExplicitTier` in the extension's `ciWorkflow.ts`, because the
/// card and this command must generate the identical file.
bool ciNeedsExplicitTier(Directory projectDir) {
  try {
    final File options = File(p.join(projectDir.path, 'analysis_options.yaml'));
    if (!options.existsSync()) {
      return true;
    }
    return !options.readAsStringSync().contains('saropa_lints');
  } on Object {
    // An unreadable file is indistinguishable from an absent one here, and
    // guessing "configured" would generate a workflow that exits 2.
    return true;
  }
}

/// Builds the workflow body written by [emitCiWorkflow].
///
/// Kept in sync with the "GitHub Actions CI with SARIF" example in
/// doc/guides/cli.md — that doc is the hand-authored reference, this is the
/// generated copy of it.
///
/// The action reference is pinned to the exact saropa_lints version doing the
/// generating, resolved at runtime from the consumer's package_config.json.
/// That is self-consistent by construction: a release old enough to lack
/// `action.yml` at its tag is also too old to have `--emit-ci`, so any version
/// that can reach this code has an action to point at.
///
/// A hardcoded pin cannot make that guarantee, and did not: this was written
/// as `v16.2.1`, a tag that predates `action.yml` entirely, so every workflow
/// it generated referenced an action that could not resolve.
///
/// Deliberately the exact version rather than the moving major (`@v16`) that
/// the release script also maintains: a generated file should pin to the
/// release it was generated against, so regenerating is the only thing that
/// can change which action runs.
String buildCiWorkflow({
  String? version,
  String? tier,
  String? workingDirectory,
}) {
  final String resolved = version ?? saropaLintsVersion;

  // Emitted only when the project has no rule configuration of its own.
  // Naming a tier for a project that IS configured would override the rule
  // set the team already chose; omitting it for one that is not produces a
  // `scan` that exits 2 on the workflow's very first run.
  final String tierLine = tier == null ? '' : '\n          tier: $tier';
  // A project below the repository root: the workflow lives at the root, so
  // the action has to be told where the pubspec is.
  final String workingDirectoryLine = workingDirectory == null
      ? ''
      : '\n          working-directory: $workingDirectory';

  // 'unknown' means package_config.json could not be read. Emitting
  // `@vunknown` would be a broken reference dressed up as a real one, so
  // fall back to the default branch and say so in the generated file rather
  // than leaving a silent trap for whoever pushes it.
  final bool known = resolved != 'unknown';
  final String ref = known ? 'v$resolved' : 'main';
  final String note = known
      ? ''
      : '#\n'
            '# NOTE: no saropa_lints release that ships this action could be resolved\n'
            '# for this project, so this references the default branch. Pin it to a\n'
            '# release (16.3.0 or later) before relying on this in CI.\n';

  // Must stay byte-identical to buildTemplate in
  // extension/src/systemHealth/ciWorkflow.ts: both are checked against the
  // same fixtures under test/fixtures/ci_workflow/.
  return '''
# Generated by saropa_lints (dart run saropa_lints:init --emit-ci)
# managed-by: saropa_lints
$note
name: saropa_lints

on:
  pull_request:
    paths: ['**.dart']

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: saropa/saropa_lints@$ref
        # Reports; does not block. Remove this line to make a finding fail the
        # pull request once the project is clean enough to enforce.
        continue-on-error: true
        with:
          # gate runs the `scan` command, which honors THIS project's
          # analysis_options.yaml — the tier and per-rule choices already made
          # here. The alternative, annotate, runs every rule regardless of
          # configured tier, which on a 2332-rule set means findings from rules
          # the project never enabled.
          mode: gate$tierLine$workingDirectoryLine
''';
}

/// Writes [buildCiWorkflow]'s output to [outputFile].
///
/// Never overwrites an existing file (see [EmitCiResult.refusedExists]);
/// under `--dry-run` reports what it would do without touching disk.
///
/// [projectDir] is the project the workflow is being written for. It decides
/// whether a `tier:` input is needed — see [ciNeedsExplicitTier] — and, when
/// it sits below its repository's root, the `working-directory:` input. When
/// omitted, the file is generated with neither.
///
/// [tier] is an explicit choice (`init --tier`), written whatever the
/// project's configuration says.
EmitCiResult emitCiWorkflow(
  File outputFile, {
  required bool dryRun,
  Directory? projectDir,
  String? tier,
}) {
  // Any existing entry, not just a file: a directory at the path is not
  // something to write over either.
  if (FileSystemEntity.typeSync(outputFile.path) !=
      FileSystemEntityType.notFound) {
    return EmitCiResult.refusedExists;
  }

  if (dryRun) {
    return EmitCiResult.wouldWrite;
  }

  final String content = buildCiWorkflow(
    tier:
        tier ??
        (projectDir != null && ciNeedsExplicitTier(projectDir)
            ? 'recommended'
            : null),
    workingDirectory: projectDir == null ? null : projectPathInRepo(projectDir),
  );
  try {
    final Directory parent = outputFile.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    outputFile.writeAsStringSync(content);
  } on FileSystemException {
    return EmitCiResult.writeFailed;
  }

  return EmitCiResult.written;
}
