import * as fs from 'fs';
import * as path from 'path';

/**
 * Read/write helpers for the generated GitHub Actions CI workflow, backing
 * the "CI" card in the Diagnostic Engines section of the System Health
 * panel (WP3).
 *
 * IMPORTANT — this state lives entirely in the workspace's working tree,
 * NOT in a VS Code setting: `.github/workflows/saropa-lints.yml`. Both
 * directions here only edit that file; the caller (extension.ts) never
 * runs git on the user's behalf — they review and commit the change
 * themselves, the same as any other edit to a file that governs the whole
 * team's PRs.
 *
 * KNOWN LIMITATION: everything here reads/writes the copy of the workflow
 * on the CURRENT branch's working tree. What actually gates pull requests
 * is the copy on the repository's default branch, and the two routinely
 * diverge (an unmerged edit, a branch behind main, etc). The card's
 * description text (see engineCardsHtml.ts / debug.engine.description.ci)
 * says this explicitly — nothing here should be read as "CI is green".
 */

/** Path of the generated workflow, relative to the workspace root. */
export const CI_WORKFLOW_RELATIVE_PATH = '.github/workflows/saropa-lints.yml';

/**
 * Fallback action ref used when the installed saropa_lints version cannot be
 * read from pubspec.lock.
 *
 * Deliberately the default branch, not a version literal. A hardcoded tag was
 * the original bug here: it read `v16.2.1`, a tag created before `action.yml`
 * existed, so every workflow this wrote referenced an action that could not
 * resolve. `@vunknown` would be the same mistake wearing a different hat —
 * a broken ref that looks real. `main` at least resolves, and the generated
 * file says plainly that it needs pinning.
 */
const FALLBACK_ACTION_REF = 'main';

/**
 * First saropa_lints release whose git tag contains `action.yml`.
 *
 * This floor exists because the extension and the package version
 * independently — the extension can be several releases ahead of the
 * saropa_lints a project actually depends on. Pinning blindly to the locked
 * version would therefore generate `@v16.2.1` for a project on 16.2.1, and
 * that tag predates `action.yml` entirely: a reference that cannot resolve.
 *
 * `--emit-ci` has no such problem, since it ships inside the package and the
 * running version always carries the action. The card does, so it checks.
 *
 * Erring high is safe: a version above the floor that lacks the action is
 * impossible, and a version below it falls back to the default branch, which
 * always has one.
 */
const MIN_ACTION_VERSION = '16.3.0';

/**
 * Compares dotted numeric versions. Returns true when `version` is at least
 * `floor`. Pre-release suffixes are ignored: `16.3.0-dev` counts as 16.3.0,
 * which is the conservative reading for a floor check.
 */
function meetsMinimum(version: string, floor: string): boolean {
  const parse = (v: string): number[] =>
    v.split('-')[0].split('.').map((n) => Number.parseInt(n, 10) || 0);
  const a = parse(version);
  const b = parse(floor);
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const x = a[i] ?? 0;
    const y = b[i] ?? 0;
    if (x !== y) return x > y;
  }
  return true;
}

/**
 * Resolves the action ref to pin, from the workspace's pubspec.lock.
 *
 * Pinning to the version the project actually depends on is self-consistent:
 * a release old enough to lack `action.yml` at its tag is also too old to
 * ship this card, so any version that can reach this code has an action to
 * point at.
 */
function resolveActionRef(root: string): { ref: string; pinned: boolean } {
  try {
    const lock = path.join(root, 'pubspec.lock');
    if (!fs.existsSync(lock)) return { ref: FALLBACK_ACTION_REF, pinned: false };
    const version = readLockedVersion(fs.readFileSync(lock, 'utf-8'));
    if (!version) return { ref: FALLBACK_ACTION_REF, pinned: false };
    // Below the floor the tag has no action.yml, so a pin would be a
    // reference that looks right and fails at run time.
    if (!meetsMinimum(version, MIN_ACTION_VERSION)) {
      return { ref: FALLBACK_ACTION_REF, pinned: false };
    }
    return { ref: `v${version}`, pinned: true };
  } catch {
    // A malformed or unreadable lockfile is not worth failing the toggle over;
    // fall back and let the generated file explain itself.
    return { ref: FALLBACK_ACTION_REF, pinned: false };
  }
}

