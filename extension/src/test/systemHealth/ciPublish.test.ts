import * as assert from 'assert';
import { execFileSync } from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

import {
  buildCiPublishPlan,
  compareUrl,
  detectBaseBranch,
  isGitRepository,
  parseGitHubSlug,
  pickBranchName,
  runCiPublish,
} from '../../systemHealth/ciPublish';
import { CI_WORKFLOW_RELATIVE_PATH } from '../../systemHealth/ciWorkflow';
import { buildCiPublishSection } from '../../systemHealth/ciPublishHtml';

/**
 * These run against real git repositories in a temp directory, with a real
 * bare remote, rather than against a mocked git.
 *
 * The whole value of this module is what git actually does with the arguments
 * it is handed — whether a pathspec stages only the file it names, whether a
 * push to a new branch is a fast-forward, what `symbolic-ref` returns in a
 * repository where it was never set. A mock would assert my assumptions about
 * git back at me, which is the bug, not the test.
 */

function git(cwd: string, args: string[]): string {
  return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
}

/** A working repo with an `origin` pointing at a real bare repo, one commit deep. */
function makeRepo(defaultBranch = 'main'): { root: string; remote: string; cleanup: () => void } {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-cipublish-'));
  const remote = path.join(dir, 'remote.git');
  const root = path.join(dir, 'work');
  fs.mkdirSync(root);

  execFileSync('git', ['init', '--bare', `--initial-branch=${defaultBranch}`, remote], { stdio: 'ignore' });
  git(root, ['init', `--initial-branch=${defaultBranch}`]);
  git(root, ['config', 'user.email', 'test@example.com']);
  git(root, ['config', 'user.name', 'Test']);
  // Signing would prompt for a key that does not exist on a CI runner.
  git(root, ['config', 'commit.gpgsign', 'false']);
  fs.writeFileSync(path.join(root, 'README.md'), '# test\n');
  git(root, ['add', 'README.md']);
  git(root, ['commit', '-m', 'initial']);
  git(root, ['remote', 'add', 'origin', remote]);
  git(root, ['push', '-u', 'origin', defaultBranch]);

  return { root, remote, cleanup: () => fs.rmSync(dir, { recursive: true, force: true }) };
}

/** Writes the workflow file the plan expects to stage. */
function writeWorkflow(root: string, body = 'name: saropa_lints\n'): void {
  const full = path.join(root, ...CI_WORKFLOW_RELATIVE_PATH.split('/'));
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, body);
}

describe('ciPublish — remote URL parsing', () => {
  it('parses every shape a GitHub origin actually takes', () => {
    const expected = { owner: 'saropa', repo: 'saropa_lints' };
    for (const url of [
      'https://github.com/saropa/saropa_lints.git',
      'https://github.com/saropa/saropa_lints',
      'https://user@github.com/saropa/saropa_lints.git',
      'git@github.com:saropa/saropa_lints.git',
      'git@github.com:saropa/saropa_lints',
      'ssh://git@github.com/saropa/saropa_lints.git',
      'https://github.com/saropa/saropa_lints/',
    ]) {
      assert.deepStrictEqual(parseGitHubSlug(url), expected, url);
    }
  });

  it('returns undefined for hosts we cannot open a pull request on', () => {
    assert.strictEqual(parseGitHubSlug('https://gitlab.com/saropa/saropa_lints.git'), undefined);
    assert.strictEqual(parseGitHubSlug('git@bitbucket.org:saropa/saropa_lints.git'), undefined);
    assert.strictEqual(parseGitHubSlug(''), undefined);
  });

  it('does not mistake a lookalike host for github.com', () => {
    // The guard that matters: notgithub.com must not satisfy a github.com rule.
    assert.strictEqual(parseGitHubSlug('https://notgithub.com/a/b.git'), undefined);
    assert.strictEqual(parseGitHubSlug('https://github.com.evil.test/a/b.git'), undefined);
  });

  it('keeps a repository name containing dots intact', () => {
    // Only a trailing `.git` is a suffix; one in the middle is part of the name.
    assert.deepStrictEqual(parseGitHubSlug('https://github.com/a/my.repo.git'), {
      owner: 'a',
      repo: 'my.repo',
    });
  });
});

