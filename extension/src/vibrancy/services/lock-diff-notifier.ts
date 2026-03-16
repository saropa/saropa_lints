import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import { diffVersionMaps } from './lock-diff';
import { summarizeDiff, narrateDiff } from '../scoring/diff-narrator';

let diffOutputChannel: vscode.OutputChannel | null = null;

/** Capture current package versions for later comparison. */
export function snapshotVersions(
    results: readonly VibrancyResult[],
): Map<string, string> {
    return new Map(results.map(r => [r.package.name, r.package.version]));
}

/** Show notification if lock versions changed between scans. */
export function notifyLockDiff(
    oldVersions: ReadonlyMap<string, string>,
    results: readonly VibrancyResult[],
): void {
    if (oldVersions.size === 0) { return; }
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    if (!config.get<boolean>('showLockDiffNotifications', true)) { return; }

    const newVersions = snapshotVersions(results);
    const diff = diffVersionMaps(oldVersions, newVersions);
    const totalChanges = diff.added.length + diff.removed.length
        + diff.upgraded.length + diff.downgraded.length;
    if (totalChanges === 0) { return; }

    const summary = summarizeDiff(diff);
    vscode.window.showInformationMessage(summary, 'View Details')
        .then(choice => {
            if (choice !== 'View Details') { return; }
            if (!diffOutputChannel) {
                diffOutputChannel = vscode.window.createOutputChannel(
                    'Saropa Lock Diff',
                );
            }
            diffOutputChannel.clear();
            diffOutputChannel.appendLine(narrateDiff(diff));
            diffOutputChannel.show(true);
        });
}
