import * as vscode from 'vscode';
import { findPackageRange } from '../services/pubspec-parser';
import {
    findPubspecYaml, buildVersionEdit, findPackageLines, buildBackupUri,
    readVersionConstraint,
} from '../services/pubspec-editor';
import {
    addSuppressedPackage, removeSuppressedPackage,
} from '../services/config-service';
import { DetailItem, PackageItem } from './tree-items';
import { copyTreeNodesToClipboard } from '../../copyTreeAsJson';
import { serializeVibrancyNode } from '../../treeSerializers';
import { DetailViewProvider } from '../views/detail-view-provider';
import { DetailLogger } from '../services/detail-logger';
import { getLatestResults, getScannedPubspecUri } from '../extension-activation';
import { UpdateFromCodeLensArgs } from './codelens-provider';
import { ComparisonPanel } from '../views/comparison-webview';
import { resultToComparisonData } from '../scoring/comparison-ranker';
import { resolvePackagePaths } from '../services/package-code-analyzer';

// Re-export for backward compatibility
export { findPubspecYaml, buildVersionEdit, findPackageLines, readVersionConstraint };

let _detailViewProvider: DetailViewProvider | null = null;
let _detailLogger: DetailLogger | null = null;

/**
 * Guard for commands that require a PackageItem from the Packages view.
 * Returns true if item has result.package.name; otherwise shows a warning and returns false.
 */
function requirePackageItem(
    item: PackageItem | undefined,
    actionLabel: string,
): item is PackageItem {
    if (item?.result?.package?.name) { return true; }
    vscode.window.showWarningMessage(
        `${actionLabel} is only available for package items in the Packages view.`,
    );
    return false;
}

/** Register tree-item commands (navigate, open, update, copy, suppress). */
export function registerTreeCommands(
    context: vscode.ExtensionContext,
    treeProvider: { getChildren(element?: unknown): unknown[] },
    detailViewProvider?: DetailViewProvider | null,
    detailLogger?: DetailLogger | null,
): void {
    _detailViewProvider = detailViewProvider ?? null;
    _detailLogger = detailLogger ?? null;

    // Bind getChildren for the copy command to use for recursive serialization.
    const getChildren = (n: unknown) => treeProvider.getChildren(n as never);

    context.subscriptions.push(
        vscode.commands.registerCommand('saropaLints.packageVibrancy.goToPackage', goToPackage),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.goToLine', goToLine),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.openOnPubDev', openOnPubDev),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.showChangelog', showChangelog),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.updateToLatest', updateToLatest),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.copyAsJson',
            (item: unknown, selected?: unknown[]) =>
                copyTreeNodesToClipboard(item, selected, serializeVibrancyNode, getChildren, 'Vibrancy'),
        ),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.suppressPackage', suppressPackage),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.unsuppressPackage', unsuppressPackage),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.openUrl', openUrl),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.commentOutUnused', commentOutUnused),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.deleteUnused', deleteUnused),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.focusDetails', focusDetails),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.logDetails', logDetails),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.logAllDetails', logAllDetails),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.updateFromCodeLens', updateFromCodeLens),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.focusPackageInTree', focusPackageInTree),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.compareSelected', compareSelected),
        vscode.commands.registerCommand('saropaLints.packageVibrancy.openSourceFolder', openSourceFolder),
    );
}

/**
 * Resolve the pubspec.yaml URI, preferring the scanned URI from the last scan
 * over a workspace-wide glob (which can return a wrong file in multi-root workspaces).
 */
async function resolveScannedPubspec(): Promise<vscode.Uri | null> {
    return getScannedPubspecUri() ?? await findPubspecYaml();
}

/** Navigate to a package's entry in pubspec.yaml. */
async function goToPackage(packageName: string | undefined): Promise<void> {
    if (!packageName || typeof packageName !== 'string') { return; }
    const yamlUri = await resolveScannedPubspec();
    if (!yamlUri) { return; }

    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const range = findPackageRange(doc.getText(), packageName);
    if (!range) { return; }

    const pos = new vscode.Position(range.line, range.startChar);
    const sel = new vscode.Selection(pos, pos);
    await vscode.window.showTextDocument(doc, { selection: sel });
}