describe('ciPublish — repository probing', () => {
  it('detects a git work tree, and the absence of one', () => {
    const repo = makeRepo();
    try {
      assert.strictEqual(isGitRepository(repo.root), true);
      const plain = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-plain-'));
      try {
        assert.strictEqual(isGitRepository(plain), false);
      } finally {
        fs.rmSync(plain, { recursive: true, force: true });
      }
    } finally {
      repo.cleanup();
    }
  });

  it('finds a default branch that is neither main nor master', () => {
    const repo = makeRepo('trunk');
    try {
      assert.strictEqual(detectBaseBranch(repo.root), 'trunk');
    } finally {
      repo.cleanup();
    }
  });

  it('falls back to the conventional name when origin/HEAD was never fetched', () => {
    const repo = makeRepo('main');
    try {
      // A fresh clone routinely has no origin/HEAD symbolic ref.
      try {
        git(repo.root, ['symbolic-ref', '--delete', 'refs/remotes/origin/HEAD']);
      } catch {
        // Already absent, which is the state under test anyway.
      }
      assert.strictEqual(detectBaseBranch(repo.root), 'main');
    } finally {
      repo.cleanup();
    }
  });

  it('never reuses a branch name that already exists', () => {
    const repo = makeRepo();
    try {
      assert.strictEqual(pickBranchName(repo.root, 'enable'), 'saropa-lints-ci');
      git(repo.root, ['branch', 'saropa-lints-ci']);
      assert.strictEqual(pickBranchName(repo.root, 'enable'), 'saropa-lints-ci-2');
      git(repo.root, ['branch', 'saropa-lints-ci-2']);
      assert.strictEqual(pickBranchName(repo.root, 'enable'), 'saropa-lints-ci-3');
    } finally {
      repo.cleanup();
    }
  });

  it('the two directions cannot collide with each other', () => {
    const repo = makeRepo();
    try {
      assert.notStrictEqual(
        pickBranchName(repo.root, 'enable'),
        pickBranchName(repo.root, 'disable'),
      );
    } finally {
      repo.cleanup();
    }
  });
});

