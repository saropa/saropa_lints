import * as vscode from 'vscode';
import { execFile } from 'child_process';
import { UpgradeStep, UpgradeStepResult, UpgradeReport } from '../types';
import { runPubGet, runFlutterTest } from './flutter-cli';
import { buildVersionEdit, readVersionConstraint, findPubspecYaml } from './pubspec-editor';

interface ExecutorConfig {
    readonly skipTests: boolean;
    readonly maxSteps: number;
    readonly autoCommit: boolean;
}

/** Execute an upgrade plan step-by-step with test gates. */
export async function executeUpgradePlan(
    steps: readonly UpgradeStep[],
    channel: vscode.OutputChannel,
    config: ExecutorConfig,
): Promise<UpgradeReport> {
    const yamlUri = await findPubspecYaml();
    const cwd = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!yamlUri || !cwd) {
        return { steps: [], completedCount: 0, failedAt: 'no workspace' };
    }

    const limited = steps.slice(0, config.maxSteps);
    const results: UpgradeStepResult[] = [];
    let failed = false;

    for (const step of limited) {
        if (failed) {
            results.push({ step, outcome: 'skipped', output: '' });
            continue;
        }
        const result = await executeStep(
            step, yamlUri, cwd, channel, config,
        );
        results.push(result);
        if (result.outcome !== 'success') { failed = true; }
    }

    const completedCount = results.filter(
        r => r.outcome === 'success',
    ).length;
    const failedStep = results.find(
        r => r.outcome !== 'success' && r.outcome !== 'skipped',
    );
    return {
        steps: results, completedCount,
        failedAt: failedStep?.step.packageName ?? null,
    };
}

async function executeStep(
    step: UpgradeStep,
    yamlUri: vscode.Uri,
    cwd: string,
    channel: vscode.OutputChannel,
    config: ExecutorConfig,
): Promise<UpgradeStepResult> {
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const original = readVersionConstraint(doc, step.packageName);
    const newConstraint = `^${step.targetVersion}`;

    channel.appendLine(
        `\n--- Step ${step.order}: ${step.packageName} `
        + `${step.currentVersion} → ${step.targetVersion} ---`,
    );

    if (!await applyEdit(yamlUri, doc, step.packageName, newConstraint)) {
        return { step, outcome: 'pub-get-failed', output: 'Failed to edit pubspec.yaml' };
    }

    const pubGet = await runPubGet(cwd);
    channel.appendLine(pubGet.output);
    if (!pubGet.success) {
        await rollbackStep(yamlUri, step.packageName, original, cwd);
        return { step, outcome: 'pub-get-failed', output: pubGet.output };
    }

    if (!config.skipTests) {
        const test = await runFlutterTest(cwd);
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

async function applyEdit(
    yamlUri: vscode.Uri,
    doc: vscode.TextDocument,
    pkgName: string,
    constraint: string,
): Promise<boolean> {
    const edit = buildVersionEdit(doc, pkgName, constraint);
    if (!edit) { return false; }
    const wsEdit = new vscode.WorkspaceEdit();
    wsEdit.replace(yamlUri, edit.range, edit.newText);
    await vscode.workspace.applyEdit(wsEdit);
    await doc.save();
    return true;
}

async function rollbackStep(
    yamlUri: vscode.Uri,
    pkgName: string,
    original: string | null,
    cwd: string,
): Promise<void> {
    if (!original) { return; }
    const doc = await vscode.workspace.openTextDocument(yamlUri);
    await applyEdit(yamlUri, doc, pkgName, original);
    await runPubGet(cwd);
}

async function autoCommitStep(
    step: UpgradeStep,
    cwd: string,
    channel: vscode.OutputChannel,
): Promise<void> {
    const msg = `upgrade ${step.packageName} ${step.currentVersion} → ${step.targetVersion}`;
    try {
        await gitExec(['add', 'pubspec.yaml', 'pubspec.lock'], cwd);
        await gitExec(['commit', '-m', msg], cwd);
        channel.appendLine(`  committed: ${msg}`);
    } catch {
        channel.appendLine(`  auto-commit skipped (git error)`);
    }
}

function gitExec(args: string[], cwd: string): Promise<string> {
    return new Promise((resolve, reject) => {
        execFile('git', args, { cwd, timeout: 10_000 }, (err, stdout) => {
            if (err) { reject(err); } else { resolve(stdout); }
        });
    });
}

/** Format the upgrade plan as a readable string for the output channel. */
export function formatUpgradePlan(
    steps: readonly UpgradeStep[],
): string {
    const lines = [`Upgrade Plan (${steps.length} packages):\n`];
    for (const step of steps) {
        const family = step.familyId ? `  ← family: ${step.familyId}` : '';
        const override = step.mayResolveOverride
            ? `  → may resolve override: ${step.mayResolveOverride}`
            : '';
        lines.push(
            `  ${step.order}. [${step.updateType}]  `
            + `${step.packageName} ${step.currentVersion} → ${step.targetVersion}`
            + family
            + override,
        );
    }
    lines.push('\nEach step: bump version → pub get → flutter test → next');
    lines.push('Stop on first failure.\n');
    return lines.join('\n');
}

/** Format an upgrade report as a readable summary. */
export function formatUpgradeReport(
    report: UpgradeReport,
): string {
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
