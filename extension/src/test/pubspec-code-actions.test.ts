// Must be first import — redirects 'vscode' to the local mock
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as vscode from 'vscode';
import { PubspecCodeActionProvider } from '../pubspec-code-actions';
import {
    MockDiagnosticCollection,
    Diagnostic,
    DiagnosticSeverity,
} from './vibrancy/vscode-mock';

// ── Helpers ───────────────────────────────────────────────────

/** Create a minimal Diagnostic matching what PubspecValidation produces. */
function makeDiag(
    line: number,
    startChar: number,
    endChar: number,
    code: string,
    message = '',
): vscode.Diagnostic {
    const range = new vscode.Range(line, startChar, line, endChar);
    const diag = new vscode.Diagnostic(
        range, message, DiagnosticSeverity.Information as any,
    );
    diag.source = 'Saropa Lints';
    diag.code = code;
    return diag;
}

/**
 * Simulate provideCodeActions for a given document content and diagnostic.
 * Returns the array of CodeAction objects produced by the provider.
 */
function getActions(
    content: string,
    diag: vscode.Diagnostic,
): vscode.CodeAction[] {
    const provider = new PubspecCodeActionProvider();
    const uri = vscode.Uri.file('/test/pubspec.yaml');

    // Build a minimal TextDocument mock with getText and lineAt
    const lines = content.split('\n');
    const doc = {
        uri,
        getText(range?: vscode.Range): string {
            if (!range) { return content; }
            // Single-line range extraction
            const line = lines[range.start.line] ?? '';
            return line.substring(range.start.character, range.end.character);
        },
        lineAt(lineNum: number) {
            return {
                text: lines[lineNum] ?? '',
                range: new vscode.Range(
                    lineNum, 0, lineNum, (lines[lineNum] ?? '').length,
                ),
            };
        },
    } as any;

    const context = {
        diagnostics: [diag],
        triggerKind: 1,
        only: undefined,
    } as any;

    return provider.provideCodeActions(doc, diag.range, context);
}

// ── Tests ─────────────────────────────────────────────────────

describe('PubspecCodeActionProvider', () => {
    describe('prefer_caret_version_syntax fix', () => {
        it('adds ^ prefix to bare version', () => {
            const content = 'dependencies:\n  http: 1.2.3\n';
            const diag = makeDiag(1, 2, 6, 'prefer_caret_version_syntax');
            const actions = getActions(content, diag);

            assert.strictEqual(actions.length, 1);
            assert.ok(actions[0].title.includes('^1.2.3'));
            assert.ok(actions[0].isPreferred);
            assert.ok(actions[0].edit);
        });

        it('ignores diagnostics from other sources', () => {
            const content = 'dependencies:\n  http: 1.2.3\n';
            const diag = makeDiag(1, 2, 6, 'prefer_caret_version_syntax');
            diag.source = 'Other Source';
            const actions = getActions(content, diag);

            assert.strictEqual(actions.length, 0);
        });
    });

    describe('prefer_pinned_version_syntax fix', () => {
        it('removes ^ from caret version', () => {
            const content = 'dependencies:\n  http: ^1.2.3\n';
            const diag = makeDiag(1, 2, 6, 'prefer_pinned_version_syntax');
            const actions = getActions(content, diag);

            assert.strictEqual(actions.length, 1);
            assert.ok(actions[0].title.includes('remove ^'));
            assert.ok(actions[0].isPreferred);
            assert.ok(actions[0].edit);
        });
    });

    describe('prefer_publish_to_none fix', () => {
        it('inserts publish_to: none after name line', () => {
            const content = 'name: my_app\nversion: 1.0.0\n';
            const diag = makeDiag(0, 0, 12, 'prefer_publish_to_none');
            const actions = getActions(content, diag);

            assert.strictEqual(actions.length, 1);
            assert.ok(actions[0].title.includes('publish_to'));
            assert.ok(actions[0].isPreferred);
            assert.ok(actions[0].edit);
        });
    });

    describe('newline_before_pubspec_entry fix', () => {
        it('inserts blank line before entry', () => {
            const content = 'name: my_app\nversion: 1.0.0\n';
            const diag = makeDiag(1, 0, 14, 'newline_before_pubspec_entry');
            const actions = getActions(content, diag);

            assert.strictEqual(actions.length, 1);
            assert.ok(actions[0].title.includes('blank line'));
            assert.ok(actions[0].isPreferred);
            assert.ok(actions[0].edit);
        });
    });

    describe('add_resolution_workspace fix', () => {
        it('inserts resolution: workspace before workspace line', () => {
            const content = 'name: my_app\n\nworkspace:\n  - packages/app\n';
            const diag = makeDiag(2, 0, 10, 'add_resolution_workspace');
            const actions = getActions(content, diag);

            assert.strictEqual(actions.length, 1);
            assert.ok(actions[0].title.includes('resolution'));
            assert.ok(actions[0].isPreferred);
            assert.ok(actions[0].edit);
        });
    });

    describe('unhandled diagnostics', () => {
        it('returns no actions for diagnostics without fixes', () => {
            const content = 'dependencies:\n  zebra: ^1.0.0\n  alpha: ^2.0.0\n';
            const diag = makeDiag(1, 2, 7, 'dependencies_ordering');
            const actions = getActions(content, diag);

            assert.strictEqual(actions.length, 0);
        });
    });
});
