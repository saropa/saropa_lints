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
exports.SaveTaskRunner = void 0;
const vscode = __importStar(require("vscode"));
const dependency_differ_1 = require("./dependency-differ");
const DEBOUNCE_MS = 300;
const STATUS_DISPLAY_MS = 3000;
const TASK_TIMEOUT_MS = 300000; // 5 minutes max for VS Code tasks
const TASK_PREFIX = 'task:';
class SaveTaskRunner {
    _contentCache = new Map();
    _debounceTimers = new Map();
    _disposables = [];
    _statusItem = null;
    _statusTimeout = null;
    _isRunning = false;
    _outputChannel = null;
    constructor() {
        this._disposables.push(vscode.workspace.onDidSaveTextDocument(doc => this._onDocumentSaved(doc)));
        this._disposables.push(vscode.workspace.onDidOpenTextDocument(doc => this._cacheIfPubspec(doc)));
        for (const doc of vscode.workspace.textDocuments) {
            this._cacheIfPubspec(doc);
        }
    }
    _getConfig() {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        return {
            command: config.get('onSaveChanges', ''),
            detection: config.get('onSaveChangesDetection', 'dependencies'),
        };
    }
    _cacheIfPubspec(doc) {
        if (!this._isPubspec(doc)) {
            return;
        }
        const key = doc.uri.toString();
        if (!this._contentCache.has(key)) {
            this._contentCache.set(key, doc.getText());
        }
    }
    _isPubspec(doc) {
        return doc.fileName.endsWith('pubspec.yaml');
    }
    _onDocumentSaved(doc) {
        if (!this._isPubspec(doc)) {
            return;
        }
        const config = this._getConfig();
        if (!config.command) {
            return;
        }
        const key = doc.uri.toString();
        const existingTimer = this._debounceTimers.get(key);
        if (existingTimer) {
            clearTimeout(existingTimer);
        }
        const timer = setTimeout(() => {
            this._debounceTimers.delete(key);
            void this._processDocumentSave(doc, config);
        }, DEBOUNCE_MS);
        this._debounceTimers.set(key, timer);
    }
    async _processDocumentSave(doc, config) {
        const key = doc.uri.toString();
        const newContent = doc.getText();
        const oldContent = this._contentCache.get(key) ?? '';
        this._contentCache.set(key, newContent);
        if (config.detection === 'dependencies') {
            if (!(0, dependency_differ_1.hasDependencyChanges)(oldContent, newContent)) {
                return;
            }
            const summary = (0, dependency_differ_1.getDependencyChangeSummary)(oldContent, newContent);
            this._logChange(doc, summary);
        }
        await this._runTask(config.command, doc.uri);
    }
    _logChange(doc, summary) {
        const parts = [];
        if (summary.added.length > 0) {
            parts.push(`+${summary.added.join(', ')}`);
        }
        if (summary.removed.length > 0) {
            parts.push(`-${summary.removed.join(', ')}`);
        }
        if (summary.changed.length > 0) {
            parts.push(`~${summary.changed.join(', ')}`);
        }
        if (parts.length > 0) {
            this._getOutputChannel().appendLine(`[SaveTask] ${doc.fileName}: ${parts.join(' ')}`);
        }
    }
    _getOutputChannel() {
        if (!this._outputChannel) {
            this._outputChannel = vscode.window.createOutputChannel('Saropa: Save Tasks');
        }
        return this._outputChannel;
    }
    async _runTask(command, fileUri) {
        if (this._isRunning) {
            return;
        }
        this._isRunning = true;
        const workspaceFolder = vscode.workspace.getWorkspaceFolder(fileUri);
        const cwd = workspaceFolder?.uri.fsPath
            ?? vscode.Uri.joinPath(fileUri, '..').fsPath;
        try {
            this._showStatus('running', command);
            if (command.startsWith(TASK_PREFIX)) {
                await this._runVscodeTask(command.slice(TASK_PREFIX.length));
            }
            else {
                await this._runShellCommand(command, cwd);
            }
            this._showStatus('success', command);
        }
        catch (error) {
            this._showStatus('error', command);
            const message = error instanceof Error ? error.message : String(error);
            this._getOutputChannel().appendLine(`[SaveTask] Error: ${message}`);
            vscode.window.showErrorMessage(`Save task failed: ${message}`);
        }
        finally {
            this._isRunning = false;
        }
    }
    async _runVscodeTask(taskName) {
        const tasks = await vscode.tasks.fetchTasks();
        const task = tasks.find(t => t.name === taskName);
        if (!task) {
            throw new Error(`Task "${taskName}" not found`);
        }
        const execution = await vscode.tasks.executeTask(task);
        await new Promise((resolve, reject) => {
            const timeoutId = setTimeout(() => {
                disposable.dispose();
                reject(new Error(`Task "${taskName}" timed out after 5 minutes`));
            }, TASK_TIMEOUT_MS);
            const disposable = vscode.tasks.onDidEndTaskProcess(e => {
                if (e.execution === execution) {
                    clearTimeout(timeoutId);
                    disposable.dispose();
                    if (e.exitCode === 0) {
                        resolve();
                    }
                    else {
                        reject(new Error(`Task exited with code ${e.exitCode}`));
                    }
                }
            });
        });
    }
    async _runShellCommand(command, cwd) {
        const terminal = vscode.window.createTerminal({
            name: 'Saropa: Save Task',
            cwd,
            hideFromUser: false,
        });
        terminal.sendText(command);
        terminal.show(true);
        await new Promise(resolve => setTimeout(resolve, 500));
    }
    _showStatus(state, command) {
        if (!this._statusItem) {
            this._statusItem = vscode.window.createStatusBarItem('saropaLints.packageVibrancy.saveTask', vscode.StatusBarAlignment.Left, 100);
            this._statusItem.name = 'Save Task';
        }
        if (this._statusTimeout) {
            clearTimeout(this._statusTimeout);
            this._statusTimeout = null;
        }
        const shortCommand = this._truncateCommand(command);
        switch (state) {
            case 'running':
                this._statusItem.text = `$(sync~spin) ${shortCommand}...`;
                this._statusItem.backgroundColor = undefined;
                this._statusItem.show();
                break;
            case 'success':
                this._statusItem.text = `$(check) ${shortCommand}`;
                this._statusItem.backgroundColor = undefined;
                this._statusItem.show();
                this._scheduleHide();
                break;
            case 'error':
                this._statusItem.text = `$(error) ${shortCommand} failed`;
                this._statusItem.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
                this._statusItem.show();
                this._scheduleHide();
                break;
        }
    }
    _truncateCommand(command) {
        const short = command.startsWith(TASK_PREFIX)
            ? command.slice(TASK_PREFIX.length)
            : command.split(' ')[0];
        return short.length > 20 ? short.slice(0, 17) + '...' : short;
    }
    _scheduleHide() {
        this._statusTimeout = setTimeout(() => {
            this._statusItem?.hide();
            this._statusTimeout = null;
        }, STATUS_DISPLAY_MS);
    }
    dispose() {
        for (const timer of Array.from(this._debounceTimers.values())) {
            clearTimeout(timer);
        }
        this._debounceTimers.clear();
        if (this._statusTimeout) {
            clearTimeout(this._statusTimeout);
        }
        this._statusItem?.dispose();
        this._outputChannel?.dispose();
        for (const d of this._disposables) {
            d.dispose();
        }
    }
}
exports.SaveTaskRunner = SaveTaskRunner;
//# sourceMappingURL=save-task-runner.js.map