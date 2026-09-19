/**
 * Tests for the `files.watcherExclude` audit.
 *
 * Two things pinned here:
 *  - `computeMissingExcludes` is pure: given the current config and whether
 *    a `.claude/worktrees` directory exists, it decides which patterns are
 *    missing without touching vscode or the filesystem.
 *  - `auditWatcherExcludes` dismissal is per-pattern, not all-or-nothing —
 *    a workspace that dismissed the original prompt (via the legacy boolean
 *    flag) can still be offered the newer agent-worktree pattern, and a
 *    workspace with an explicit dismissed-patterns list only re-prompts for
 *    patterns outside that list.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  auditWatcherExcludes,
  computeMissingExcludes,
  findMissingExcludes,
} from '../../systemHealth/watcherExcludeAudit';
import {
  clearTestConfig,
  informationMessageMockQueue,
  messageMock,
  mockWorkspaceFolders,
  setTestConfig,
} from '../vibrancy/vscode-mock';

const UNCONDITIONAL_PATTERNS = [
  '**/*.hprof',
  '**/*.log',
  '**/build/**',
  '**/.dart_tool/**',
  '**/reports/**',
  '**/.vs/**',
  '**/dependency_overrides/**/build/**',
  '**/dependency_overrides/**/.dart_tool/**',
];

/** All unconditional patterns set to true, as if fully configured. */
function fullyConfigured(): Record<string, boolean> {
  const current: Record<string, boolean> = {};
  for (const pattern of UNCONDITIONAL_PATTERNS) {
    current[pattern] = true;
  }
  return current;
}

/** Minimal ExtensionContext stand-in — only workspaceState is exercised. */
function fakeContext(initial: Record<string, unknown> = {}): {
  workspaceState: any;
  store: Map<string, unknown>;
} {
  const store = new Map<string, unknown>(Object.entries(initial));
  return {
    store,
    workspaceState: {
      get: <T>(key: string, defaultValue?: T): T | undefined =>
        store.has(key) ? (store.get(key) as T) : defaultValue,
      update: async (key: string, value: unknown): Promise<void> => {
        if (value === undefined) store.delete(key);
        else store.set(key, value);
      },
    },
  };
}

describe('computeMissingExcludes', () => {
  it('returns nothing when all unconditional patterns are present and no worktrees exist', () => {
    const missing = computeMissingExcludes(fullyConfigured(), {
      hasClaudeWorktrees: false,
    });
    assert.deepStrictEqual(missing, []);
  });

  it('recommends the agent-worktree pattern when worktrees exist and everything else is present', () => {
    const missing = computeMissingExcludes(fullyConfigured(), {
      hasClaudeWorktrees: true,
    });
    assert.deepStrictEqual(missing, ['**/.claude/worktrees/**']);
  });

  it('does not recommend the agent-worktree pattern when no worktrees exist, even if unconfigured', () => {
    const missing = computeMissingExcludes({}, { hasClaudeWorktrees: false });
    assert.ok(!missing.includes('**/.claude/worktrees/**'));
  });

  it('treats a broader "**/.claude/**" exclude as already covering worktrees', () => {
    const current = { ...fullyConfigured(), '**/.claude/**': true };
    const missing = computeMissingExcludes(current, {
      hasClaudeWorktrees: true,
    });
    assert.deepStrictEqual(missing, []);
  });

  it('treats a "**/.claude/worktrees/**" exclude as covering itself', () => {
    const current = {
      ...fullyConfigured(),
      '**/.claude/worktrees/**': true,
    };
    const missing = computeMissingExcludes(current, {
      hasClaudeWorktrees: true,
    });
    assert.deepStrictEqual(missing, []);
  });

  it('lists unconditional patterns that are missing alongside the worktree pattern', () => {
    const missing = computeMissingExcludes(
      { '**/*.hprof': true },
      { hasClaudeWorktrees: true },
    );
    assert.ok(missing.includes('**/*.log'));
    assert.ok(missing.includes('**/.claude/worktrees/**'));
    assert.ok(!missing.includes('**/*.hprof'));
  });
});

