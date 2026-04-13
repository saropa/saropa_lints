/**
 * Regression tests for shared vscode mock behavior.
 * quickPickNextResult is a const object with a mutable `.value` so the export
 * stays `const` while tests can still drive `showQuickPick` outcomes.
 */
import './register-vscode-mock';

import * as assert from 'node:assert';
import * as vscode from 'vscode';
import { quickPickNextResult, resetMocks, setQuickPickNextResult } from './vscode-mock';

describe('vscode-mock quick pick hook', () => {
  afterEach(() => {
    resetMocks();
  });

  it('showQuickPick returns the object set via setQuickPickNextResult (stable const export)', async () => {
    const chosen = { label: 'chosen' };
    setQuickPickNextResult(chosen);
    const picked = await vscode.window.showQuickPick([{ label: 'a' }, { label: 'b' }]);
    assert.strictEqual(picked, chosen);
  });

  it('resetMocks clears the hook so showQuickPick returns undefined', async () => {
    setQuickPickNextResult({ label: 'x' });
    resetMocks();
    const picked = await vscode.window.showQuickPick([{ label: 'only' }]);
    assert.strictEqual(picked, undefined);
  });

  it('exposes the same quickPickNextResult object across imports (holder identity)', () => {
    const a = quickPickNextResult;
    setQuickPickNextResult({ label: 'id' });
    assert.strictEqual(quickPickNextResult, a);
    assert.ok(a.value && typeof (a.value as { label: string }).label === 'string');
  });
});