/**
 * Reads the locked saropa_lints version out of pubspec.lock.
 *
 * Deliberately parsed here rather than imported from upgrade-checker.ts: that
 * module pulls in `vscode`, and this one is otherwise pure fs/path. Keeping it
 * dependency-free is what makes the enable/disable round trip testable outside
 * an extension host, which is the only way its file surgery gets verified.
 *
 * pubspec.lock is two-space-indented YAML; the package block is
 * `  saropa_lints:` followed by more deeply indented fields, one of which is
 * `version: "x.y.z"`. Stop at the next top-of-block key so a `version:` from a
 * neighbouring package can never be misread as this one's.
 */
function readLockedVersion(lockContent: string): string | null {
  const lines = lockContent.split('\n');
  const start = lines.findIndex((l) => /^ {2}saropa_lints:\s*$/.test(l));
  if (start === -1) return null;

  for (let i = start + 1; i < lines.length; i++) {
    if (/^ {0,2}\S/.test(lines[i])) break; // next package, or a top-level key
    const m = /^\s+version:\s*"?([^"\s]+)"?\s*$/.exec(lines[i]);
    if (m) return m[1];
  }
  return null;
}

/**
 * Marker comment appended to the job's `if:` line when the CI toggle is
 * switched OFF. Its exact text is how [getCiWorkflowState] recognizes "this
 * job was suspended by the Health Panel" and how [enableCiWorkflow] finds
 * precisely the line to remove — never a byte more, so any other
 * customisation the team made to the workflow (extra jobs, extra steps,
 * comments) survives untouched across an OFF/ON round trip.
 */
const DISABLE_MARKER = '# disabled via Saropa Lints System Health panel';

/**
 * Follows [DISABLE_MARKER] when OFF had to overwrite a job's existing `if:`.
 * Everything after it is that original line, verbatim, so ON can put it back
 * byte for byte. Inserting a second `if:` instead would be a duplicate key,
 * and GitHub rejects the whole workflow over one.
 */
const WAS_SEPARATOR = ' | was: ';

/**
 * Content written when [enableCiWorkflow] is called against a workspace
 * that has no workflow file yet. Same shape as the composite-action example
 * in doc/guides/cli.md's "GitHub Actions CI with SARIF" section — kept in
 * sync by hand since the two live in different files for different
 * audiences (a guide a human reads vs. a template a toggle writes).
 */
/** Choices the card resolves before writing a workflow. */
export interface CiWorkflowOptions {
  /**
   * Written as an explicit `tier:` input when set.
   *
   * Required when the project has no saropa_lints rule configuration: `scan`
   * reads per-rule config from analysis_options.yaml and exits 2 when it finds
   * none, which is a workflow that fails on its first run. Left unset when the
   * project IS configured, so the generated CI honors the rule set the team
   * chose rather than overriding it.
   */
  tier?: string;

  /** `annotate` (SARIF on the PR diff) or `gate` (fail the build). */
  mode?: string;
}

/**
 * True when the project has no saropa_lints rule configuration, so a generated
 * `scan` would exit 2 unless the workflow names a tier.
 *
 * Deliberately a substring check rather than a YAML parse: configuration
 * reaches analysis_options.yaml several ways (a tier `include:`, an
 * init-generated per-rule block, a plugins section), and every one of them
 * mentions saropa_lints. Absence is the signal worth acting on.
 */
export function needsExplicitTier(root: string): boolean {
  try {
    const options = path.join(root, 'analysis_options.yaml');
    if (!fs.existsSync(options)) return true;
    return !fs.readFileSync(options, 'utf-8').includes('saropa_lints');
  } catch {
    return true;
  }
}

