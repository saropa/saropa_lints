/**
 * Code actions for Package Vibrancy diagnostics: curated replacements, alternatives,
 * suppress-by-name command, SDK constraint quick-fixes, and stale override removal.
 *
 * [provideCodeActions] is O(diagnostics); [seen] dedupes per package name within one request.
 */
import * as vscode from 'vscode';
import { VibrancyResult, AlternativeSuggestion } from '../types';
import { findKnownIssue, isReplacementPackageName } from '../scoring/known-issues';
import { findOverrideRange } from '../services/override-parser';
import { l10n } from '../../i18n/runtime';
import { endsWithIgnoreCodeList } from '../../pubspec-validation';

/** Normalizes [vscode.Diagnostic.code] whether it is a string, number, or `{ value }` object. */
function getDiagnosticCode(diag: vscode.Diagnostic): string | number | undefined {
    const c = diag.code;
    if (c === undefined || c === null) { return c; }
    if (typeof c === 'object' && 'value' in c) { return c.value; }
    return c as string | number;
}

export class VibrancyCodeActionProvider implements vscode.CodeActionProvider {
    /** Latest vibrancy scan keyed by package name for alternative suggestions. */
    private _results = new Map<string, VibrancyResult>();

    /** Replace cached results (typically after a full workspace vibrancy run). */
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
            // Only handle diagnostics produced by this extension's vibrancy analyzer.
            if (diag.source !== 'Package Vibrancy') { continue; }
            const code = getDiagnosticCode(diag);
            if (code === 'sdk-constraint') {
                actions.push(...this.createSdkConstraintActions(document, diag));
                continue;
            }

            const packageName = document.getText(diag.range);
            const issue = findKnownIssue(
                packageName, this._results.get(packageName)?.package.version);

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

            if (code === 'stale-override') {
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

    /** Quick fixes for sdk-constraint: set Dart SDK minimum to >=3.11.0 (saropa_lints 17 floor). Only on sdk: line. */
    private createSdkConstraintActions(
        document: vscode.TextDocument,
        diag: vscode.Diagnostic,
    ): vscode.CodeAction[] {
        const lineText = document.getText(document.lineAt(diag.range.start).range);
        // Suppress applies to both the sdk: and flutter: lines.
        const suppress = this._createSdkSuppressAction(document, diag);
        // The ">=3.11.0" raise only makes sense for the Dart sdk: line.
        if (!lineText.includes('sdk:')) { return [suppress]; }
        const current = document.getText(diag.range);
        const upperMatch = current.match(/<\s*(\d+\.\d+\.\d+)/);
        const upper = upperMatch ? ` <${upperMatch[1]}` : '';
        const actions: vscode.CodeAction[] = [];
        for (const [min, label, preferred] of [
            ['>=3.11.0', 'Set Dart SDK to >=3.11.0', true],
        ] as const) {
            const replacement = min + upper;
            const action = new vscode.CodeAction(
                label,
                vscode.CodeActionKind.QuickFix,
            );
            action.diagnostics = [diag];
            action.edit = new vscode.WorkspaceEdit();
            action.edit.replace(document.uri, diag.range, replacement);
            if (preferred) { action.isPreferred = true; }
            actions.push(action);
        }
        actions.push(suppress);
        return actions;
    }

    /**
     * "Suppress (intentional old SDK)": appends `# saropa_lints:ignore sdk-constraint`
     * to the constraint line, extending an existing directive if one is present
     * (a second directive on the same line would not be parsed).
     */
    private _createSdkSuppressAction(
        document: vscode.TextDocument,
        diag: vscode.Diagnostic,
    ): vscode.CodeAction {
        const action = new vscode.CodeAction(
            l10n('vibrancy.sdkConstraint.suppressOldSdk'),
            vscode.CodeActionKind.QuickFix,
        );
        action.diagnostics = [diag];
        action.edit = new vscode.WorkspaceEdit();
        const line = document.lineAt(diag.range.start.line);
        const text = line.text.trimEnd();
        const end = new vscode.Position(line.lineNumber, text.length);
        // Shared grammar with the parser: pure comma-separated code list only.
        if (endsWithIgnoreCodeList(text)) {
            // Existing directive that ends in a pure code list: extend it.
            action.edit.insert(document.uri, end, ', sdk-constraint');
        } else if (text.includes('saropa_lints:ignore')) {
            // Directive followed by free text: appending would put the code
            // after the prose where the parser reads it as part of a code
            // name, so use a standalone comment on the line above instead.
            const indent = text.match(/^\s*/)?.[0] ?? '';
            action.edit.insert(
                document.uri,
                new vscode.Position(line.lineNumber, 0),
                `${indent}# saropa_lints:ignore sdk-constraint\n`,
            );
        } else {
            action.edit.insert(
                document.uri, end, '  # saropa_lints:ignore sdk-constraint',
            );
        }
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
