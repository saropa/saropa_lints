"use strict";
/**
 * Setup and run commands: add saropa_lints to pubspec, pub get, init, analyze.
 * Replaces the init process from the user's perspective.
 */
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
exports.TIER_ORDER = void 0;
exports.runEnable = runEnable;
exports.runDisable = runDisable;
exports.runAnalysis = runAnalysis;
exports.runInitializeConfig = runInitializeConfig;
exports.openConfig = openConfig;
exports.runRepairConfig = runRepairConfig;
exports.runSetTier = runSetTier;
exports.showOutputChannel = showOutputChannel;
const vscode = __importStar(require("vscode"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const child_process_1 = require("child_process");
const reportWriter_1 = require("./reportWriter");
const projectRoot_1 = require("./projectRoot");
const SAROPA_LINTS_DEV_DEP = 'saropa_lints';
const DEFAULT_VERSION = '^9.1.0';
const OUTPUT_CHANNEL_NAME = 'Saropa Lints';
// Lazily-initialized singleton to avoid creating multiple channel objects.
let _outputChannel;
function getOutputChannel() {
    if (!_outputChannel)
        _outputChannel = vscode.window.createOutputChannel(OUTPUT_CHANNEL_NAME);
    return _outputChannel;
}
function hasFlutterDep(pubspecPath) {
    try {
        const content = fs.readFileSync(pubspecPath, 'utf-8');
        return /flutter:\s*$/m.test(content) || content.includes('sdk: flutter');
    }
    catch {
        return false;
    }
}
function ensureSaropaLintsInPubspec(workspaceRoot) {
    const pubspecPath = path.join(workspaceRoot, 'pubspec.yaml');
    if (!fs.existsSync(pubspecPath)) {
        void vscode.window.showErrorMessage('Saropa Lints requires a Dart or Flutter project (no pubspec.yaml found).', 'Learn More').then((choice) => {
            if (choice === 'Learn More') {
                void vscode.env.openExternal(vscode.Uri.parse('https://pub.dev/packages/saropa_lints'));
            }
        });
        return false;
    }
    const content = fs.readFileSync(pubspecPath, 'utf-8');
    // Precision check: match as an actual dependency entry, not a substring
    // in comments or similarly-named packages like saropa_lints_extra.
    if (/^\s{2}saropa_lints\s*:/m.test(content))
        return true;
    // Line-based insertion avoids regex backtracking bugs that corrupted YAML
    // by placing the dependency on the same line as dev_dependencies:.
    // Preserve original line endings (CRLF on Windows) to avoid git noise.
    const eol = content.includes('\r\n') ? '\r\n' : '\n';
    const lines = content.split(eol);
    const devDepsIdx = lines.findIndex(l => /^dev_dependencies:\s*$/.test(l));
    const entry = `  ${SAROPA_LINTS_DEV_DEP}: ${DEFAULT_VERSION}`;
    if (devDepsIdx !== -1) {
        lines.splice(devDepsIdx + 1, 0, entry);
    }
    else {
        lines.push('', 'dev_dependencies:', entry);
    }
    fs.writeFileSync(pubspecPath, lines.join(eol), 'utf-8');
    return true;
}
/** Builds args for non-interactive init (Enable, Initialize config, Set tier). */
function buildInitArgs(workspaceRoot, tier) {
    return [
        'run',
        'saropa_lints:init',
        '--tier',
        tier,
        '--no-stylistic',
        '--target',
        workspaceRoot,
    ];
}
function runInWorkspace(workspaceRoot, command, args, logToOutput = true) {
    if (logToOutput) {
        const ch = getOutputChannel();
        ch.appendLine(`$ ${command} ${args.join(' ')}`);
    }
    const result = (0, child_process_1.spawnSync)(command, args, {
        cwd: workspaceRoot,
        encoding: 'utf-8',
        shell: true,
    });
    const stdout = (result.stdout ?? '');
    const stderr = (result.stderr || result.error?.message || '');
    if (logToOutput) {
        const ch = getOutputChannel();
        if (stdout)
            ch.appendLine(stdout);
        if (stderr)
            ch.appendLine(stderr);
    }
    return {
        ok: result.status === 0,
        stderr,
        stdout,
    };
}
async function runEnable(context) {
    const workspaceRoot = (0, projectRoot_1.getProjectRoot)();
    if (!workspaceRoot) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return false;
    }
    let success = false;
    await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: 'Enabling Saropa Lints',
        cancellable: false,
    }, async () => {
        (0, reportWriter_1.logSection)('Enable');
        if (!ensureSaropaLintsInPubspec(workspaceRoot))
            return;
        (0, reportWriter_1.logReport)('- Added saropa_lints to pubspec.yaml');
        const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
        const pubCmd = useFlutter ? 'flutter' : 'dart';
        const { ok: pubOk, stderr: pubErr } = runInWorkspace(workspaceRoot, pubCmd, ['pub', 'get']);
        if (!pubOk) {
            (0, reportWriter_1.logReport)(`- pub get FAILED: ${pubErr || '(no details)'}`);
            (0, reportWriter_1.flushReport)(workspaceRoot);
            vscode.window.showErrorMessage(`Saropa Lints: pub get failed. ${pubErr || 'Check Output.'}`);
            return;
        }
        (0, reportWriter_1.logReport)(`- Ran pub get (${pubCmd})`);
        // Verify saropa_lints was actually resolved — corrupted pubspec YAML
        // can cause pub get to exit 0 without resolving the package.
        const pkgConfigPath = path.join(workspaceRoot, '.dart_tool', 'package_config.json');
        if (!fs.existsSync(pkgConfigPath) || !fs.readFileSync(pkgConfigPath, 'utf-8').includes('"saropa_lints"')) {
            (0, reportWriter_1.logReport)('- saropa_lints not found in package_config.json after pub get');
            (0, reportWriter_1.flushReport)(workspaceRoot);
            vscode.window.showErrorMessage('Saropa Lints: pub get succeeded but saropa_lints was not resolved. Check pubspec.yaml formatting.');
            return;
        }
        const cfg = vscode.workspace.getConfiguration('saropaLints');
        const tier = (cfg.get('tier') ?? 'recommended').trim();
        const { ok: initOk, stderr: initErr } = runInWorkspace(workspaceRoot, 'dart', buildInitArgs(workspaceRoot, tier));
        if (!initOk) {
            (0, reportWriter_1.logReport)(`- init FAILED: ${initErr || '(no details)'}`);
            (0, reportWriter_1.flushReport)(workspaceRoot);
            vscode.window.showErrorMessage(`Saropa Lints: init failed. ${initErr || 'Check Output.'}`);
            return;
        }
        (0, reportWriter_1.logReport)(`- Ran init --tier ${tier} --no-stylistic`);
        const runAnalysisAfter = cfg.get('runAnalysisAfterConfigChange', true);
        if (runAnalysisAfter) {
            const analyzeCmd = useFlutter ? 'flutter' : 'dart';
            runInWorkspace(workspaceRoot, analyzeCmd, ['analyze']);
            (0, reportWriter_1.logReport)('- Ran analysis');
        }
        success = true;
        (0, reportWriter_1.flushReport)(workspaceRoot);
    });
    // I5: Notification moved to extension.ts enable handler where health score is available.
    return success;
}
async function runDisable() {
    await vscode.workspace.getConfiguration('saropaLints').update('enabled', false, vscode.ConfigurationTarget.Workspace);
    vscode.window.showInformationMessage('Saropa Lints is disabled. Project files were not changed.');
}
async function runAnalysis(context) {
    const workspaceRoot = (0, projectRoot_1.getProjectRoot)();
    if (!workspaceRoot) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return false;
    }
    const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
    const cmd = useFlutter ? 'flutter' : 'dart';
    let ok = false;
    await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: 'Running analysis',
        cancellable: false,
    }, async () => {
        (0, reportWriter_1.logSection)('Analysis');
        const result = runInWorkspace(workspaceRoot, cmd, ['analyze']);
        ok = result.ok;
        if (!ok) {
            (0, reportWriter_1.logReport)(`- Analysis reported issues (${cmd} analyze)`);
            vscode.window.showWarningMessage(`Analysis reported issues. ${result.stderr ? result.stderr.slice(0, 200) : 'See Problems view.'}`);
        }
        else {
            (0, reportWriter_1.logReport)('- Analysis completed clean');
        }
        (0, reportWriter_1.flushReport)(workspaceRoot);
    });
    return ok;
}
async function runInitializeConfig(context, title) {
    const workspaceRoot = (0, projectRoot_1.getProjectRoot)();
    if (!workspaceRoot) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return false;
    }
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const tier = (cfg.get('tier') ?? 'recommended').trim();
    let ok = false;
    await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: title ?? 'Initializing Saropa Lints config',
        cancellable: false,
    }, async () => {
        (0, reportWriter_1.logSection)('Initialize Config');
        const result = runInWorkspace(workspaceRoot, 'dart', buildInitArgs(workspaceRoot, tier));
        ok = result.ok;
        if (!ok) {
            (0, reportWriter_1.logReport)(`- Init FAILED: ${result.stderr || '(no details)'}`);
            (0, reportWriter_1.flushReport)(workspaceRoot);
            vscode.window.showErrorMessage(`Init failed. ${result.stderr || 'Check Output.'}`);
        }
        else {
            (0, reportWriter_1.logReport)(`- Config initialized (tier: ${tier})`);
            (0, reportWriter_1.flushReport)(workspaceRoot);
            vscode.window.showInformationMessage(`Saropa Lints config updated (tier: ${tier}).`);
        }
    });
    return ok;
}
async function openConfig() {
    const workspaceRoot = (0, projectRoot_1.getProjectRoot)();
    if (!workspaceRoot)
        return;
    const customPath = path.join(workspaceRoot, 'analysis_options_custom.yaml');
    const uri = fs.existsSync(customPath)
        ? vscode.Uri.file(customPath)
        : vscode.Uri.file(path.join(workspaceRoot, 'analysis_options.yaml'));
    const doc = await vscode.workspace.openTextDocument(uri);
    await vscode.window.showTextDocument(doc);
}
async function runRepairConfig(context) {
    return runInitializeConfig(context);
}
/** Tier metadata for the picker — labels, cumulative rule counts, short descriptions. */
const TIER_INFO = [
    { id: 'essential', label: 'Essential', rules: 297, desc: 'Security and critical issues only' },
    { id: 'recommended', label: 'Recommended', rules: 895, desc: 'Best practices for most projects' },
    { id: 'professional', label: 'Professional', rules: 1834, desc: 'Comprehensive coverage for teams' },
    { id: 'comprehensive', label: 'Comprehensive', rules: 1959, desc: 'Thorough analysis with minor rules' },
    { id: 'pedantic', label: 'Pedantic', rules: 1984, desc: 'Every rule enabled' },
];
/** Ordered tier IDs for upgrade/downgrade comparison. Exported for use in extension.ts. */
exports.TIER_ORDER = TIER_INFO.map(t => t.id);
/** Look up the capitalized label for a tier id (e.g. 'recommended' → 'Recommended'). */
function tierLabel(id) {
    return TIER_INFO.find(t => t.id === id)?.label ?? id;
}
/** Run init + optional analysis for a tier change; returns true on success. */
function applyTierChange(workspaceRoot, tier, previousTier) {
    (0, reportWriter_1.logSection)('Set Tier');
    (0, reportWriter_1.logReport)(`- Changed tier: ${previousTier} → ${tier}`);
    const initResult = runInWorkspace(workspaceRoot, 'dart', buildInitArgs(workspaceRoot, tier));
    if (!initResult.ok) {
        (0, reportWriter_1.logReport)(`- Init FAILED: ${initResult.stderr || '(no details)'}`);
        (0, reportWriter_1.flushReport)(workspaceRoot);
        vscode.window.showErrorMessage(`Init failed. ${initResult.stderr || 'Check Output.'}`);
        return false;
    }
    (0, reportWriter_1.logReport)(`- Ran init --tier ${tier} --no-stylistic`);
    // C6: Re-analyze after tier change so violations.json reflects the new ruleset.
    const runAnalysisAfter = vscode.workspace.getConfiguration('saropaLints')
        .get('runAnalysisAfterConfigChange', true);
    if (runAnalysisAfter) {
        const useFlutter = hasFlutterDep(path.join(workspaceRoot, 'pubspec.yaml'));
        const analyzeCmd = useFlutter ? 'flutter' : 'dart';
        const analyzeResult = runInWorkspace(workspaceRoot, analyzeCmd, ['analyze']);
        // Log whether analysis succeeded — a non-zero exit is expected when violations exist.
        (0, reportWriter_1.logReport)(analyzeResult.ok ? '- Analysis completed' : '- Analysis reported issues');
    }
    (0, reportWriter_1.flushReport)(workspaceRoot);
    return true;
}
/**
 * Show an enhanced tier picker and run init + analysis for the selected tier.
 * Returns the new and previous tier on success, or null on cancel/failure/same-tier.
 */