describe('ciPublish — the plan', () => {
  it('describes the change without performing any of it', () => {
    const repo = makeRepo();
    try {
      writeWorkflow(repo.root);
      const before = git(repo.root, ['rev-parse', 'HEAD']);
      const plan = buildCiPublishPlan(repo.root, 'enable');

      assert.strictEqual(git(repo.root, ['rev-parse', 'HEAD']), before, 'no commit was made');
      assert.strictEqual(git(repo.root, ['rev-parse', '--abbrev-ref', 'HEAD']), 'main', 'no checkout');
      assert.strictEqual(
        git(repo.root, ['status', '--porcelain', '--untracked-files=all']).includes(
          CI_WORKFLOW_RELATIVE_PATH,
        ),
        true,
        'the file is still only in the working tree',
      );
      assert.strictEqual(plan.baseBranch, 'main');
      assert.strictEqual(plan.paths[0], CI_WORKFLOW_RELATIVE_PATH);
    } finally {
      repo.cleanup();
    }
  });

  it('carries an extra path the caller needs published with the workflow', () => {
    const repo = makeRepo();
    try {
      const plan = buildCiPublishPlan(repo.root, 'enable', ['pubspec.yaml']);
      assert.deepStrictEqual(plan.paths, [CI_WORKFLOW_RELATIVE_PATH, 'pubspec.yaml']);
      // The workflow file stays first: the panel's prose names paths[0].
      assert.strictEqual(plan.paths[0], CI_WORKFLOW_RELATIVE_PATH);
    } finally {
      repo.cleanup();
    }
  });

  it('never lists the workflow path twice, however the caller passes it', () => {
    const repo = makeRepo();
    try {
      const plan = buildCiPublishPlan(repo.root, 'enable', [
        CI_WORKFLOW_RELATIVE_PATH,
        'pubspec.yaml',
        'pubspec.yaml',
      ]);
      assert.deepStrictEqual(plan.paths, [CI_WORKFLOW_RELATIVE_PATH, 'pubspec.yaml']);
    } finally {
      repo.cleanup();
    }
  });

  it('the displayed commands are the commands, in order', () => {
    const repo = makeRepo();
    try {
      const plan = buildCiPublishPlan(repo.root, 'enable');
      assert.deepStrictEqual(plan.commands, [
        `git checkout -b ${plan.branch}`,
        `git add ${CI_WORKFLOW_RELATIVE_PATH}`,
        `git commit -m "${plan.commitMessage}" -- ${CI_WORKFLOW_RELATIVE_PATH}`,
        `git push -u origin ${plan.branch}`,
      ]);
    } finally {
      repo.cleanup();
    }
  });

  it('a non-GitHub remote yields no slug and no compare URL', () => {
    const repo = makeRepo();
    try {
      git(repo.root, ['remote', 'set-url', 'origin', 'https://gitlab.com/a/b.git']);
      const plan = buildCiPublishPlan(repo.root, 'enable');
      assert.strictEqual(plan.slug, undefined);
      assert.strictEqual(compareUrl(plan), undefined);
    } finally {
      repo.cleanup();
    }
  });

  it('the compare URL points at the new branch against the base', () => {
    const repo = makeRepo();
    try {
      git(repo.root, ['remote', 'set-url', 'origin', 'git@github.com:saropa/saropa_lints.git']);
      const plan = buildCiPublishPlan(repo.root, 'enable');
      assert.strictEqual(
        compareUrl(plan),
        `https://github.com/saropa/saropa_lints/compare/main...${plan.branch}?expand=1`,
      );
    } finally {
      repo.cleanup();
    }
  });

  it('enable and disable differ in message and body', () => {
    const repo = makeRepo();
    try {
      const on = buildCiPublishPlan(repo.root, 'enable');
      const off = buildCiPublishPlan(repo.root, 'disable');
      assert.notStrictEqual(on.commitMessage, off.commitMessage);
      assert.notStrictEqual(on.prTitle, off.prTitle);
      assert.notStrictEqual(on.prBody, off.prBody);
    } finally {
      repo.cleanup();
    }
  });
});

