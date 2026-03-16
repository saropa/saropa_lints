"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.VibrancyCodeActionProvider = void 0;
const vscode = __importStar(require("vscode"));
const known_issues_1 = require("../scoring/known-issues");
const override_parser_1 = require("../services/override-parser");
class VibrancyCodeActionProvider {
    _results = new Map();
    updateResults(results) {
        this._results.clear();
        for (const r of results) {
            this._results.set(r.package.name, r);
        }
    }
    provideCodeActions(document, _range, context) {
        const actions = [];
        const seen = new Set();
        for (const diag of context.diagnostics) {
            if (diag.source !== 'Saropa Package Vibrancy') {
                continue;
            }
            const packageName = document.getText(diag.range);
            const issue = (0, known_issues_1.findKnownIssue)(packageName);
            if (!seen.has(packageName)) {
                if (issue?.replacement && (0, known_issues_1.isReplacementPackageName)(issue.replacement)) {
                    const action = new vscode.CodeAction(`Replace with ${issue.replacement}`, vscode.CodeActionKind.QuickFix);
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
                        actions.push(this.createAlternativeAction(document, diag, alt));
                    }
                }
                actions.push(this.createSuppressAction(packageName, diag));
            }
            if (diag.code === 'stale-override') {
                const removeAction = this._createRemoveOverrideAction(document, packageName, diag);
                if (removeAction) {
                    actions.push(removeAction);
                }
            }
            seen.add(packageName);
        }
        return actions;
    }
    createSuppressAction(packageName, diag) {
        const action = new vscode.CodeAction(`Suppress "${packageName}" diagnostics`, vscode.CodeActionKind.QuickFix);
        action.diagnostics = [diag];
        action.command = {
            command: 'saropaLints.packageVibrancy.suppressPackageByName',
            title: 'Suppress Package',
            arguments: [packageName],
        };
        return action;
    }
    _createRemoveOverrideAction(document, packageName, diag) {
        const range = (0, override_parser_1.findOverrideRange)(document.getText(), packageName);
        if (!range) {
            return null;
        }
        const deleteRange = new vscode.Range(range.startLine, 0, range.endLine + 1, 0);
        const action = new vscode.CodeAction(`Remove override for ${packageName}`, vscode.CodeActionKind.QuickFix);
        action.diagnostics = [diag];
        action.edit = new vscode.WorkspaceEdit();
        action.edit.delete(document.uri, deleteRange);
        action.isPreferred = true;
        return action;
    }
    createAlternativeAction(document, diag, alt) {
        const label = alt.source === 'curated'
            ? `Replace with ${alt.name} (recommended)`
            : `Replace with ${alt.name} (similar)`;
        const action = new vscode.CodeAction(label, vscode.CodeActionKind.QuickFix);
        action.diagnostics = [diag];
        action.edit = new vscode.WorkspaceEdit();
        action.edit.replace(document.uri, diag.range, alt.name);
        return action;
    }
}
exports.VibrancyCodeActionProvider = VibrancyCodeActionProvider;
//# sourceMappingURL=code-action-provider.js.map