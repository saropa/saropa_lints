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
exports.executeUpgradePlan = executeUpgradePlan;
exports.formatUpgradePlan = formatUpgradePlan;
exports.formatUpgradeReport = formatUpgradeReport;
const vscode = __importStar(require("vscode"));
const child_process_1 = require("child_process");
const flutter_cli_1 = require("./flutter-cli");
const pubspec_editor_1 = require("./pubspec-editor");
/** Execute an upgrade plan step-by-step with test gates. */
async function executeUpgradePlan(steps, channel, config) {
    const yamlUri = await (0, pubspec_editor_1.findPubspecYaml)();
    const cwd = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!yamlUri || !cwd) {
        return { steps: [], completedCount: 0, failedAt: 'no workspace' };
    }
    const limited = steps.slice(0, config.maxSteps);
    const results = [];
    let failed = false;
    for (const step of limited) {
        if (failed) {
            results.push({ step, outcome: 'skipped', output: '' });
            continue;
        }
        const result = await executeStep(step, yamlUri, cwd, channel, config);
        results.push(result);
        if (result.outcome !== 'success') {
            failed = true;
        }
    }
    const completedCount = results.filter(r => r.outcome === 'success').length;
    const failedStep = results.find(r => r.outcome !== 'success' && r.outcome !== 'skipped');
    return {
        steps: results, completedCount,
        failedAt: failedStep?.step.packageName ?? null,
    };
}
async function executeStep(step, yamlUri, cwd, channel, config) {
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const original = (0, pubspec_editor_1.readVersionConstraint)(doc, step.packageName);
    const newConstraint = `^${step.targetVersion}`;
    channel.appendLine(`\n--- Step ${step.order}: ${step.packageName} `
        + `${step.currentVersion} → ${step.targetVersion} ---`);
    if (!await applyEdit(yamlUri, doc, step.packageName, newConstraint)) {
        return { step, outcome: 'pub-get-failed', output: 'Failed to edit pubspec.yaml' };
    }
    const pubGet = await (0, flutter_cli_1.runPubGet)(cwd);
    channel.appendLine(pubGet.output);
    if (!pubGet.success) {
        await rollbackStep(yamlUri, step.packageName, original, cwd);
        return { step, outcome: 'pub-get-failed', output: pubGet.output };
    }
    if (!config.skipTests) {
        const test = await (0, flutter_cli_1.runFlutterTest)(cwd);
        channel.appendLine(test.output);
        if (!test.success) {
            await rollbackStep(yamlUri, step.packageName, original, cwd);
            return { step, outcome: 'test-failed', output: test.output };
        }
    }
    channel.appendLine(`✅ ${step.packageName} upgraded successfully`);
    if (config.autoCommit) {
        await autoCommitStep(step, cwd, channel);
    }
    return { step, outcome: 'success', output: '' };
}
async function applyEdit(yamlUri, doc, pkgName, constraint) {
    const edit = (0, pubspec_editor_1.buildVersionEdit)(doc, pkgName, constraint);
    if (!edit) {
        return false;
    }
    const wsEdit = new vscode.WorkspaceEdit();
    wsEdit.replace(yamlUri, edit.range, edit.newText);
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();
    return true;
}
async function rollbackStep(yamlUri, pkgName, original, cwd) {
    if (!original) {
        return;
    }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    await applyEdit(yamlUri, doc, pkgName, original);
    await (0, flutter_cli_1.runPubGet)(cwd);
}
async function autoCommitStep(step, cwd, channel) {
    const msg = `upgrade ${step.packageName} ${step.currentVersion} → ${step.targetVersion}`;
    try {
        await gitExec(['add', 'pubspec.yaml', 'pubspec.lock'], cwd);
        await gitExec(['commit', '-m', msg], cwd);
        channel.appendLine(`  committed: ${msg}`);
    }
    catch {
        channel.appendLine(`  auto-commit skipped (git error)`);
    }
}
function gitExec(args, cwd) {
    return new Promise((resolve, reject) => {
        (0, child_process_1.execFile)('git', args, { cwd, timeout: 10_000 }, (err, stdout) => {
            if (err) {
                reject(err);
            }
            else {
                resolve(stdout);
            }
        });
    });
}
/** Format the upgrade plan as a readable string for the output channel. */
function formatUpgradePlan(steps) {
    const lines = [`Upgrade Plan (${steps.length} packages):\n`];
    for (const step of steps) {
        const family = step.familyId ? `  ← family: ${step.familyId}` : '';
        const override = step.mayResolveOverride
            ? `  → may resolve override: ${step.mayResolveOverride}`
            : '';
        lines.push(`  ${step.order}. [${step.updateType}]  `
            + `${step.packageName} ${step.currentVersion} → ${step.targetVersion}`
            + family
            + override);
    }
    lines.push('\nEach step: bump version → pub get → flutter test → next');
    lines.push('Stop on first failure.\n');
    return lines.join('\n');
}
/** Format an upgrade report as a readable summary. */
function formatUpgradeReport(report) {
    const lines = ['Upgrade Results:\n'];
    for (const result of report.steps) {
        const name = result.step.packageName;
        const ver = `${result.step.currentVersion} → ${result.step.targetVersion}`;
        switch (result.outcome) {
            case 'success':
                lines.push(`  ✅ ${name} ${ver}`);
                break;
            case 'pub-get-failed':
                lines.push(`  ❌ ${name} ${ver}\n     └─ pub get failed`);
                break;
            case 'test-failed':
                lines.push(`  ❌ ${name} ${ver}\n     └─ flutter test failed`);
                break;
            case 'skipped':
                lines.push(`  ⏭️ ${name} — skipped`);
                break;
        }
    }
    return lines.join('\n');
}
//# sourceMappingURL=upgrade-executor.js.map