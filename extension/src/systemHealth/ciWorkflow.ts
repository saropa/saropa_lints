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

/** Relative path (from the project root) of the generated workflow file. */
export const CI_WORKFLOW_RELATIVE_PATH = '.github/workflows/saropa-lints.yml';

/**
 * Pinned action version used when generating the workflow from scratch.
 * Always an exact tag — never a moving major like `@v16` — so a freshly
 * generated workflow doesn't silently pick up a future breaking release.
 */
const ACTION_VERSION = 'v16.2.1';

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
const TEMPLATE = `# .github/workflows/saropa-lints.yml
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
      - uses: saropa/saropa_lints@${ACTION_VERSION}
        with:
          since: origin/\${{ github.base_ref }}   # changed files only
          mode: annotate                        # annotate | gate | both
`;

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
    fs.writeFileSync(file, TEMPLATE, 'utf-8');
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
