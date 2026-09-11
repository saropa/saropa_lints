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
function buildTemplate(root: string): string {
  const { ref, pinned } = resolveActionRef(root);
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
          mode: annotate                        # annotate | gate | both
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
export function enableCiWorkflow(root: string): void {
  const file = getCiWorkflowPath(root);
  if (!fs.existsSync(file)) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, buildTemplate(root), 'utf-8');
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
