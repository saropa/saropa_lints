/**
 * Pins the data-shape contract for the command catalog history store.
 *
 * The webview's "Frequent" band ranks tiles by `count`; if migration drops a
 * legacy record (no `count`) or a re-record fails to increment the lifetime
 * counter, the band silently shows the wrong order. The webview itself has no
 * unit-level coverage, so this is the load-bearing test for that behavior.
 */

import * as assert from 'node:assert';
import {
  COMMAND_CATALOG_HISTORY_KEY,
  type CatalogHistoryRecord,
  clearCommandHistory,
  readCommandHistory,
  recordCommandHistory,
} from '../views/commandCatalogHistory';

// Minimal fake of vscode.ExtensionContext.globalState — we only exercise
// `get` and `update` from the history module, so a Map-backed stub is enough.
function makeFakeContext(seed?: unknown): {
  globalState: {
    get: <T>(key: string) => T | undefined;
    update: (key: string, value: unknown) => Thenable<void>;
  };
} {
  const store = new Map<string, unknown>();
  if (seed !== undefined) store.set(COMMAND_CATALOG_HISTORY_KEY, seed);
  return {
    globalState: {
      get: <T>(key: string): T | undefined => store.get(key) as T | undefined,
      update: (key: string, value: unknown): Thenable<void> => {
        store.set(key, value);
        return Promise.resolve();
      },
    },
  };
}

// The history module imports `vscode` only as `import type`, so the runtime
// shape just needs `globalState.get` / `globalState.update`. Casting through
// `unknown` keeps the test free of a real vscode dependency.
function asContext(
  fake: ReturnType<typeof makeFakeContext>,
): Parameters<typeof readCommandHistory>[0] {
  return fake as unknown as Parameters<typeof readCommandHistory>[0];
}

describe('commandCatalogHistory', () => {
  describe('readCommandHistory migration', () => {
    it('returns an empty array when nothing is stored', () => {
      const ctx = asContext(makeFakeContext());
      assert.deepStrictEqual(readCommandHistory(ctx), []);
    });

    it('migrates legacy records (no count field) to count=1', () => {
      // Pre-redesign records had only { command, title, icon, at }. The Frequent
      // band must not silently rank these as undefined.
      const legacy = [
        { command: 'a', title: 'A', icon: 'play', at: 100 },
        { command: 'b', title: 'B', icon: 'gear', at: 200 },
      ];
      const ctx = asContext(makeFakeContext(legacy));
      const out = readCommandHistory(ctx);
      assert.strictEqual(out.length, 2);
      assert.strictEqual(out[0].count, 1);
      assert.strictEqual(out[1].count, 1);
    });

    it('preserves valid count values on read', () => {
      const stored: CatalogHistoryRecord[] = [
        { command: 'x', title: 'X', icon: 'play', at: 9, count: 7 },
      ];
      const ctx = asContext(makeFakeContext(stored));
      const out = readCommandHistory(ctx);
      assert.strictEqual(out[0].count, 7);
    });

    it('coerces non-positive or non-numeric count to 1', () => {
      const garbage = [
        { command: 'a', title: 'A', icon: 'play', at: 1, count: 0 },
        { command: 'b', title: 'B', icon: 'play', at: 2, count: -3 },
        { command: 'c', title: 'C', icon: 'play', at: 3, count: 'oops' },
      ];
      const ctx = asContext(makeFakeContext(garbage));
      const out = readCommandHistory(ctx);
      assert.deepStrictEqual(out.map((r) => r.count), [1, 1, 1]);
    });

    it('drops malformed records (missing required fields)', () => {
      const mixed = [
        { command: 'ok', title: 'OK', icon: 'play', at: 1 },
        { command: 'no-title', icon: 'play', at: 2 },
        { title: 'no-cmd', icon: 'play', at: 3 },
        null,
      ];
      const ctx = asContext(makeFakeContext(mixed));
      const out = readCommandHistory(ctx);
      assert.strictEqual(out.length, 1);
      assert.strictEqual(out[0].command, 'ok');
    });
  });

  describe('recordCommandHistory', () => {
    it('starts a brand new record at count=1', () => {
      const ctx = asContext(makeFakeContext());
      const out = recordCommandHistory(ctx, 'a', 'A', 'play');
      assert.strictEqual(out[0].command, 'a');
      assert.strictEqual(out[0].count, 1);
    });

    it('increments count when the same command is recorded again', () => {
      const ctx = asContext(makeFakeContext());
      recordCommandHistory(ctx, 'a', 'A', 'play');
      recordCommandHistory(ctx, 'a', 'A', 'play');
      const out = recordCommandHistory(ctx, 'a', 'A', 'play');
      assert.strictEqual(out.length, 1);
      assert.strictEqual(out[0].count, 3);
    });

    it('promotes a re-recorded command to the front and bumps `at`', () => {
      const ctx = asContext(makeFakeContext());
      recordCommandHistory(ctx, 'a', 'A', 'play');
      recordCommandHistory(ctx, 'b', 'B', 'gear');
      const before = readCommandHistory(ctx);
      assert.strictEqual(before[0].command, 'b');

      const after = recordCommandHistory(ctx, 'a', 'A', 'play');
      assert.strictEqual(after[0].command, 'a');
      assert.strictEqual(after[0].count, 2);
      assert.ok(after[0].at >= before[0].at);
    });

    it('does not record the catalog-opening meta command', () => {
      const ctx = asContext(makeFakeContext());
      const out = recordCommandHistory(
        ctx,
        'saropaLints.showCommandCatalog',
        'Browse All Commands',
        'list-flat',
      );
      assert.deepStrictEqual(out, []);
    });

    it('caps stored history at 25 records', () => {
      const ctx = asContext(makeFakeContext());
      for (let i = 0; i < 30; i++) {
        recordCommandHistory(ctx, `cmd-${i}`, `Cmd ${i}`, 'play');
      }
      const out = readCommandHistory(ctx);
      assert.strictEqual(out.length, 25);
      // Newest first — `cmd-29` was the last recorded.
      assert.strictEqual(out[0].command, 'cmd-29');
    });

    it('migrates legacy records on next write so subsequent reads carry count', async () => {
      const ctx = asContext(
        makeFakeContext([{ command: 'a', title: 'A', icon: 'play', at: 1 }]),
      );
      const out = recordCommandHistory(ctx, 'a', 'A', 'play');
      // Existing legacy record was migrated to count=1, then incremented to 2.
      assert.strictEqual(out[0].count, 2);
    });
  });

  describe('clearCommandHistory', () => {
    it('empties the stored array', async () => {
      const ctx = asContext(makeFakeContext());
      recordCommandHistory(ctx, 'a', 'A', 'play');
      await clearCommandHistory(ctx);
      assert.deepStrictEqual(readCommandHistory(ctx), []);
    });
  });
});