describe('auditWatcherExcludes dismissal', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-watcher-audit-'));
    mockWorkspaceFolders.value = [{ uri: { fsPath: tmpDir } }];
    clearTestConfig();
    messageMock.infos.length = 0;
    informationMessageMockQueue.length = 0;
  });

  afterEach(() => {
    mockWorkspaceFolders.value = undefined;
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('legacy boolean dismissal still allows the new .claude pattern to prompt', async () => {
    // Simulate an agent-worktree directory on disk so the pattern is relevant.
    fs.mkdirSync(path.join(tmpDir, '.claude', 'worktrees'), {
      recursive: true,
    });
    setTestConfig('files', 'watcherExclude', fullyConfigured());

    const ctx = fakeContext({ 'watcherExcludeAudit.dismissed': true });
    informationMessageMockQueue.push(undefined); // dismiss the toast without clicking

    await auditWatcherExcludes(ctx as any);

    assert.strictEqual(messageMock.infos.length, 1);
    assert.ok(messageMock.infos[0].includes('**/.claude/worktrees/**'));
    // None of the already-dismissed unconditional patterns should reappear.
    for (const pattern of UNCONDITIONAL_PATTERNS) {
      assert.ok(!messageMock.infos[0].includes(pattern));
    }
  });

  it('legacy boolean dismissal stays silent when there are no worktrees', async () => {
    setTestConfig('files', 'watcherExclude', fullyConfigured());
    const ctx = fakeContext({ 'watcherExcludeAudit.dismissed': true });

    await auditWatcherExcludes(ctx as any);

    assert.strictEqual(messageMock.infos.length, 0);
  });

  it('honors a stored dismissed-patterns list', async () => {
    fs.mkdirSync(path.join(tmpDir, '.claude', 'worktrees'), {
      recursive: true,
    });
    // Fully configured except the worktree pattern is missing, and it was
    // already dismissed once before.
    setTestConfig('files', 'watcherExclude', fullyConfigured());
    const ctx = fakeContext({
      'watcherExcludeAudit.dismissedPatterns': ['**/.claude/worktrees/**'],
    });

    await auditWatcherExcludes(ctx as any);

    assert.strictEqual(messageMock.infos.length, 0);
  });

  it('a stored dismissed-patterns list does not suppress newly missing patterns', async () => {
    // Only the worktree pattern was dismissed before; now an unconditional
    // pattern is also missing and should still prompt.
    const current = fullyConfigured();
    delete current['**/*.log'];
    setTestConfig('files', 'watcherExclude', current);
    const ctx = fakeContext({
      'watcherExcludeAudit.dismissedPatterns': ['**/.claude/worktrees/**'],
    });
    informationMessageMockQueue.push(undefined);

    await auditWatcherExcludes(ctx as any);

    assert.strictEqual(messageMock.infos.length, 1);
    assert.ok(messageMock.infos[0].includes('**/*.log'));
    assert.ok(!messageMock.infos[0].includes('**/.claude/worktrees/**'));
  });
});

describe('findMissingExcludes', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-find-missing-'));
    mockWorkspaceFolders.value = [{ uri: { fsPath: tmpDir } }];
    clearTestConfig();
  });

  afterEach(() => {
    mockWorkspaceFolders.value = undefined;
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('reports the worktree pattern only when .claude/worktrees exists on disk', async () => {
    setTestConfig('files', 'watcherExclude', fullyConfigured());
    assert.deepStrictEqual(await findMissingExcludes(), []);

    fs.mkdirSync(path.join(tmpDir, '.claude', 'worktrees'), { recursive: true });
    assert.deepStrictEqual(await findMissingExcludes(), ['**/.claude/worktrees/**']);
  });

  it('treats a missing files.watcherExclude setting as empty', async () => {
    const missing = await findMissingExcludes();
    assert.deepStrictEqual(missing, UNCONDITIONAL_PATTERNS);
  });

  it('returns nothing extra when no workspace folder is open', async () => {
    mockWorkspaceFolders.value = undefined;
    setTestConfig('files', 'watcherExclude', fullyConfigured());
    assert.deepStrictEqual(await findMissingExcludes(), []);
  });
});
