import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

import {
  ciWorkflowPathFromProject,
  disableCiWorkflow,
  enableCiWorkflow,
  findRepoRoot,
  getCiWorkflowPath,
  getCiWorkflowState,
  needsExplicitTier,
  projectPathInRepo,
} from '../../systemHealth/ciWorkflow';

/**
 * Real files in a temp directory: the whole job of this module is line
 * surgery on a workflow a team may have customised, so the assertions are on
 * the exact bytes written.
 */

/** Repository root, from out-test/test/systemHealth/. */
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..', '..');

function fixture(name: string): string {
  return fs.readFileSync(path.join(REPO_ROOT, 'test', 'fixtures', 'ci_workflow', name), 'utf-8');
}

function makeRoot(lockedVersion?: string): { root: string; cleanup: () => void } {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-ciworkflow-'));
  if (lockedVersion) {
    fs.writeFileSync(
      path.join(root, 'pubspec.lock'),
      `packages:\n  saropa_lints:\n    dependency: "direct main"\n    version: "${lockedVersion}"\n`,
    );
  }
  return { root, cleanup: () => fs.rmSync(root, { recursive: true, force: true }) };
}

function writeWorkflow(root: string, body: string): void {
  const file = getCiWorkflowPath(root);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, body, 'utf-8');
}

function readWorkflow(root: string): string {
  return fs.readFileSync(getCiWorkflowPath(root), 'utf-8');
}

/** Number of `if:` keys at exactly `indent` spaces — more than one per job is a duplicate key. */
function ifKeysAt(content: string, indent: number): number {
  return content.split('\n').filter((l) => l.startsWith(`${' '.repeat(indent)}if:`)).length;
}

describe('ciWorkflow — generated template', () => {
  // lib/src/init/emit_ci_workflow.dart is checked against the same fixtures,
  // which is what holds the card and `--emit-ci` to the same bytes.
  it('matches the shared fixture for a pinned project', () => {
    const { root, cleanup } = makeRoot('16.3.0');
    try {
      enableCiWorkflow(root);
      assert.strictEqual(readWorkflow(root), fixture('pinned.yml'));
    } finally {
      cleanup();
    }
  });

  it('matches the shared fixture with an explicit tier', () => {
    const { root, cleanup } = makeRoot('16.3.0');
    try {
      enableCiWorkflow(root, { tier: 'recommended' });
      assert.strictEqual(readWorkflow(root), fixture('pinned_tier_recommended.yml'));
    } finally {
      cleanup();
    }
  });

  it('matches the shared fixture when no version can be pinned', () => {
    const { root, cleanup } = makeRoot();
    try {
      enableCiWorkflow(root);
      assert.strictEqual(readWorkflow(root), fixture('unpinned.yml'));
    } finally {
      cleanup();
    }
  });

  it('falls back to the default branch below the action floor', () => {
    const { root, cleanup } = makeRoot('16.2.1');
    try {
      enableCiWorkflow(root);
      assert.strictEqual(readWorkflow(root), fixture('unpinned.yml'));
    } finally {
      cleanup();
    }
  });
});

