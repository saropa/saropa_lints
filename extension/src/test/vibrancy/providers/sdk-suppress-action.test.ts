/**
 * Tests the "Suppress (intentional old SDK)" quick fix for sdk-constraint
 * diagnostics: where the ignore comment lands for each line shape.
 */
import '../register-vscode-mock';
import * as assert from 'assert';
import * as vscode from 'vscode';
import { VibrancyCodeActionProvider } from '../../../vibrancy/providers/code-action-provider';

const TITLE = 'Suppress (intentional old SDK)';

/** One-line pubspec document; only the members the provider touches. */
function makeLineDoc(text: string): vscode.TextDocument {
    return {
        uri: vscode.Uri.file('/test/pubspec.yaml'),
        getText: (_r?: vscode.Range) => text,
        lineAt: (_p: unknown) => ({
            text, lineNumber: 0, range: new vscode.Range(0, 0, 0, text.length),
        }),
    } as unknown as vscode.TextDocument;
}

/** Requests actions for an sdk-constraint diagnostic on [text]. */
function actionsFor(text: string): vscode.CodeAction[] {
    const diag = {
        range: new vscode.Range(0, 7, 0, text.length),
        message: 'x',
        severity: vscode.DiagnosticSeverity.Information,
        source: 'Package Vibrancy',
        code: 'sdk-constraint',
    } as vscode.Diagnostic;
    const ctx = { diagnostics: [diag] } as unknown as vscode.CodeActionContext;
    return new VibrancyCodeActionProvider().provideCodeActions(makeLineDoc(text), diag.range, ctx);
}

/** The single text edit produced by the suppress action. */
function suppressEdit(text: string): { newText: string; range: { start: { character: number } } } {
    const action = actionsFor(text).find(a => a.title === TITLE);
    assert.ok(action, 'suppress action missing');
    // MockWorkspaceEdit exposes getEdits(); real WorkspaceEdit would use entries().
    return (action!.edit as unknown as { getEdits(): never[] }).getEdits()[0];
}

describe('sdk-constraint suppress quick fix', () => {
    it('is offered on the flutter: line, without the >=3.11.0 raise', () => {
        const titles = actionsFor('  flutter: ">=3.32.0"').map(a => a.title);
        assert.deepStrictEqual(titles, [TITLE]);
    });

    it('is offered alongside the raise on the sdk: line', () => {
        const titles = actionsFor('  sdk: ^3.8.0').map(a => a.title);
        assert.ok(titles.includes(TITLE));
        assert.ok(titles.includes('Set Dart SDK to >=3.11.0'));
    });

    it('appends an ignore comment when the line has none', () => {
        assert.strictEqual(
            suppressEdit('  sdk: ^3.8.0').newText,
            '  # saropa_lints:ignore sdk-constraint',
        );
    });

    it('extends an existing code-list directive', () => {
        assert.strictEqual(
            suppressEdit('  sdk: ^3.8.0  # saropa_lints:ignore foo').newText,
            ', sdk-constraint',
        );
    });

    it('uses a comment line above when the directive has trailing prose', () => {
        const edit = suppressEdit('  sdk: ^3.8.0  # saropa_lints:ignore foo because bar');
        assert.strictEqual(edit.newText, '  # saropa_lints:ignore sdk-constraint\n');
        assert.strictEqual(edit.range.start.character, 0);
    });
});
