import * as vscode from 'vscode';
import { VibrancyResult, AlternativeSuggestion } from '../types';
import { findKnownIssue, isReplacementPackageName } from '../scoring/known-issues';
import { findOverrideRange } from '../services/override-parser';

export class VibrancyCodeActionProvider implements vscode.CodeActionProvider {
    private _results = new Map<string, VibrancyResult>();

    updateResults(results: VibrancyResult[]): void {
        this._results.clear();
        for (const r of results) {
            this._results.set(r.package.name, r);
        }
    }

    provideCodeActions(
        document: vscode.TextDocument,
        _range: vscode.Range,
        context: vscode.CodeActionContext,
    ): vscode.CodeAction[] {
        const actions: vscode.CodeAction[] = [];
        const seen = new Set<string>();

        for (const diag of context.diagnostics) {
            if (diag.source !== 'Package Vibrancy') { continue; }
            if (diag.code === 'vibrancy-summary') { continue; }

            const packageName = document.getText(diag.range);
            const issue = findKnownIssue(packageName);

            if (!seen.has(packageName)) {
                if (issue?.replacement && isReplacementPackageName(issue.replacement)) {
                    const action = new vscode.CodeAction(
                        `Replace with ${issue.replacement}`,
                        vscode.CodeActionKind.QuickFix,
                    );
                    action.diagnostics = [diag];
                    action.edit = new vscode.WorkspaceEdit();
                    action.edit.replace(document.uri, diag.range, issue.replacement);
                    action.isPreferred = true;
                    actions.push(action);
                }

                const result = this._results.get(packageName);
                if (result?.alternatives?.length) {
                    for (const alt of result.alternatives) {
                        if (alt.source === 'curated' && alt.name === issue?.replacement) {
                            continue;
                        }
                        actions.push(
                            this.createAlternativeAction(document, diag, alt),
                        );
                    }
                }

                actions.push(this.createSuppressAction(packageName, diag));
            }

            if (diag.code === 'stale-override') {
                const removeAction = this._createRemoveOverrideAction(
                    document, packageName, diag,
                );
                if (removeAction) { actions.push(removeAction); }
            }

            seen.add(packageName);
        }

        return actions;
    }

    private createSuppressAction(
        packageName: string,
        diag: vscode.Diagnostic,
    ): vscode.CodeAction {
        const action = new vscode.CodeAction(
            `Suppress "${packageName}" diagnostics`,
            vscode.CodeActionKind.QuickFix,
        );
        action.diagnostics = [diag];
        action.command = {
            command: 'saropaLints.packageVibrancy.suppressPackageByName',
            title: 'Suppress Package',
            arguments: [packageName],
        };
        return action;
    }

    private _createRemoveOverrideAction(
        document: vscode.TextDocument,
        packageName: string,
        diag: vscode.Diagnostic,
    ): vscode.CodeAction | null {
        const range = findOverrideRange(document.getText(), packageName);
        if (!range) { return null; }

        const deleteRange = new vscode.Range(
            range.startLine, 0,
            range.endLine + 1, 0,
        );
        const action = new vscode.CodeAction(
            `Remove override for ${packageName}`,
            vscode.CodeActionKind.QuickFix,
        );
        action.diagnostics = [diag];
        action.edit = new vscode.WorkspaceEdit();
        action.edit.delete(document.uri, deleteRange);
        action.isPreferred = true;
        return action;
    }

    private createAlternativeAction(
        document: vscode.TextDocument,
        diag: vscode.Diagnostic,
        alt: AlternativeSuggestion,
    ): vscode.CodeAction {
        const label = alt.source === 'curated'
            ? `Replace with ${alt.name} (recommended)`
            : `Replace with ${alt.name} (similar)`;

        const action = new vscode.CodeAction(
            label,
            vscode.CodeActionKind.QuickFix,
        );
        action.diagnostics = [diag];
        action.edit = new vscode.WorkspaceEdit();
        action.edit.replace(document.uri, diag.range, alt.name);
        return action;
    }
}
