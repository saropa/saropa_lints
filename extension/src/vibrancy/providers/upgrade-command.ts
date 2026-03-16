import * as vscode from 'vscode';
import { runPubGet, runFlutterTest } from '../services/flutter-cli';
import {
    findPubspecYaml, buildVersionEdit, readVersionConstraint,
} from '../services/pubspec-editor';
import { PackageItem } from './tree-items';

const outputChannel = vscode.window.createOutputChannel('Saropa: Upgrade & Test');
let upgradeInProgress = false;

/** Register the upgrade-and-test command. */
export function registerUpgradeCommand(
    context: vscode.ExtensionContext,
): void {
    context.subscriptions.push(
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.upgradeAndTest',
            (item: PackageItem) => upgradeAndTest(item),
        ),
    );
}

interface UpgradeContext {
    readonly yamlUri: vscode.Uri;
    readonly workspaceDir: string;
    readonly pkgName: string;
    readonly newConstraint: string;
    readonly original: string;
}

/** Upgrade a package, run tests, and rollback on failure. */
async function upgradeAndTest(item: PackageItem): Promise<void> {
    if (upgradeInProgress) {
        vscode.window.showWarningMessage('An upgrade is already in progress');
        return;
    }

    const ctx = await buildUpgradeContext(item);
    if (!ctx) { return; }

    upgradeInProgress = true;
    try {
        await runUpgradeWorkflow(ctx);
    } finally {
        upgradeInProgress = false;
    }
}

async function buildUpgradeContext(
    item: PackageItem,
): Promise<UpgradeContext | null> {
    const latest = item.result.updateInfo?.latestVersion;
    if (!latest) { return null; }

    const yamlUri = await findPubspecYaml();
    if (!yamlUri) { return null; }

    const workspaceDir = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!workspaceDir) { return null; }

    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const original = readVersionConstraint(doc, item.result.package.name);
    if (!original) {
        vscode.window.showWarningMessage(
            `Could not read constraint for ${item.result.package.name}`,
        );
        return null;
    }

    return {
        yamlUri, workspaceDir,
        pkgName: item.result.package.name,
        newConstraint: `^${latest}`,
        original,
    };
}

async function runUpgradeWorkflow(ctx: UpgradeContext): Promise<void> {
    await vscode.window.withProgress(
        {
            location: vscode.ProgressLocation.Notification,
            title: `Upgrade & Test: ${ctx.pkgName}`,
            cancellable: false,
        },
        (progress) => executeSteps(ctx, progress),
    );
}

async function executeSteps(
    ctx: UpgradeContext,
    progress: vscode.Progress<{ message?: string }>,
): Promise<void> {
    outputChannel.clear();
    outputChannel.show(true);
    log(`Upgrading ${ctx.pkgName}: ${ctx.original} → ${ctx.newConstraint}`);

    const doc = await vscode.workspace.openTextDocument(ctx.yamlUri);
    if (!await applyConstraint(ctx.yamlUri, doc, ctx.pkgName, ctx.newConstraint)) {
        return;
    }

    progress.report({ message: 'Running flutter pub get...' });
    log('\n--- flutter pub get ---');
    const pubGetResult = await runPubGet(ctx.workspaceDir);
    log(pubGetResult.output);

    if (!pubGetResult.success) {
        log('\npub get FAILED — rolling back');
        await rollback(ctx);
        showFailure(ctx.pkgName, 'flutter pub get');
        return;
    }

    progress.report({ message: 'Running flutter test...' });
    log('\n--- flutter test ---');
    const testResult = await runFlutterTest(ctx.workspaceDir);
    log(testResult.output);

    if (!testResult.success) {
        log('\nTests FAILED — rolling back');
        await rollback(ctx);
        showFailure(ctx.pkgName, 'flutter test');
        return;
    }

    log(`\nUpgrade successful: ${ctx.pkgName} ${ctx.newConstraint}`);
    vscode.window.showInformationMessage(
        `${ctx.pkgName} upgraded to ${ctx.newConstraint} — all tests pass`,
    );
}

async function applyConstraint(
    yamlUri: vscode.Uri,
    doc: vscode.TextDocument,
    pkgName: string,
    constraint: string,
): Promise<boolean> {
    const edit = buildVersionEdit(doc, pkgName, constraint);
    if (!edit) {
        vscode.window.showWarningMessage(
            `Could not locate version constraint for ${pkgName}`,
        );
        return false;
    }
    const wsEdit = new vscode.WorkspaceEdit();
    wsEdit.replace(yamlUri, edit.range, edit.newText);
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();
    return true;
}

async function rollback(ctx: UpgradeContext): Promise<void> {
    const doc = await vscode.workspace.openTextDocument(ctx.yamlUri);
    await applyConstraint(ctx.yamlUri, doc, ctx.pkgName, ctx.original);
    log('Restoring dependencies...');
    const restore = await runPubGet(ctx.workspaceDir);
    log(restore.output);
    log(restore.success ? 'Rollback complete' : 'Rollback pub get failed');
}

function showFailure(pkgName: string, phase: string): void {
    vscode.window.showWarningMessage(
        `${pkgName} upgrade rolled back — ${phase} failed. See output for details.`,
    );
}

function log(message: string): void {
    outputChannel.appendLine(message);
}