/** Open pubspec.yaml at a given 0-based line. Used when clicking a problem in the Problems view. */
async function goToLine(line: number | undefined): Promise<void> {
    if (line == null || typeof line !== 'number' || line < 0) { return; }
    const yamlUri = await resolveScannedPubspec();
    if (!yamlUri) { return; }

    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const pos = new vscode.Position(line, 0);
    const sel = new vscode.Selection(pos, pos);
    await vscode.window.showTextDocument(doc, { selection: sel });
}

/** Open a package's pub.dev page in the browser. */
async function openOnPubDev(item: PackageItem | undefined): Promise<void> {
    if (!requirePackageItem(item, 'Open on pub.dev')) { return; }
    const url = `https://pub.dev/packages/${item.result.package.name}`;
    await vscode.env.openExternal(vscode.Uri.parse(url));
}

/** Open a package's changelog on pub.dev (used by detail view). */
async function showChangelog(packageName: string | undefined): Promise<void> {
    if (!packageName || typeof packageName !== 'string') { return; }
    const url = `https://pub.dev/packages/${packageName}/changelog`;
    await vscode.env.openExternal(vscode.Uri.parse(url));
}

/** Open a URL in the default browser (from click or inline action). */
async function openUrl(urlOrItem: string | DetailItem): Promise<void> {
    if (!urlOrItem) { return; }
    const url = typeof urlOrItem === 'string' ? urlOrItem : urlOrItem.url;
    if (!url) { return; }
    await vscode.env.openExternal(vscode.Uri.parse(url));
}

/** Replace the version constraint in pubspec.yaml with ^latest. */
async function updateToLatest(item: PackageItem | undefined): Promise<void> {
    if (!requirePackageItem(item, 'Update to Latest')) { return; }
    const latest = item.result.updateInfo?.latestVersion;
    if (!latest) { return; }

    const yamlUri = await resolveScannedPubspec();
    if (!yamlUri) { return; }

    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const edit = buildVersionEdit(doc, item.result.package.name, `^${latest}`);
    if (!edit) {
        vscode.window.showWarningMessage(
            `Could not locate version constraint for ${item.result.package.name}`,
        );
        return;
    }

    const wsEdit = new vscode.WorkspaceEdit();
    wsEdit.replace(yamlUri, edit.range, edit.newText);
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();
}

// copyAsJson is now handled inline by copyTreeNodesToClipboard in registerTreeCommands.

/** Add a package to the suppressed list in workspace settings. */
async function suppressPackage(item: PackageItem | undefined): Promise<void> {
    if (!requirePackageItem(item, 'Suppress')) { return; }
    await addSuppressedPackage(item.result.package.name);
}

/** Remove a package from the suppressed list in workspace settings. */
async function unsuppressPackage(item: PackageItem | undefined): Promise<void> {
    if (!requirePackageItem(item, 'Unsuppress')) { return; }
    await removeSuppressedPackage(item.result.package.name);
}


/** Comment out an unused dependency in pubspec.yaml. */
async function commentOutUnused(item: PackageItem | undefined): Promise<void> {
    if (!requirePackageItem(item, 'Comment Out Unused')) { return; }
    const yamlUri = await resolveScannedPubspec();
    if (!yamlUri) { return; }

    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const lines = findPackageLines(doc, item.result.package.name);
    if (!lines) { return; }

    const wsEdit = new vscode.WorkspaceEdit();
    for (let i = lines.start; i < lines.end; i++) {
        wsEdit.insert(yamlUri, new vscode.Position(i, 0), '# ');
    }
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();
}

/** Delete an unused dependency from pubspec.yaml, creating a backup. */
async function deleteUnused(item: PackageItem | undefined): Promise<void> {
    if (!requirePackageItem(item, 'Delete Unused')) { return; }
    const yamlUri = await resolveScannedPubspec();
    if (!yamlUri) { return; }

    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const lines = findPackageLines(doc, item.result.package.name);
    if (!lines) { return; }

    const backupUri = buildBackupUri(yamlUri);
    const content = new TextEncoder().encode(doc.getText());
    await vscode.workspace.fs.writeFile(backupUri, content);

    const wsEdit = new vscode.WorkspaceEdit();
    const range = new vscode.Range(
        new vscode.Position(lines.start, 0),
        new vscode.Position(lines.end, 0),
    );
    wsEdit.delete(yamlUri, range);
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();

    const backupName = backupUri.path.split('/').pop();
    vscode.window.showInformationMessage(
        `Deleted ${item.result.package.name} from pubspec.yaml (backup: ${backupName})`,
    );
}

