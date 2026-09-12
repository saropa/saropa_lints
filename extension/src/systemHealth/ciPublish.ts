import { execFileSync } from 'child_process';
import { CI_WORKFLOW_RELATIVE_PATH } from './ciWorkflow';

/**
 * Git plumbing behind the "publish this change" step of the CI engine card.
 *
 * Deliberately free of any `vscode` import, for the same reason as
 * `ciWorkflow.ts`: every branch here can then be exercised against a real
 * temporary repository in a plain Node test, with no extension host. The one
 * part that genuinely needs VS Code — the GitHub sign-in used to open the
 * pull request — lives in `ciPublishGithub.ts` instead.
 *
 * SCOPE, and why it is drawn this tightly: this module stages exactly one
 * path, `.github/workflows/saropa-lints.yml`. It never runs `git add -A`,
 * never touches the user's index beyond that path, and never commits on the
 * branch they happen to be standing on — it always cuts a new one. A toggle
 * in a panel that swept up whatever else was dirty in someone's working tree
 * would be a far worse bug than the friction it saved.
 */

/** Which direction the pending change represents. Shapes the branch, message and PR text. */
export type CiPublishDirection = 'enable' | 'disable';

/** Everything the UI needs to describe the change, and the runner needs to perform it. */
export interface CiPublishPlan {
  direction: CiPublishDirection;
  /** New branch the change is committed to. Never an existing branch. */
  branch: string;
  /** Branch the pull request targets. */
  baseBranch: string;
  /**
   * Repository paths staged and committed — nothing outside this list is ever
   * touched.
   *
   * Usually just the workflow file. It grows when turning CI on also had to
   * edit something else for the workflow to work: adding `saropa_lints` to
   * `pubspec.yaml` when the project did not depend on it. Publishing the
   * workflow without that edit produces a pull request whose very first CI
   * run fails with "saropa_lints is not a resolved dependency" — the one
   * outcome this whole step exists to avoid.
   */
  paths: string[];
  commitMessage: string;
  prTitle: string;
  prBody: string;
  /** `owner/repo`, when the origin remote is a GitHub URL we recognize. */
  slug?: { owner: string; repo: string };
  /**
   * The exact commands, in order, that `runCiPublish` will execute — rendered
   * verbatim in the panel's copyable text control.
   *
   * These are not an approximation for display. If this list and the runner
   * ever drift, the text control becomes a lie, so both are generated from
   * this one array and the runner parses its own steps back out of it.
   */
  commands: string[];
}

/** Outcome of running the plan. `remoteBranch` is set once the push succeeds. */
export interface CiPublishResult {
  ok: boolean;
  /** The command that failed, verbatim, so the message can name it. */
  failedCommand?: string;
  /** Captured stderr of the failing command, trimmed. */
  stderr?: string;
}

/** Runs a git command in `root`, returning trimmed stdout. Throws on non-zero exit. */
function git(root: string, args: string[]): string {
  return execFileSync('git', args, {
    cwd: root,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    // stdin is ignored, so a credential or passphrase prompt would have
    // nowhere to read from and `execFileSync` would block the extension host
    // forever. Refusing to prompt turns that hang into an ordinary failure
    // the caller can report.
    env: { ...process.env, GIT_TERMINAL_PROMPT: '0' },
  }).trim();
}

/** Runs a git command, returning undefined instead of throwing. For probes. */
function gitOrUndefined(root: string, args: string[]): string | undefined {
  try {
    return git(root, args);
  } catch {
    return undefined;
  }
}

/** True when `root` is inside a git work tree. Everything else here assumes it. */
export function isGitRepository(root: string): boolean {
  return gitOrUndefined(root, ['rev-parse', '--is-inside-work-tree']) === 'true';
}

/**
 * Parses `owner/repo` out of an origin URL.
 *
 * Handles the three shapes git remotes actually take — HTTPS, SSH scp-style,
 * and ssh:// — with or without a trailing `.git`. A remote that is not GitHub
 * (GitLab, a self-hosted mirror) returns undefined, which downgrades the flow
 * to commit-and-push with a manual pull request rather than failing: opening
 * the PR is the only step that needs to know the host.
 */