async function runSetTier(context) {
    const previousTier = (vscode.workspace.getConfiguration('saropaLints').get('tier') ?? 'recommended').trim();
    const items = TIER_INFO.map(t => ({
        label: t.id === previousTier ? `$(check) ${t.label}` : t.label,
        description: `${t.rules} rules${t.id === previousTier ? ' (current)' : ''}`,
        detail: t.desc,
        id: t.id,
    }));
    const pick = await vscode.window.showQuickPick(items, {
        placeHolder: `Current: ${tierLabel(previousTier)}`,
        title: 'Saropa Lints: Set tier',
    });
    if (!pick)
        return null;
    const tier = pick.id;
    // Same-tier guard — no-op, skip the expensive init + analysis cycle.
    if (tier === previousTier) {
        void vscode.window.showInformationMessage(`Already on ${tierLabel(tier)} tier.`);
        return null;
    }
    const workspaceRoot = (0, projectRoot_1.getProjectRoot)();
    if (!workspaceRoot) {
        vscode.window.showErrorMessage('No workspace folder open.');
        return null;
    }
    await vscode.workspace.getConfiguration('saropaLints').update('tier', tier, vscode.ConfigurationTarget.Workspace);
    let ok = false;
    await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: `Updating tier to ${tierLabel(tier)}`,
        cancellable: false,
    }, 
    // Smart notification is shown by the handler in extension.ts after we return.
    async () => { ok = applyTierChange(workspaceRoot, tier, previousTier); });
    return ok ? { tier, tierLabel: tierLabel(tier), previousTier } : null;
}
function showOutputChannel() {
    getOutputChannel().show();
}
//# sourceMappingURL=setup.js.map