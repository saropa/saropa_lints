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
 * always has one. Update this when the release containing `action.yml` ships.
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
  const note = pinned
    ? ''
    : '#\n' +
      '# NOTE: the saropa_lints version could not be read from pubspec.lock,\n' +
      '# so this references the default branch rather than a release tag.\n' +
      '# Pin it to the version you depend on before relying on this in CI.\n';

  return `# .github/workflows/saropa-lints.yml
# managed-by: saropa_lints
${note}
name: saropa_lints

on:
  pull_request:
    paths: ['**.dart']

permissions:
  security-events: write   # required for the SARIF upload
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: saropa/saropa_lints@${ref}
        with:
          since: origin/\${{ github.base_ref }}   # changed files only
          # annotate = findings appear on the diff, build stays green.
          # If this job fails with a code-scanning permission error, this is a
          # private repository without GitHub Advanced Security: change the
          # line below to 'gate', which fails the build on findings instead
          # and needs no special permissions.
          mode: ${opts.mode ?? 'annotate'}${tierLine}
`;
}

/** On-disk state of the generated CI workflow for a given project root. */
export type CiWorkflowState = 'active' | 'stopped' | 'absent';

/** Absolute path to the generated workflow file under `root`. */
export function getCiWorkflowPath(root: string): string {
  return path.join(root, ...CI_WORKFLOW_RELATIVE_PATH.split('/'));
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
    .filter((line) => !line.includes(DISABLE_MARKER))
    .join('\n');
  fs.writeFileSync(file, next, 'utf-8');
}

/**
 * Turn CI OFF: add `if: false` (tagged with [DISABLE_MARKER]) to the first
 * job under `jobs:`, rather than deleting the file — a one-line, reversible
 * diff that preserves whatever else the team customised in this workflow.
 *
 * A no-op when the file doesn't exist (nothing to suspend) or is already
 * suspended. Returns false only when the file exists but its shape isn't
 * recognized (no `jobs:` map found) — the file is left untouched rather
 * than guessing at a structural edit.
 */
export function disableCiWorkflow(root: string): boolean {
  const file = getCiWorkflowPath(root);
  if (!fs.existsSync(file)) return false;

  const content = fs.readFileSync(file, 'utf-8');
  if (content.includes(DISABLE_MARKER)) return true; // already disabled

  const lines = content.split('\n');
  const jobsIndex = lines.findIndex((l) => l.trim() === 'jobs:');
  if (jobsIndex === -1) return false;

  // First "  <jobName>:" line after `jobs:` — a 2-space-indented map key,
  // not one of its (more deeply indented) properties.
  const jobKeyIndex = lines.findIndex(
    (l, i) => i > jobsIndex && /^ {2}[A-Za-z0-9_.-]+:\s*$/.test(l),
  );
  if (jobKeyIndex === -1) return false;

  const next = [
    ...lines.slice(0, jobKeyIndex + 1),
    `    if: false  ${DISABLE_MARKER}`,
    ...lines.slice(jobKeyIndex + 1),
  ].join('\n');
  fs.writeFileSync(file, next, 'utf-8');
  return true;
}