describe('ciWorkflow — OFF/ON toggle', () => {
  it('round-trips the generated workflow byte for byte', () => {
    const { root, cleanup } = makeRoot('16.3.0');
    try {
      enableCiWorkflow(root);
      const original = readWorkflow(root);
      assert.strictEqual(getCiWorkflowState(root), 'active');

      assert.strictEqual(disableCiWorkflow(root), true);
      assert.strictEqual(getCiWorkflowState(root), 'stopped');
      assert.match(readWorkflow(root), /^ {4}if: false {2}# disabled via/m);
      // Idempotent in both directions.
      assert.strictEqual(disableCiWorkflow(root), true);
      assert.strictEqual(ifKeysAt(readWorkflow(root), 4), 1);

      enableCiWorkflow(root);
      assert.strictEqual(readWorkflow(root), original);
      enableCiWorkflow(root);
      assert.strictEqual(readWorkflow(root), original);
    } finally {
      cleanup();
    }
  });

  it('replaces an existing job `if:` instead of adding a duplicate, and restores it', () => {
    const { root, cleanup } = makeRoot();
    const original = [
      'name: saropa_lints',
      'on: pull_request',
      'jobs:',
      '  lint:',
      '    if: github.event.pull_request.draft == false  # skip drafts',
      '    runs-on: ubuntu-latest',
      '    steps:',
      '      - uses: actions/checkout@v5',
      '  extra:',
      '    runs-on: ubuntu-latest',
      '    steps:',
      '      - run: echo hi',
      '',
    ].join('\n');
    try {
      writeWorkflow(root, original);
      assert.strictEqual(disableCiWorkflow(root), true);
      const off = readWorkflow(root);
      // One `if:` per job: two jobs, two keys, none duplicated.
      assert.strictEqual(ifKeysAt(off, 4), 2);
      assert.ok(!off.includes('\n    if: github.event'), 'original if: must not remain as a live key');
      assert.strictEqual(getCiWorkflowState(root), 'stopped');

      enableCiWorkflow(root);
      assert.strictEqual(readWorkflow(root), original);
    } finally {
      cleanup();
    }
  });

  it('finds a job\'s own `if:` past a shallow-indented comment, and restores it', () => {
    const { root, cleanup } = makeRoot();
    const original = [
      'jobs:',
      '  lint:',
      '    runs-on: ubuntu-latest',
      '  # a 2-space comment',
      '    if: github.event.pull_request.draft == false',
      '    steps:',
      '      - run: echo hi',
      '',
    ].join('\n');
    try {
      writeWorkflow(root, original);
      assert.strictEqual(disableCiWorkflow(root), true);
      const off = readWorkflow(root);
      // One `if:` for the single job: the existing one, swapped, not a second.
      assert.strictEqual(ifKeysAt(off, 4), 1);
      assert.ok(!off.includes('\n    if: github.event'), 'original if: must not remain as a live key');

      enableCiWorkflow(root);
      assert.strictEqual(readWorkflow(root), original);
    } finally {
      cleanup();
    }
  });

  // The OFF line encodes the original as `<marker> | was: <line>`, so an `if:`
  // whose own value contains that separator is the one input that could make
  // ON slice at the wrong offset and hand back a truncated condition.
  it('restores an `if:` whose value contains the marker separator', () => {
    const { root, cleanup } = makeRoot();
    const original = [
      'jobs:',
      '  lint:',
      "    if: contains(github.event.head_commit.message, ' | was: ')",
      '    runs-on: ubuntu-latest',
      '',
    ].join('\n');
    try {
      writeWorkflow(root, original);
      assert.strictEqual(disableCiWorkflow(root), true);
      assert.strictEqual(ifKeysAt(readWorkflow(root), 4), 1);

      enableCiWorkflow(root);
      assert.strictEqual(readWorkflow(root), original);
    } finally {
      cleanup();
    }
  });

  it('leaves top-level maps after `jobs:` alone', () => {
    const { root, cleanup } = makeRoot();
    const original = [
      'on: pull_request',
      'jobs:',
      '  lint:',
      '    runs-on: ubuntu-latest',
      '    steps:',
      '      - run: dart analyze',
      'defaults:',
      '  run:',
      '    shell: bash',
      '',
    ].join('\n');
    try {
      writeWorkflow(root, original);
      assert.strictEqual(disableCiWorkflow(root), true);
      const off = readWorkflow(root);
      assert.strictEqual(ifKeysAt(off, 4), 1);
      assert.ok(off.endsWith('defaults:\n  run:\n    shell: bash\n'), off);

      enableCiWorkflow(root);
      assert.strictEqual(readWorkflow(root), original);
    } finally {
      cleanup();
    }
  });

  it('refuses a multi-line `if:` and leaves the file untouched', () => {
    const { root, cleanup } = makeRoot();
    const original = [
      'jobs:',
      '  lint:',
      '    if: >-',
      '      github.actor != \'dependabot[bot]\'',
      '    runs-on: ubuntu-latest',
      '',
    ].join('\n');
    try {
      writeWorkflow(root, original);
      assert.strictEqual(disableCiWorkflow(root), false);
      assert.strictEqual(readWorkflow(root), original);
      assert.strictEqual(getCiWorkflowState(root), 'active');
    } finally {
      cleanup();
    }
  });

  it('refuses a plain `if:` wrapped across lines', () => {
    const { root, cleanup } = makeRoot();
    const original = [
      'jobs:',
      '  lint:',
      '    if: github.event_name == \'push\' ||',
      '      github.event_name == \'pull_request\'',
      '    runs-on: ubuntu-latest',
      '',
    ].join('\n');
    try {
      writeWorkflow(root, original);
      assert.strictEqual(disableCiWorkflow(root), false);
      assert.strictEqual(readWorkflow(root), original);
    } finally {
      cleanup();
    }
  });

  it('refuses rather than half-suspending when one job is flow-style', () => {
    const { root, cleanup } = makeRoot();
    const original = [
      'jobs:',
      '  lint:',
      '    runs-on: ubuntu-latest',
      '  other: { runs-on: ubuntu-latest, steps: [{ run: echo }] }',
      '',
    ].join('\n');
    try {
      writeWorkflow(root, original);
      assert.strictEqual(disableCiWorkflow(root), false);
      assert.strictEqual(readWorkflow(root), original);
    } finally {
      cleanup();
    }
  });

  it('refuses a file with no `jobs:` map', () => {
    const { root, cleanup } = makeRoot();
    try {
      writeWorkflow(root, 'name: nothing here\n');
      assert.strictEqual(disableCiWorkflow(root), false);
      assert.strictEqual(readWorkflow(root), 'name: nothing here\n');
    } finally {
      cleanup();
    }
  });

  it('returns false when there is no workflow at all', () => {
    const { root, cleanup } = makeRoot();
    try {
      assert.strictEqual(disableCiWorkflow(root), false);
      assert.strictEqual(getCiWorkflowState(root), 'absent');
    } finally {
      cleanup();
    }
  });
});

describe('ciWorkflow — a project below its repository root', () => {
  it('writes the workflow at the repository root, naming the project directory', () => {
    const { root: repo, cleanup } = makeRoot();
    try {
      fs.mkdirSync(path.join(repo, '.git'));
      const app = path.join(repo, 'packages', 'app');
      fs.mkdirSync(app, { recursive: true });
      fs.writeFileSync(
        path.join(app, 'pubspec.lock'),
        'packages:\n  saropa_lints:\n    dependency: "direct main"\n    version: "16.3.0"\n',
      );

      assert.strictEqual(findRepoRoot(app), repo);
      assert.strictEqual(projectPathInRepo(app), 'packages/app');
      assert.strictEqual(getCiWorkflowPath(app), path.join(repo, '.github', 'workflows', 'saropa-lints.yml'));
      assert.strictEqual(ciWorkflowPathFromProject(app), '../../.github/workflows/saropa-lints.yml');

      enableCiWorkflow(app);
      // The Dart `--emit-ci` is checked against this same fixture.
      assert.strictEqual(
        fs.readFileSync(getCiWorkflowPath(app), 'utf-8'),
        fixture('pinned_subdir.yml'),
      );
      assert.ok(!fs.existsSync(path.join(app, '.github')), 'nothing written under the project');
    } finally {
      cleanup();
    }
  });

  it('a .git file (worktree, submodule) marks the root too', () => {
    const { root: repo, cleanup } = makeRoot();
    try {
      fs.writeFileSync(path.join(repo, '.git'), 'gitdir: elsewhere\n');
      const app = path.join(repo, 'app');
      fs.mkdirSync(app);
      assert.strictEqual(projectPathInRepo(app), 'app');
      assert.strictEqual(projectPathInRepo(repo), '');
    } finally {
      cleanup();
    }
  });
});

describe('ciWorkflow — more toggle shapes', () => {
  it('a second OFF suspends a job added after the first', () => {
    const { root, cleanup } = makeRoot();
    try {
      writeWorkflow(root, ['jobs:', '  lint:', '    runs-on: ubuntu-latest', ''].join('\n'));
      assert.strictEqual(disableCiWorkflow(root), true);
      // Someone adds a job while CI is off.
      fs.appendFileSync(getCiWorkflowPath(root), '  extra:\n    runs-on: ubuntu-latest\n');
      assert.strictEqual(disableCiWorkflow(root), true);
      assert.strictEqual(ifKeysAt(readWorkflow(root), 4), 2);
    } finally {
      cleanup();
    }
  });

  it('round-trips a CRLF workflow', () => {
    const { root, cleanup } = makeRoot();
    const original = ['jobs:', '  lint:', '    if: always()', '    runs-on: ubuntu-latest', ''].join('\r\n');
    try {
      writeWorkflow(root, original);
      assert.strictEqual(disableCiWorkflow(root), true);
      assert.strictEqual(getCiWorkflowState(root), 'stopped');
      enableCiWorkflow(root);
      assert.strictEqual(readWorkflow(root), original);
    } finally {
      cleanup();
    }
  });

  it('writes the mode it is asked for', () => {
    const { root, cleanup } = makeRoot('16.3.0');
    try {
      enableCiWorkflow(root, { mode: 'annotate' });
      assert.match(readWorkflow(root), /^ {10}mode: annotate$/m);
    } finally {
      cleanup();
    }
  });
});

describe('ciWorkflow — version pin and tier', () => {
  function lockWith(root: string, body: string): void {
    fs.writeFileSync(path.join(root, 'pubspec.lock'), body);
  }

  it('reads a CRLF lockfile', () => {
    const { root, cleanup } = makeRoot();
    try {
      lockWith(root, 'packages:\r\n  saropa_lints:\r\n    dependency: "direct dev"\r\n    version: "16.4.0"\r\n');
      enableCiWorkflow(root);
      assert.ok(readWorkflow(root).includes('saropa/saropa_lints@v16.4.0\n'));
    } finally {
      cleanup();
    }
  });

  it('never takes a neighbouring package\'s version', () => {
    const { root, cleanup } = makeRoot();
    try {
      lockWith(
        root,
        'packages:\n  saropa_lints:\n    dependency: "direct dev"\n    source: path\n' +
          '  saropa_lints_extra:\n    version: "16.9.9"\n',
      );
      enableCiWorkflow(root);
      assert.ok(readWorkflow(root).includes('saropa/saropa_lints@main'));
    } finally {
      cleanup();
    }
  });

  it('pins a pre-release at or above the floor', () => {
    const { root, cleanup } = makeRoot('16.3.0-dev.1');
    try {
      enableCiWorkflow(root);
      assert.ok(readWorkflow(root).includes('saropa/saropa_lints@v16.3.0-dev.1\n'));
    } finally {
      cleanup();
    }
  });

  it('needs an explicit tier only when analysis_options.yaml does not configure saropa_lints', () => {
    const { root, cleanup } = makeRoot();
    try {
      assert.strictEqual(needsExplicitTier(root), true);
      fs.writeFileSync(path.join(root, 'analysis_options.yaml'), 'linter:\n  rules: []\n');
      assert.strictEqual(needsExplicitTier(root), true);
      fs.writeFileSync(
        path.join(root, 'analysis_options.yaml'),
        'include: package:saropa_lints/tiers/essential.yaml\n',
      );
      assert.strictEqual(needsExplicitTier(root), false);
    } finally {
      cleanup();
    }
  });
});
