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
exports.getUpdatablePackages = getUpdatablePackages;
exports.applyBulkUpdates = applyBulkUpdates;
exports.confirmBulkUpdate = confirmBulkUpdate;
exports.bulkUpdate = bulkUpdate;
exports.formatFilterLabel = formatFilterLabel;
const vscode = __importStar(require("vscode"));
const version_increment_1 = require("../scoring/version-increment");
const pubspec_editor_1 = require("./pubspec-editor");
/**
 * Get packages that can be updated, filtering by suppressed/allowlist.
 * Returns entries grouped by the update action that would be performed.
 */
function getUpdatablePackages(results, suppressedSet, allowlistSet, filter) {
    const updatable = [];
    const skipped = [];
    const filtered = (0, version_increment_1.filterByIncrement)(results, filter);
    const filteredNames = new Set(filtered.map(f => f.package.name));
    for (const pkg of results) {
        const name = pkg.package.name;
        const updateInfo = pkg.updateInfo;
        if (!updateInfo || updateInfo.updateStatus === 'up-to-date') {
            continue;
        }
        if (suppressedSet.has(name)) {
            skipped.push({ name, reason: 'suppressed' });
            continue;
        }
        if (allowlistSet.has(name)) {
            skipped.push({ name, reason: 'in allowlist' });
            continue;
        }
        const increment = (0, version_increment_1.classifyIncrement)(updateInfo.currentVersion, updateInfo.latestVersion);
        if (!filteredNames.has(name)) {
            skipped.push({
                name,
                reason: `not a ${filter} update (is ${(0, version_increment_1.formatIncrement)(increment)})`,
            });
            continue;
        }
        updatable.push({
            name,
            from: updateInfo.currentVersion,
            to: updateInfo.latestVersion,
            increment,
        });
    }
    return { updatable, skipped };
}
/**
 * Apply bulk updates to pubspec.yaml.
 * Updates all packages in the entries list to their latest versions.
 */
async function applyBulkUpdates(entries) {
    const yamlUri = await (0, pubspec_editor_1.findPubspecYaml)();
    if (!yamlUri) {
        return { success: false, error: 'No pubspec.yaml found in workspace' };
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const wsEdit = new vscode.WorkspaceEdit();
    let editCount = 0;
    for (const entry of entries) {
        const newConstraint = `^${entry.to}`;
        const edit = (0, pubspec_editor_1.buildVersionEdit)(doc, entry.name, newConstraint);
        if (edit) {
            wsEdit.replace(yamlUri, edit.range, edit.newText);
            editCount++;
        }
    }
    if (editCount === 0) {
        return { success: false, error: 'No version constraints could be updated' };
    }
    const applied = await vscode.workspace.applyEdit(wsEdit);
    if (!applied) {
        return { success: false, error: 'Failed to apply edits to pubspec.yaml' };
    }
    await doc.save();
    return { success: true };
}
/**
 * Show confirmation dialog for bulk update.
 * Returns true if user confirms, false if cancelled.
 */
async function confirmBulkUpdate(entries, filter) {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const confirmationEnabled = config.get('bulkUpdateConfirmation', true);
    if (!confirmationEnabled) {
        return true;
    }
    const filterLabel = filter === 'all' ? 'latest' : filter;
    const maxPreview = 5;
    const previewLines = entries.slice(0, maxPreview).map(e => `  • ${e.name}: ^${e.from} → ^${e.to} (${(0, version_increment_1.formatIncrement)(e.increment)})`);
    if (entries.length > maxPreview) {
        previewLines.push(`  ... and ${entries.length - maxPreview} more`);
    }
    const message = `Update ${entries.length} dependencies to ${filterLabel} versions?\n\n${previewLines.join('\n')}`;
    const choice = await vscode.window.showWarningMessage(message, { modal: true }, 'Update All');
    return choice === 'Update All';
}
/**
 * Execute a bulk update operation.
 * Filters packages, shows confirmation, and applies updates.
 */
async function bulkUpdate(results, options) {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const suppressedPackages = config.get('suppressedPackages', []);
    const allowlist = config.get('allowlist', []);
    const suppressedSet = new Set(suppressedPackages);
    const allowlistSet = new Set(allowlist);
    const { updatable, skipped } = getUpdatablePackages(results, suppressedSet, allowlistSet, options.incrementFilter);
    if (updatable.length === 0) {
        vscode.window.showInformationMessage(`No ${options.incrementFilter === 'all' ? '' : options.incrementFilter + ' '}updates available`);
        return { updated: [], skipped, cancelled: false };
    }
    if (!options.skipConfirmation) {
        const confirmed = await confirmBulkUpdate(updatable, options.incrementFilter);
        if (!confirmed) {
            return { updated: [], skipped, cancelled: true };
        }
    }
    const result = await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: `Updating ${updatable.length} packages...`,
        cancellable: false,
    }, async () => applyBulkUpdates(updatable));
    if (!result.success) {
        vscode.window.showErrorMessage(`Bulk update failed: ${result.error}`);
        return { updated: [], skipped, cancelled: false };
    }
    vscode.window.showInformationMessage(`Updated ${updatable.length} package${updatable.length === 1 ? '' : 's'}`);
    return { updated: updatable, skipped, cancelled: false };
}
/** Format filter type for display in UI. */
function formatFilterLabel(filter) {
    switch (filter) {
        case 'all':
            return 'Latest';
        case 'major':
            return 'Major Only';
        case 'minor':
            return 'Minor Only';
        case 'patch':
            return 'Patch Only';
    }
}
//# sourceMappingURL=bulk-updater.js.map