function buildTemplate(root: string, opts: CiWorkflowOptions = {}): string {
  const { ref, pinned } = resolveActionRef(root);
  // Only emitted when the project has no rule config of its own — otherwise
  // naming a tier here would override the team's configured rule set.
  const tierLine = opts.tier ? `\n          tier: ${opts.tier}` : '';
  // A project below the repository root: the workflow lives at the root, so
  // the action has to be told where the pubspec is.
  const projectPath = projectPathInRepo(root);
  const workingDirectoryLine = projectPath ? `\n          working-directory: ${projectPath}` : '';
  // Honor the caller's choice rather than ignoring it: silently writing
  // `gate` for a caller that asked for `annotate` would be a workflow that
  // does the opposite of what the code requesting it said.
  const mode = opts.mode ?? 'gate';
  const note = pinned
    ? ''
    : '#\n' +
      '# NOTE: no saropa_lints release that ships this action could be resolved\n' +
      '# for this project, so this references the default branch. Pin it to a\n' +
      '# release (16.3.0 or later) before relying on this in CI.\n';

  // Must stay byte-identical to buildCiWorkflow in
  // lib/src/init/emit_ci_workflow.dart: both are checked against the same
  // fixtures under test/fixtures/ci_workflow/.
  return `# Generated by saropa_lints (dart run saropa_lints:init --emit-ci)
# managed-by: saropa_lints
${note}
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
      - uses: saropa/saropa_lints@${ref}
        # Reports; does not block. Remove this line to make a finding fail the
        # pull request once the project is clean enough to enforce.
        continue-on-error: true
        with:
          # gate runs the \`scan\` command, which honors THIS project's
          # analysis_options.yaml — the tier and per-rule choices already made
          # here. The alternative, annotate, runs every rule regardless of
          # configured tier, which on a 2332-rule set means findings from rules
          # the project never enabled.
          mode: ${mode}${tierLine}${workingDirectoryLine}
`;
}

/** On-disk state of the generated CI workflow for a given project root. */
export type CiWorkflowState = 'active' | 'stopped' | 'absent';

/** Absolute path to the generated workflow file under `root`. */
export function getCiWorkflowPath(root: string): string {
  return path.join(findRepoRoot(root) ?? root, ...CI_WORKFLOW_RELATIVE_PATH.split('/'));
}

/**
 * The enclosing git repository's root: the nearest directory, from `start`
 * upward, holding a `.git` entry (a directory, or a file in a worktree or
 * submodule). Undefined outside a repository.
 *
 * GitHub only runs workflows from the repository root's `.github/workflows`,
 * so a Dart project in a subdirectory (`repo/app/pubspec.yaml`) must have its
 * workflow written there, not under the project.
 */
export function findRepoRoot(start: string): string | undefined {
  let dir = path.resolve(start);
  for (;;) {
    if (fs.existsSync(path.join(dir, '.git'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) return undefined;
    dir = parent;
  }
}

/**
 * The project's path inside its repository, POSIX-style, or '' when the
 * project is the repository root (or not in one). Becomes the action's
 * `working-directory` input.
 */
export function projectPathInRepo(root: string): string {
  const repo = findRepoRoot(root);
  if (!repo) return '';
  return path.relative(repo, path.resolve(root)).split(path.sep).join('/');
}

/**
 * The workflow file's path relative to the project root, POSIX-style — what
 * a git pathspec run from the project root, and a message shown to the user,
 * should say. `.github/workflows/saropa-lints.yml` for a project at the
 * repository root; `../.github/workflows/saropa-lints.yml` one level down.
 */
export function ciWorkflowPathFromProject(root: string): string {
  return path.relative(path.resolve(root), getCiWorkflowPath(root)).split(path.sep).join('/');
}

/** The workflow's current text, or undefined when there is none. */
export function readCiWorkflow(root: string): string | undefined {
  const file = getCiWorkflowPath(root);
  return fs.existsSync(file) ? fs.readFileSync(file, 'utf-8') : undefined;
}

/**
 * Derive the CI card's status purely from the workflow file: 'absent' when
 * it doesn't exist, 'stopped' when it exists but carries the disable
 * marker on its job, 'active' otherwise. Deliberately does NOT attempt to
 * read any live GitHub Actions run result — see the module doc comment.
 */
export function getCiWorkflowState(root: string): CiWorkflowState {
  const file = getCiWorkflowPath(root);
  if (!fs.existsSync(file)) return 'absent';
  const content = fs.readFileSync(file, 'utf-8');
  return content.includes(DISABLE_MARKER) ? 'stopped' : 'active';
}

/**
 * Turn CI ON: write the template workflow when none exists yet, or strip
 * the disable marker line when one is present and currently suspended.
 * A no-op when the workflow already exists and is already enabled.
 */
export function enableCiWorkflow(
  root: string,
  opts: CiWorkflowOptions = {},
): void {
  const file = getCiWorkflowPath(root);
  if (!fs.existsSync(file)) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, buildTemplate(root, opts), 'utf-8');
    return;
  }

  const content = fs.readFileSync(file, 'utf-8');
  if (!content.includes(DISABLE_MARKER)) return; // already enabled

  const next = content
    .split('\n')
    .flatMap((line) => {
      const at = line.indexOf(DISABLE_MARKER);
      if (at === -1) return [line];
      // A line OFF inserted is dropped; a line OFF overwrote is restored.
      const was = line.indexOf(WAS_SEPARATOR, at);
      return was === -1 ? [] : [line.slice(was + WAS_SEPARATOR.length)];
    })
    .join('\n');
  fs.writeFileSync(file, next, 'utf-8');
}

