/**
 * Tests [SdkDiagnostics] suppression: `# saropa_lints:ignore sdk-constraint`
 * on the constraint line or the line above silences the diagnostic.
 */
import '../register-vscode-mock';
import * as assert from 'assert';
import * as vscode from 'vscode';
import { SdkDiagnostics } from '../../../vibrancy/providers/sdk-diagnostics';
import { FlutterRelease } from '../../../vibrancy/services/flutter-releases';

// Minimal release: only the fields SdkDiagnostics reads.
const releases = [{ version: '3.40.0', dartSdkVersion: '3.11.0' }] as unknown as FlutterRelease[];

/** Runs update() on [content] and returns the diagnostics collected for it. */
function run(content: string): readonly vscode.Diagnostic[] {
    const uri = vscode.Uri.file('/test/pubspec.yaml');
    const collection = vscode.languages.createDiagnosticCollection('sdk-test');
    new SdkDiagnostics(collection).update(uri, content, releases);
    const result = collection.get(uri) ?? [];
    collection.dispose();
    return result;
}

describe('SdkDiagnostics suppression', () => {
    it('reports an old SDK minimum by default (positive control)', () => {
        const diags = run('environment:\n  sdk: ^3.8.0\n');
        assert.ok(diags.length > 0, 'old sdk must be flagged without a directive');
    });

    it('is silenced by an inline directive', () => {
        const diags = run('environment:\n  sdk: ^3.8.0  # saropa_lints:ignore sdk-constraint\n');
        assert.strictEqual(diags.length, 0);
    });

    it('is silenced by a directive on the preceding line', () => {
        const diags = run('environment:\n  # saropa_lints:ignore sdk-constraint\n  sdk: ^3.8.0\n');
        assert.strictEqual(diags.length, 0);
    });

    it('is not silenced by an unrelated code', () => {
        const diags = run('environment:\n  sdk: ^3.8.0  # saropa_lints:ignore other_rule\n');
        assert.ok(diags.length > 0);
    });

    it('is silenced by a bare ignore-file directive', () => {
        const diags = run('# saropa_lints:ignore-file\nenvironment:\n  sdk: ^3.8.0\n');
        assert.strictEqual(diags.length, 0);
    });

    it('is silenced by ignore-file listing sdk-constraint', () => {
        const diags = run('environment:\n  sdk: ^3.8.0\n# saropa_lints:ignore-file other, sdk-constraint\n');
        assert.strictEqual(diags.length, 0);
    });

    it('is not silenced by ignore-file listing other codes only', () => {
        const diags = run('# saropa_lints:ignore-file other\nenvironment:\n  sdk: ^3.8.0\n');
        assert.ok(diags.length > 0);
    });
});