/** Focus the package details view in the sidebar. */
function focusDetails(): void {
    if (_detailViewProvider) {
        _detailViewProvider.focus();
    }
}

/** Log a package's details to the output channel. */
function logDetails(item: PackageItem | undefined): void {
    if (!requirePackageItem(item, 'Log to Output')) { return; }
    if (!_detailLogger) { return; }
    _detailLogger.logPackage(item.result);
    _detailLogger.show();
}

/** Log all package details to the output channel. */
function logAllDetails(): void {
    if (!_detailLogger) { return; }
    const results = getLatestResults();
    if (results.length === 0) {
        vscode.window.showWarningMessage('Run a scan first');
        return;
    }
    _detailLogger.clear();
    _detailLogger.logAllPackages(results);
    _detailLogger.show();
}

/** Update a package version directly from CodeLens click. */
async function updateFromCodeLens(args: UpdateFromCodeLensArgs): Promise<void> {
    if (!args || !args.packageName || !args.targetVersion) {
        return;
    }

    const yamlUri = args.pubspecPath
        ? vscode.Uri.file(args.pubspecPath)
        : await resolveScannedPubspec();

    if (!yamlUri) {
        vscode.window.showWarningMessage('Could not find pubspec.yaml');
        return;
    }

    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const newConstraint = `^${args.targetVersion}`;
    const edit = buildVersionEdit(doc, args.packageName, newConstraint);

    if (!edit) {
        vscode.window.showWarningMessage(
            `Could not locate version constraint for ${args.packageName}`,
        );
        return;
    }

    const wsEdit = new vscode.WorkspaceEdit();
    wsEdit.replace(yamlUri, edit.range, edit.newText);
    const applied = await vscode.workspace.applyEdit(wsEdit);

    if (applied) {
        await doc.save();
        vscode.window.showInformationMessage(
            `Updated ${args.packageName} to ${newConstraint}`,
        );
    } else {
        vscode.window.showWarningMessage(
            `Failed to update ${args.packageName}`,
        );
    }
}

/** Focus a package in the tree view and show its details. */
async function focusPackageInTree(packageName: string): Promise<void> {
    if (!packageName) { return; }

    await vscode.commands.executeCommand(
        'saropaLints.packageVibrancy.packages.focus',
    );

    const results = getLatestResults();
    const result = results.find(r => r.package.name === packageName);

    if (result && _detailViewProvider) {
        _detailViewProvider.update(result);
    }
}

/** Compare selected packages in a side-by-side view. */
function compareSelected(
    _item: PackageItem | undefined,
    selectedItems?: PackageItem[],
): void {
    const raw = Array.isArray(selectedItems) ? selectedItems : [];
    const items = raw.filter((i): i is PackageItem => !!i?.result);

    if (items.length < 2) {
        vscode.window.showWarningMessage('Select 2-3 packages to compare');
        return;
    }

    if (items.length > 3) {
        vscode.window.showWarningMessage('Maximum 3 packages for comparison');
        return;
    }

    const comparisonData = items.map(item =>
        resultToComparisonData(item.result, true));

    ComparisonPanel.createOrShow(comparisonData);
}

/**
 * Open the local source folder for a package in the file explorer.
 * Resolves the package path from .dart_tool/package_config.json.
 */
async function openSourceFolder(packageName: string): Promise<void> {
    if (!packageName || typeof packageName !== 'string') { return; }

    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders?.length) { return; }

    const workspaceRoot = workspaceFolders[0].uri;
    const packagePaths = await resolvePackagePaths(workspaceRoot);
    const localPath = packagePaths.get(packageName);

    if (!localPath) {
        vscode.window.showWarningMessage(
            `Could not find local source for ${packageName}`,
        );
        return;
    }

    // Open the package root folder in a new VS Code window so the user
    // can browse the source code directly in the editor.
    await vscode.commands.executeCommand('vscode.openFolder', localPath, {
        forceNewWindow: true,
    });
}