export function parseGitHubSlug(remoteUrl: string): { owner: string; repo: string } | undefined {
  const url = remoteUrl.trim();
  const match =
    /^https?:\/\/(?:[^@/]+@)?github\.com\/([^/]+)\/(.+?)(?:\.git)?\/?$/.exec(url) ??
    /^git@github\.com:([^/]+)\/(.+?)(?:\.git)?\/?$/.exec(url) ??
    /^ssh:\/\/git@github\.com\/([^/]+)\/(.+?)(?:\.git)?\/?$/.exec(url);
  if (!match) return undefined;
  return { owner: match[1], repo: match[2] };
}

/**
 * The branch a pull request should target.
 *
 * Prefers what the remote itself says its HEAD is, because that is the only
 * answer that is right for a repository whose default branch is neither
 * `main` nor `master`. When the symbolic ref has never been fetched (a common
 * state in a fresh clone), falls back to whichever of the two conventional
 * names exists on the remote, and finally to `main`.
 */
export function detectBaseBranch(root: string): string {
  const head = gitOrUndefined(root, ['symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD']);
  if (head) {
    const name = head.replace(/^refs\/remotes\/origin\//, '');
    if (name) return name;
  }
  for (const candidate of ['main', 'master']) {
    if (gitOrUndefined(root, ['rev-parse', '--verify', `refs/remotes/origin/${candidate}`])) {
      return candidate;
    }
  }

  // Neither conventional name exists on the remote, so this repository uses
  // something else entirely — `trunk`, `develop`, a release line. Returning
  // `main` here would target a branch that demonstrably is not there.
  //
  // The current branch's upstream is the best remaining evidence. It is only
  // reached when `main` and `master` are both absent, so a user standing on a
  // feature branch in an ordinary repository never lands here — by then
  // `main` has already matched.
  const upstream = gitOrUndefined(root, ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}']);
  if (upstream?.startsWith('origin/')) {
    return upstream.slice('origin/'.length);
  }

  return 'main';
}

/**
 * Picks a branch name that does not already exist, locally or on the remote.
 *
 * Colliding with an existing branch is not a cosmetic problem: `git checkout
 * -b` would fail outright, and a name that exists only on the remote would
 * produce a push that silently appends to somebody else's work. Suffixing is
 * the cheap way to make the operation safe to repeat — toggling twice gives
 * two branches rather than one confusing one.
 */
export function pickBranchName(root: string, direction: CiPublishDirection): string {
  const base = direction === 'enable' ? 'saropa-lints-ci' : 'saropa-lints-ci-off';
  const exists = (name: string): boolean =>
    gitOrUndefined(root, ['rev-parse', '--verify', `refs/heads/${name}`]) !== undefined ||
    gitOrUndefined(root, ['rev-parse', '--verify', `refs/remotes/origin/${name}`]) !== undefined;

  if (!exists(base)) return base;
  for (let n = 2; n < 100; n++) {
    const candidate = `${base}-${n}`;
    if (!exists(candidate)) return candidate;
  }
  // Astronomically unlikely, and still better than returning a name that
  // collides: a timestamp is unique enough and reads as deliberate.
  return `${base}-${Date.now()}`;
}

const ENABLE_BODY = [
  'Runs saropa_lints against every pull request that touches a Dart file.',
  '',
  'The workflow calls the `scan` command, which honors this project’s own',
  '`analysis_options.yaml` — the tier and per-rule choices already made here,',
  'not the full rule set.',
  '',
  'It reports without blocking: the step carries `continue-on-error`, so a',
  'finding annotates the pull request but does not fail it. Removing that one',
  'line makes it enforce, once the project is clean enough to want that.',
].join('\n');

const DISABLE_BODY = [
  'Stops saropa_lints from running on pull requests.',
  '',
  'The workflow file is kept and each job is suspended with `if: false`, so',
  'any customization made to it survives and turning it back on is a matter of',
  'removing those lines.',
].join('\n');

/**
 * Describes the change without performing any of it.
 *
 * Safe to call purely to render the panel: it only reads git state.
 */
export function buildCiPublishPlan(
  root: string,
  direction: CiPublishDirection,
  /**
   * Extra repository-relative paths the caller changed and needs published
   * alongside the workflow — `pubspec.yaml` when the dependency was just
   * added. Duplicates and the workflow path itself are ignored.
   */
  extraPaths: readonly string[] = [],
): CiPublishPlan {
  const branch = pickBranchName(root, direction);
  const baseBranch = detectBaseBranch(root);
  const remoteUrl = gitOrUndefined(root, ['remote', 'get-url', 'origin']);
  const slug = remoteUrl ? parseGitHubSlug(remoteUrl) : undefined;

  const commitMessage =
    direction === 'enable'
      ? 'ci: run saropa_lints on pull requests'
      : 'ci: stop running saropa_lints on pull requests';
  const prTitle =
    direction === 'enable'
      ? 'Run saropa_lints on pull requests'
      : 'Turn off saropa_lints on pull requests';

  const paths = [
    CI_WORKFLOW_RELATIVE_PATH,
    ...extraPaths.filter((x) => x !== CI_WORKFLOW_RELATIVE_PATH),
  ].filter((x, i, all) => all.indexOf(x) === i);

  return {
    direction,
    branch,
    baseBranch,
    paths,
    commitMessage,
    prTitle,
    prBody: direction === 'enable' ? ENABLE_BODY : DISABLE_BODY,
    slug,
    commands: [
      `git checkout -b ${branch}`,
      `git add ${paths.join(' ')}`,
      `git commit -m "${commitMessage}" -- ${paths.join(' ')}`,
      `git push -u origin ${branch}`,
    ],
  };
}

/**
 * Performs the plan: new branch, stage the one file, commit, push.
 *
 * Stops at the first failure and reports which command it was, rather than
 * continuing and leaving the repository in a state nobody can describe. The
 * caller surfaces `failedCommand` directly, so a user whose push was rejected
 * by a branch protection rule can see exactly which step to run by hand —
 * which is also why the same strings are what the panel offers to copy.
 *
 * Note the push is NOT force, and the branch is new, so there is no path here
 * that can overwrite existing history.
 */
export function runCiPublish(root: string, plan: CiPublishPlan): CiPublishResult {
  const steps: string[][] = [
    ['checkout', '-b', plan.branch],
    // Forward slashes deliberately, not path.sep: git's pathspec grammar is
    // POSIX on every platform, including Windows.
    ['add', '--', ...plan.paths],
    // The pathspec is load-bearing: a bare `git commit` commits the WHOLE
    // index, so anything the user had already `git add`ed before pressing
    // the button would be swept into this commit and pushed. With the
    // pathspec, git commits HEAD plus this one path and leaves the rest of
    // their index exactly as they left it.
    ['commit', '-m', plan.commitMessage, '--', ...plan.paths],
    ['push', '-u', 'origin', plan.branch],
  ];

  for (let i = 0; i < steps.length; i++) {
    try {
      git(root, steps[i]);
    } catch (err) {
      const stderr =
        typeof (err as { stderr?: unknown }).stderr === 'string'
          ? ((err as { stderr: string }).stderr).trim()
          : String((err as Error)?.message ?? err).trim();
      return { ok: false, failedCommand: plan.commands[i], stderr };
    }
  }
  return { ok: true };
}

/** The pull request URL a user would open by hand, when we cannot open it for them. */
export function compareUrl(plan: CiPublishPlan): string | undefined {
  if (!plan.slug) return undefined;
  const { owner, repo } = plan.slug;
  return `https://github.com/${owner}/${repo}/compare/${plan.baseBranch}...${plan.branch}?expand=1`;
}