describe('ciPublish — running it', () => {
  it('branches, commits and pushes the workflow file', () => {
    const repo = makeRepo();
    try {
      writeWorkflow(repo.root);
      const plan = buildCiPublishPlan(repo.root, 'enable');
      const result = runCiPublish(repo.root, plan);

      assert.strictEqual(result.ok, true, result.stderr ?? '');
      assert.strictEqual(git(repo.root, ['rev-parse', '--abbrev-ref', 'HEAD']), plan.branch);
      assert.strictEqual(
        git(repo.root, ['log', '-1', '--pretty=%s']),
        plan.commitMessage,
      );
      // The branch reached the remote, with the file on it.
      assert.strictEqual(
        git(repo.remote, ['ls-tree', '--name-only', '-r', plan.branch]).includes(
          CI_WORKFLOW_RELATIVE_PATH,
        ),
        true,
      );
    } finally {
      repo.cleanup();
    }
  });

  it('stages only the workflow file, never the rest of a dirty tree', () => {
    const repo = makeRepo();
    try {
      writeWorkflow(repo.root);
      // Everything below must survive untouched — this is the guarantee that
      // makes a toggle safe to press mid-task.
      fs.writeFileSync(path.join(repo.root, 'README.md'), '# edited by the user\n');
      fs.writeFileSync(path.join(repo.root, 'scratch.txt'), 'unsaved work\n');
      // Already staged, which is the case a bare `git commit` would sweep up.
      fs.writeFileSync(path.join(repo.root, 'staged.txt'), 'staged work\n');
      git(repo.root, ['add', 'staged.txt']);

      const plan = buildCiPublishPlan(repo.root, 'enable');
      assert.strictEqual(runCiPublish(repo.root, plan).ok, true);

      const committed = git(repo.root, ['show', '--name-only', '--pretty=format:', 'HEAD'])
        .split('\n')
        .filter(Boolean);
      assert.deepStrictEqual(committed, [CI_WORKFLOW_RELATIVE_PATH]);

      const status = git(repo.root, ['status', '--porcelain', '--untracked-files=all']);
      assert.ok(status.includes('README.md'), 'the user’s edit is still uncommitted');
      assert.ok(status.includes('scratch.txt'), 'the untracked file is still untracked');
      assert.ok(status.includes('staged.txt'), 'the user\u2019s staged file is still only staged');
    } finally {
      repo.cleanup();
    }
  });

  it('stops at the add step when the workflow file is not there', () => {
    const repo = makeRepo();
    try {
      // No workflow file written. `git add` on a pathspec matching nothing is
      // itself an error, so this fails one step earlier than a bare `commit`
      // with an empty index would — and says something more useful.
      const plan = buildCiPublishPlan(repo.root, 'enable');
      const result = runCiPublish(repo.root, plan);

      assert.strictEqual(result.ok, false);
      assert.strictEqual(result.failedCommand, plan.commands[1]);
      assert.ok((result.stderr ?? '').length > 0, 'the reason is carried, not swallowed');
      // Nothing reached the remote.
      assert.throws(() => git(repo.remote, ['rev-parse', '--verify', plan.branch]));
    } finally {
      repo.cleanup();
    }
  });

  it('commits every path in the plan, not only the workflow', () => {
    const repo = makeRepo();
    try {
      writeWorkflow(repo.root);
      // Stand-in for ensureSaropaLintsInPubspec having just added the
      // dependency: without this file in the commit, the pull request's first
      // CI run fails on an unresolved dependency.
      fs.writeFileSync(path.join(repo.root, 'pubspec.yaml'), 'name: demo\n');
      const plan = buildCiPublishPlan(repo.root, 'enable', ['pubspec.yaml']);
      assert.strictEqual(runCiPublish(repo.root, plan).ok, true);

      const committed = git(repo.root, ['show', '--name-only', '--pretty=format:', 'HEAD'])
        .split('\n')
        .filter(Boolean)
        .sort();
      assert.deepStrictEqual(committed, [CI_WORKFLOW_RELATIVE_PATH, 'pubspec.yaml'].sort());
    } finally {
      repo.cleanup();
    }
  });

  it('leaves work the user had already staged out of the commit', () => {
    const repo = makeRepo();
    try {
      writeWorkflow(repo.root);
      // Already in the index, not merely dirty. A bare `git commit -m` would
      // sweep this into the CI commit and push it — the pathspec is what
      // stops that, and this is the case that proves it.
      fs.writeFileSync(path.join(repo.root, 'README.md'), '# staged by the user\n');
      git(repo.root, ['add', 'README.md']);

      const plan = buildCiPublishPlan(repo.root, 'enable');
      assert.strictEqual(runCiPublish(repo.root, plan).ok, true);

      const committed = git(repo.root, ['show', '--name-only', '--pretty=format:', 'HEAD'])
        .split('\n')
        .filter(Boolean);
      assert.deepStrictEqual(committed, [CI_WORKFLOW_RELATIVE_PATH]);
      // Still staged, exactly as the user left it.
      assert.ok(git(repo.root, ['diff', '--cached', '--name-only']).includes('README.md'));
    } finally {
      repo.cleanup();
    }
  });

  it('reports the push when the remote rejects it', () => {
    const repo = makeRepo();
    try {
      writeWorkflow(repo.root);
      const plan = buildCiPublishPlan(repo.root, 'enable');
      // A remote that cannot be reached is the reachable stand-in for a
      // protection rule: both fail at exactly the push step.
      git(repo.root, ['remote', 'set-url', 'origin', path.join(repo.root, 'does-not-exist.git')]);

      const result = runCiPublish(repo.root, plan);
      assert.strictEqual(result.ok, false);
      assert.strictEqual(result.failedCommand, plan.commands[3]);
      // The commit still exists locally, which is what makes the printed
      // commands enough for the user to finish by hand.
      assert.strictEqual(git(repo.root, ['log', '-1', '--pretty=%s']), plan.commitMessage);
    } finally {
      repo.cleanup();
    }
  });

  it('running twice produces two branches rather than a collision', () => {
    const repo = makeRepo();
    try {
      writeWorkflow(repo.root);
      const first = buildCiPublishPlan(repo.root, 'enable');
      assert.strictEqual(runCiPublish(repo.root, first).ok, true);

      writeWorkflow(repo.root, 'name: saropa_lints\n# changed\n');
      const second = buildCiPublishPlan(repo.root, 'enable');
      assert.notStrictEqual(second.branch, first.branch);
      assert.strictEqual(runCiPublish(repo.root, second).ok, true);

      assert.ok(git(repo.remote, ['rev-parse', '--verify', first.branch]));
      assert.ok(git(repo.remote, ['rev-parse', '--verify', second.branch]));
    } finally {
      repo.cleanup();
    }
  });
});

