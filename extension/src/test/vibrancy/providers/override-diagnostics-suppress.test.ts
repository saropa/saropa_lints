/**
 * Verifies that the stale-override diagnostic can be dismissed in-file with
 * `# saropa_lints:ignore stale-override` (same line or line above), so a
 * deliberate override the analyzer cannot justify is not a permanent warning.
 */
import '../register-vscode-mock';
import * as assert from 'assert';
import * as vscode from 'vscode';
import { VibrancyDiagnostics } from '../../../vibrancy/providers/diagnostics';
import { OverrideAnalysis } from '../../../vibrancy/types';

const analysis = (line: number): OverrideAnalysis => ({
    entry: { name: 'foo', version: '1.0.0', line, isPathDep: false, isGitDep: false },
    status: 'stale',
    blocker: null,
    addedDate: null,
    ageDays: null,
});

/** Runs the override diagnostics pass against [content] and returns the count. */
function countDiagnostics(content: string, line: number): number {
    const diags = new VibrancyDiagnostics({} as vscode.DiagnosticCollection);
    diags.updateOverrideAnalyses([analysis(line)]);
    const out: vscode.Diagnostic[] = [];
    // Private pass invoked directly: update() depends on workspace settings.
    (diags as unknown as {
        _addOverrideDiagnostics(c: string, o: vscode.Diagnostic[]): void;
    })._addOverrideDiagnostics(content, out);
    return out.length;
}

describe('stale-override suppression comment', () => {
    const head = 'dependency_overrides:\n';

    it('reports the warning when no directive is present', () => {
        assert.strictEqual(countDiagnostics(`${head}  foo: 1.0.0\n`, 1), 1);
    });

    it('is silenced by a directive on the same line', () => {
        const c = `${head}  foo: 1.0.0  # saropa_lints:ignore stale-override\n`;
        assert.strictEqual(countDiagnostics(c, 1), 0);
    });

    it('is silenced by a directive on the line above', () => {
        const c = `${head}  # saropa_lints:ignore stale-override\n  foo: 1.0.0\n`;
        assert.strictEqual(countDiagnostics(c, 2), 0);
    });

    it('is not silenced by a directive for a different code', () => {
        const c = `${head}  foo: 1.0.0  # saropa_lints:ignore sdk-constraint\n`;
        assert.strictEqual(countDiagnostics(c, 1), 1);
    });
});
