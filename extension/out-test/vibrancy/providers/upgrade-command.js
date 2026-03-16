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
exports.registerUpgradeCommand = registerUpgradeCommand;
const vscode = __importStar(require("vscode"));
const flutter_cli_1 = require("../services/flutter-cli");
const pubspec_editor_1 = require("../services/pubspec-editor");
const outputChannel = vscode.window.createOutputChannel('Saropa: Upgrade & Test');
let upgradeInProgress = false;
/** Register the upgrade-and-test command. */
function registerUpgradeCommand(context) {
    context.subscriptions.push(vscode.commands.registerCommand('saropaLints.packageVibrancy.upgradeAndTest', (item) => upgradeAndTest(item)));
}
/** Upgrade a package, run tests, and rollback on failure. */
async function upgradeAndTest(item) {
    if (upgradeInProgress) {
        vscode.window.showWarningMessage('An upgrade is already in progress');
        return;
    }
    const ctx = await buildUpgradeContext(item);
    if (!ctx) {
        return;
    }
    upgradeInProgress = true;
    try {
        await runUpgradeWorkflow(ctx);
    }
    finally {
        upgradeInProgress = false;
    }
}
async function buildUpgradeContext(item) {
    const latest = item.result.updateInfo?.latestVersion;
    if (!latest) {
        return null;
    }
    const yamlUri = await (0, pubspec_editor_1.findPubspecYaml)();
    if (!yamlUri) {
        return null;
    }
    const workspaceDir = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!workspaceDir) {
        return null;
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const original = (0, pubspec_editor_1.readVersionConstraint)(doc, item.result.package.name);
    if (!original) {
        vscode.window.showWarningMessage(`Could not read constraint for ${item.result.package.name}`);
        return null;
    }
    return {
        yamlUri, workspaceDir,
        pkgName: item.result.package.name,
        newConstraint: `^${latest}`,
        original,
    };
}
async function runUpgradeWorkflow(ctx) {
    await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: `Upgrade & Test: ${ctx.pkgName}`,
        cancellable: false,
    }, (progress) => executeSteps(ctx, progress));
}
async function executeSteps(ctx, progress) {
    outputChannel.clear();
    outputChannel.show(true);
    log(`Upgrading ${ctx.pkgName}: ${ctx.original} → ${ctx.newConstraint}`);
    const doc = await vscode.workspace.openTextDocument(ctx.yamlUri);
    if (!await applyConstraint(ctx.yamlUri, doc, ctx.pkgName, ctx.newConstraint)) {
        return;
    }
    progress.report({ message: 'Running flutter pub get...' });
    log('\n--- flutter pub get ---');
    const pubGetResult = await (0, flutter_cli_1.runPubGet)(ctx.workspaceDir);
    log(pubGetResult.output);
    if (!pubGetResult.success) {
        log('\npub get FAILED — rolling back');
        await rollback(ctx);
        showFailure(ctx.pkgName, 'flutter pub get');
        return;
    }
    progress.report({ message: 'Running flutter test...' });
    log('\n--- flutter test ---');
    const testResult = await (0, flutter_cli_1.runFlutterTest)(ctx.workspaceDir);
    log(testResult.output);
    if (!testResult.success) {
        log('\nTests FAILED — rolling back');
        await rollback(ctx);
        showFailure(ctx.pkgName, 'flutter test');
        return;
    }
    log(`\nUpgrade successful: ${ctx.pkgName} ${ctx.newConstraint}`);
    vscode.window.showInformationMessage(`${ctx.pkgName} upgraded to ${ctx.newConstraint} — all tests pass`);
}
async function applyConstraint(yamlUri, doc, pkgName, constraint) {
    const edit = (0, pubspec_editor_1.buildVersionEdit)(doc, pkgName, constraint);
    if (!edit) {
        vscode.window.showWarningMessage(`Could not locate version constraint for ${pkgName}`);
        return false;
    }
    const wsEdit = new vscode.WorkspaceEdit();
    wsEdit.replace(yamlUri, edit.range, edit.newText);
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();
    return true;
}
async function rollback(ctx) {
    const doc = await vscode.workspace.openTextDocument(ctx.yamlUri);
    await applyConstraint(ctx.yamlUri, doc, ctx.pkgName, ctx.original);
    log('Restoring dependencies...');
    const restore = await (0, flutter_cli_1.runPubGet)(ctx.workspaceDir);
    log(restore.output);
    log(restore.success ? 'Rollback complete' : 'Rollback pub get failed');
}
function showFailure(pkgName, phase) {
    vscode.window.showWarningMessage(`${pkgName} upgrade rolled back — ${phase} failed. See output for details.`);
}
function log(message) {
    outputChannel.appendLine(message);
}
//# sourceMappingURL=upgrade-command.js.map