/**
 * Turn CI OFF: set `if: false` (tagged with [DISABLE_MARKER]) on every job
 * under `jobs:`, rather than deleting the file — a reversible diff that
 * preserves whatever else the team customised in this workflow.
 *
 * A job with no `if:` gets one inserted. A job that already has one keeps it,
 * inside the marker comment, and ON restores it (see [WAS_SEPARATOR]).
 *
 * Jobs already suspended are left exactly as they are, so a second OFF also
 * suspends a job added since the first one, instead of reporting "stopped"
 * while that job runs. Returns false, leaving the file
 * untouched, when the file is missing or when any job's shape isn't
 * recognized: a flow-style job, an empty job, or an `if:` that spans several
 * lines. Suspending some jobs and not others would leave CI running while the
 * card reported it stopped, so it is all or nothing.
 */
export function disableCiWorkflow(root: string): boolean {
  const file = getCiWorkflowPath(root);
  if (!fs.existsSync(file)) return false;

  const content = fs.readFileSync(file, 'utf-8');
  const lines = content.split('\n');
  const jobsIndex = lines.findIndex((l) => /^jobs:\s*(#.*)?$/.test(l));
  if (jobsIndex === -1) return false;

  // The jobs map ends at the next top-level key. Without this bound, a map
  // placed after `jobs:` (say `defaults:` → `run:`) would have its 2-space
  // keys mistaken for jobs and an `if:` injected into them.
  let end = lines.length;
  for (let i = jobsIndex + 1; i < lines.length; i++) {
    if (/^[^\s#]/.test(lines[i])) {
      end = i;
      break;
    }
  }

  const out = lines.slice(0, jobsIndex + 1);
  let suspended = 0;
  let i = jobsIndex + 1;
  while (i < end) {
    const line = lines[i];
    // Blank lines and comments between jobs pass through.
    if (!/^ {2}[^\s#]/.test(line)) {
      out.push(line);
      i++;
      continue;
    }
    // A job key whose value is on the same line (flow style) has no block to
    // put `if:` in.
    if (!/^ {2}[A-Za-z0-9_.-]+:\s*(#.*)?$/.test(line)) return false;
    out.push(line);

    // The job's body: every following line indented deeper than the key.
    // A comment at 0-2 spaces doesn't end the body — only a real key does.
    let j = i + 1;
    while (j < end && !/^ {0,2}[^\s#]/.test(lines[j])) j++;
    const body = lines.slice(i + 1, j);

    const first = body.find((l) => /\S/.test(l) && !/^\s*#/.test(l));
    if (!first) return false;
    const indent = /^ */.exec(first)![0];

    const ifAt = body.findIndex((l) => l.startsWith(`${indent}if:`));
    if (ifAt !== -1 && body[ifAt].includes(DISABLE_MARKER)) {
      out.push(...body); // suspended by an earlier OFF
    } else if (ifAt === -1) {
      out.push(`${indent}if: false  ${DISABLE_MARKER}`, ...body);
    } else {
      const original = body[ifAt];
      const value = original.slice(indent.length + 'if:'.length).trim();
      const next = body.slice(ifAt + 1).find((l) => /\S/.test(l) && !/^\s*#/.test(l));
      const continues = next !== undefined && /^ */.exec(next)![0].length > indent.length;
      // A block scalar, a value on the next line, or a plain scalar wrapped
      // across lines: one replacement line cannot stand in for it.
      if (value === '' || value.startsWith('#') || /^[|>]/.test(value) || continues) {
        return false;
      }
      out.push(
        ...body.slice(0, ifAt),
        `${indent}if: false  ${DISABLE_MARKER}${WAS_SEPARATOR}${original}`,
        ...body.slice(ifAt + 1),
      );
    }
    suspended++;
    i = j;
  }
  if (suspended === 0) return false;
  out.push(...lines.slice(end));

  const next = out.join('\n');
  if (next !== content) fs.writeFileSync(file, next, 'utf-8');
  return true;
}
