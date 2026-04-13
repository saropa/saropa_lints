/**
 * Quick-fix code actions for pubspec validation diagnostics.
 *
 * Provides CodeActionKind.QuickFix for diagnostics produced by
 * PubspecValidation. Only offers fixes that make a real code change —
 * no "insert TODO" style fixes per project guidelines.
 *
 * Supported fixes:
 * - prefer_caret_version_syntax: `1.2.3` → `^1.2.3`
 * - prefer_pinned_version_syntax: `^1.2.3` → `1.2.3`
 * - prefer_publish_to_none: insert `publish_to: none` after `name:`
 * - newline_before_pubspec_entry: insert blank line before entry
 * - add_resolution_workspace: insert `resolution: workspace`
 *
 * Registered alongside the existing VibrancyCodeActionProvider on the
 * same `pubspec.yaml` selector — VS Code merges actions from multiple
 * providers into one lightbulb menu.
 */

import * as vscode from 'vscode';

const SOURCE = 'Saropa Lints';

export class PubspecCodeActionProvider implements vscode.CodeActionProvider {
    provideCodeActions(
        document: vscode.TextDocument,
        _range: vscode.Range,
        context: vscode.CodeActionContext,
    ): vscode.CodeAction[] {
        const actions: vscode.CodeAction[] = [];

        for (const diag of context.diagnostics) {
            if (diag.source !== SOURCE) { continue; }

            const code = typeof diag.code === 'object' && 'value' in diag.code
                ? diag.code.value
                : diag.code;

            switch (code) {
                case 'prefer_caret_version_syntax':
                    actions.push(
                        this._fixCaretSyntax(document, diag),
                    );
                    break;
                case 'prefer_pinned_version_syntax':
                    actions.push(
                        this._fixPinnedSyntax(document, diag),
                    );
                    break;
                case 'prefer_publish_to_none':
                    actions.push(
                        this._fixPublishToNone(document, diag),
                    );
                    break;
                case 'newline_before_pubspec_entry':
                    actions.push(
                        this._fixNewlineBefore(document, diag),
                    );
                    break;
                case 'add_resolution_workspace':
                    actions.push(
                        this._fixResolutionWorkspace(document, diag),
                    );
                    break;
            }
        }

        return actions;
    }

    /**
     * prefer_caret_version_syntax: `1.2.3` → `^1.2.3`.
     *
     * The diagnostic highlights the package name. The bare version is
     * on the same line after the colon. We find the version portion
     * and prepend `^`.
     */
    private _fixCaretSyntax(
        document: vscode.TextDocument,
        diag: vscode.Diagnostic,
    ): vscode.CodeAction {
        const lineText = document.lineAt(diag.range.start.line).text;
        // Match the version after the colon, stripping optional quotes
        const versionMatch = lineText.match(
            /:\s*['"]?(\d+\.\d+\.\d+\S*)['"]?\s*$/,
        );

        const action = new vscode.CodeAction(
            `Use caret syntax: ^${versionMatch?.[1] ?? '...'}`,
            vscode.CodeActionKind.QuickFix,
        );
        action.diagnostics = [diag];
        action.isPreferred = true;

        if (versionMatch) {
            const versionStart = lineText.indexOf(
                versionMatch[1], lineText.indexOf(':'),
            );
            const versionRange = new vscode.Range(
                diag.range.start.line, versionStart,
                diag.range.start.line, versionStart + versionMatch[1].length,
            );
            action.edit = new vscode.WorkspaceEdit();
            action.edit.replace(
                document.uri, versionRange, `^${versionMatch[1]}`,
            );
        }

        return action;
    }

    /**
     * prefer_pinned_version_syntax: `^1.2.3` → `1.2.3`.
     *
     * The diagnostic highlights the package name. The caret version is
     * on the same line. We find `^` and remove it.
     */
    private _fixPinnedSyntax(
        document: vscode.TextDocument,
        diag: vscode.Diagnostic,
    ): vscode.CodeAction {
        const lineText = document.lineAt(diag.range.start.line).text;
        const caretIdx = lineText.indexOf('^', lineText.indexOf(':'));

        const action = new vscode.CodeAction(
            'Pin exact version (remove ^)',
            vscode.CodeActionKind.QuickFix,
        );
        action.diagnostics = [diag];
        action.isPreferred = true;

        if (caretIdx >= 0) {
            // Delete just the `^` character
            const caretRange = new vscode.Range(
                diag.range.start.line, caretIdx,
                diag.range.start.line, caretIdx + 1,
            );
            action.edit = new vscode.WorkspaceEdit();
            action.edit.delete(document.uri, caretRange);
        }

        return action;
    }

    /**
     * prefer_publish_to_none: insert `publish_to: none` after `name:`.
     *
     * The diagnostic is on the `name:` line. Insert a new line with
     * `publish_to: none` immediately after it (with blank line).
     */
    private _fixPublishToNone(
        document: vscode.TextDocument,
        diag: vscode.Diagnostic,
    ): vscode.CodeAction {
        const action = new vscode.CodeAction(
            "Add 'publish_to: none'",
            vscode.CodeActionKind.QuickFix,
        );
        action.diagnostics = [diag];
        action.isPreferred = true;

        // Insert after the name: line
        const insertPos = new vscode.Position(
            diag.range.start.line + 1, 0,
        );
        action.edit = new vscode.WorkspaceEdit();
        action.edit.insert(
            document.uri, insertPos, '\npublish_to: none\n',
        );

        return action;
    }

    /**
     * newline_before_pubspec_entry: insert blank line before a
     * top-level key that lacks one.
     */
    private _fixNewlineBefore(
        document: vscode.TextDocument,
        diag: vscode.Diagnostic,
    ): vscode.CodeAction {
        const action = new vscode.CodeAction(
            'Insert blank line',
            vscode.CodeActionKind.QuickFix,
        );
        action.diagnostics = [diag];
        action.isPreferred = true;

        // Insert a blank line at the start of the flagged line
        const insertPos = new vscode.Position(
            diag.range.start.line, 0,
        );
        action.edit = new vscode.WorkspaceEdit();
        action.edit.insert(document.uri, insertPos, '\n');

        return action;
    }

    /**
     * add_resolution_workspace: insert `resolution: workspace`
     * before the `workspace:` line.
     */
    private _fixResolutionWorkspace(
        document: vscode.TextDocument,
        diag: vscode.Diagnostic,
    ): vscode.CodeAction {
        const action = new vscode.CodeAction(
            "Add 'resolution: workspace'",
            vscode.CodeActionKind.QuickFix,
        );
        action.diagnostics = [diag];
        action.isPreferred = true;

        // Insert before the workspace: line
        const insertPos = new vscode.Position(
            diag.range.start.line, 0,
        );
        action.edit = new vscode.WorkspaceEdit();
        action.edit.insert(
            document.uri, insertPos, 'resolution: workspace\n\n',
        );

        return action;
    }
}