describe('ciPublish — the panel section', () => {
  const plan = {
    direction: 'enable' as const,
    branch: 'saropa-lints-ci',
    baseBranch: 'main',
    paths: [CI_WORKFLOW_RELATIVE_PATH],
    commitMessage: 'ci: run saropa_lints on pull requests',
    prTitle: 'Run saropa_lints on pull requests',
    prBody: 'body',
    slug: { owner: 'saropa', repo: 'saropa_lints' },
    commands: [
      'git checkout -b saropa-lints-ci',
      `git add ${CI_WORKFLOW_RELATIVE_PATH}`,
      'git commit -m "ci: run saropa_lints on pull requests"',
      'git push -u origin saropa-lints-ci',
    ],
  };

  it('renders nothing when there is no pending change', () => {
    assert.strictEqual(buildCiPublishSection(undefined), '');
  });

  it('shows every command the runner will execute', () => {
    const html = buildCiPublishSection(plan);
    for (const command of plan.commands) {
      // Escaped, because the commit command contains quote marks.
      assert.ok(html.includes(command.replace(/"/g, '&quot;')), command);
    }
  });

  it('escapes the commands rather than emitting raw quote marks into an attribute', () => {
    const html = buildCiPublishSection(plan);
    const attr = /data-commands="([^"]*)"/.exec(html);
    assert.ok(attr, 'the copy button carries the commands');
    // A raw quote here would have terminated the attribute early, silently
    // truncating what the copy button hands over.
    assert.ok(!attr[1].includes('"'));
    assert.ok(attr[1].includes('&quot;'));
  });

  it('offers the pull request button only when there is a GitHub remote', () => {
    assert.ok(buildCiPublishSection(plan).includes('data-action="ciPublish"'));
    const noRemote = buildCiPublishSection({ ...plan, slug: undefined });
    assert.ok(!noRemote.includes('data-action="ciPublish"'));
    // The commands are still there — that path has to carry the whole flow.
    assert.ok(noRemote.includes('data-action="ciCopyCommands"'));
  });

  it('always offers a way out', () => {
    assert.ok(buildCiPublishSection(plan).includes('data-action="ciPublishDismiss"'));
    assert.ok(
      buildCiPublishSection({ ...plan, slug: undefined }).includes(
        'data-action="ciPublishDismiss"',
      ),
    );
  });

  it('distinguishes the two directions', () => {
    const on = buildCiPublishSection(plan);
    const off = buildCiPublishSection({ ...plan, direction: 'disable' });
    assert.ok(on.includes('data-direction="enable"'));
    assert.ok(off.includes('data-direction="disable"'));
    assert.notStrictEqual(on, off);
  });
});
