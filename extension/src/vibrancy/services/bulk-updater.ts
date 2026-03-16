import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import {
    classifyIncrement, filterByIncrement, formatIncrement,
    IncrementFilter, VersionIncrement,
} from '../scoring/version-increment';
import { buildVersionEdit, findPubspecYaml } from './pubspec-editor';

/** Options for bulk update operation. */
export interface BulkUpdateOptions {
    readonly incrementFilter: IncrementFilter;
    readonly skipConfirmation?: boolean;
}

/** A single update that was applied or skipped. */
export interface UpdateEntry {
    readonly name: string;
    readonly from: string;
    readonly to: string;
    readonly increment: VersionIncrement;
}

/** A package that was skipped with reason. */
export interface SkippedEntry {
    readonly name: string;
    readonly reason: string;
}

/** Result of a bulk update operation. */
export interface BulkUpdateResult {
    readonly updated: readonly UpdateEntry[];
    readonly skipped: readonly SkippedEntry[];
    readonly cancelled: boolean;
}

/**
 * Get packages that can be updated, filtering by suppressed/allowlist.
 * Returns entries grouped by the update action that would be performed.
 */
export function getUpdatablePackages(
    results: readonly VibrancyResult[],
    suppressedSet: ReadonlySet<string>,
    allowlistSet: ReadonlySet<string>,
    filter: IncrementFilter,
): { updatable: UpdateEntry[]; skipped: SkippedEntry[] } {
    const updatable: UpdateEntry[] = [];
    const skipped: SkippedEntry[] = [];

    const filtered = filterByIncrement(results, filter);
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

        const increment = classifyIncrement(
            updateInfo.currentVersion,
            updateInfo.latestVersion,
        );

        if (!filteredNames.has(name)) {
            skipped.push({
                name,
                reason: `not a ${filter} update (is ${formatIncrement(increment)})`,
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
export async function applyBulkUpdates(
    entries: readonly UpdateEntry[],
): Promise<{ success: boolean; error?: string }> {
    const yamlUri = await findPubspecYaml();
    if (!yamlUri) {
        return { success: false, error: 'No pubspec.yaml found in workspace' };
    }

    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const wsEdit = new vscode.WorkspaceEdit();
    let editCount = 0;

    for (const entry of entries) {
        const newConstraint = `^${entry.to}`;
        const edit = buildVersionEdit(doc, entry.name, newConstraint);

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
export async function confirmBulkUpdate(
    entries: readonly UpdateEntry[],
    filter: IncrementFilter,
): Promise<boolean> {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const confirmationEnabled = config.get<boolean>('bulkUpdateConfirmation', true);

    if (!confirmationEnabled) {
        return true;
    }

    const filterLabel = filter === 'all' ? 'latest' : filter;
    const maxPreview = 5;
    const previewLines = entries.slice(0, maxPreview).map(e =>
        `  • ${e.name}: ^${e.from} → ^${e.to} (${formatIncrement(e.increment)})`,
    );

    if (entries.length > maxPreview) {
        previewLines.push(`  ... and ${entries.length - maxPreview} more`);
    }

    const message = `Update ${entries.length} dependencies to ${filterLabel} versions?\n\n${previewLines.join('\n')}`;

    const choice = await vscode.window.showWarningMessage(
        message,
        { modal: true },
        'Update All',
    );

    return choice === 'Update All';
}

/**
 * Execute a bulk update operation.
 * Filters packages, shows confirmation, and applies updates.
 */
export async function bulkUpdate(
    results: readonly VibrancyResult[],
    options: BulkUpdateOptions,
): Promise<BulkUpdateResult> {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const suppressedPackages = config.get<string[]>('suppressedPackages', []);
    const allowlist = config.get<string[]>('allowlist', []);

    const suppressedSet = new Set(suppressedPackages);
    const allowlistSet = new Set(allowlist);

    const { updatable, skipped } = getUpdatablePackages(
        results,
        suppressedSet,
        allowlistSet,
        options.incrementFilter,
    );

    if (updatable.length === 0) {
        vscode.window.showInformationMessage(
            `No ${options.incrementFilter === 'all' ? '' : options.incrementFilter + ' '}updates available`,
        );
        return { updated: [], skipped, cancelled: false };
    }

    if (!options.skipConfirmation) {
        const confirmed = await confirmBulkUpdate(updatable, options.incrementFilter);
        if (!confirmed) {
            return { updated: [], skipped, cancelled: true };
        }
    }

    const result = await vscode.window.withProgress(
        {
            location: vscode.ProgressLocation.Notification,
            title: `Updating ${updatable.length} packages...`,
            cancellable: false,
        },
        async () => applyBulkUpdates(updatable),
    );

    if (!result.success) {
        vscode.window.showErrorMessage(
            `Bulk update failed: ${result.error}`,
        );
        return { updated: [], skipped, cancelled: false };
    }

    vscode.window.showInformationMessage(
        `Updated ${updatable.length} package${updatable.length === 1 ? '' : 's'}`,
    );

    return { updated: updatable, skipped, cancelled: false };
}

/** Format filter type for display in UI. */
export function formatFilterLabel(filter: IncrementFilter): string {
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
