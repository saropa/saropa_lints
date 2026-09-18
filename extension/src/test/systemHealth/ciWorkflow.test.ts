import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

import {
  disableCiWorkflow,
  enableCiWorkflow,
  getCiWorkflowPath,
  getCiWorkflowState,
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
