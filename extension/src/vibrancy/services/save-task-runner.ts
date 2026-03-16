import * as vscode from 'vscode';
import { hasDependencyChanges, getDependencyChangeSummary } from './dependency-differ';

export type DetectionMode = 'any' | 'dependencies';

export interface SaveTaskConfig {
    readonly command: string;
    readonly detection: DetectionMode;
}

const DEBOUNCE_MS = 300;
const STATUS_DISPLAY_MS = 3000;
const TASK_TIMEOUT_MS = 300000; // 5 minutes max for VS Code tasks
const TASK_PREFIX = 'task:';

export class SaveTaskRunner implements vscode.Disposable {
    private readonly _contentCache = new Map<string, string>();
    private readonly _debounceTimers = new Map<string, ReturnType<typeof setTimeout>>();
    private readonly _disposables: vscode.Disposable[] = [];
    private _statusItem: vscode.StatusBarItem | null = null;
    private _statusTimeout: ReturnType<typeof setTimeout> | null = null;
    private _isRunning = false;
    private _outputChannel: vscode.OutputChannel | null = null;

    constructor() {
        this._disposables.push(
            vscode.workspace.onDidSaveTextDocument(doc => this._onDocumentSaved(doc)),
        );

        this._disposables.push(
            vscode.workspace.onDidOpenTextDocument(doc => this._cacheIfPubspec(doc)),
        );

        for (const doc of vscode.workspace.textDocuments) {
            this._cacheIfPubspec(doc);
        }
    }

    private _getConfig(): SaveTaskConfig {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        return {
            command: config.get<string>('onSaveChanges', ''),
            detection: config.get<DetectionMode>('onSaveChangesDetection', 'dependencies'),
        };
    }

    private _cacheIfPubspec(doc: vscode.TextDocument): void {
        if (!this._isPubspec(doc)) { return; }
        const key = doc.uri.toString();
        if (!this._contentCache.has(key)) {
            this._contentCache.set(key, doc.getText());
        }
    }

    private _isPubspec(doc: vscode.TextDocument): boolean {
        return doc.fileName.endsWith('pubspec.yaml');
    }

    private _onDocumentSaved(doc: vscode.TextDocument): void {
        if (!this._isPubspec(doc)) { return; }

        const config = this._getConfig();
        if (!config.command) { return; }

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

    private async _processDocumentSave(
        doc: vscode.TextDocument,
        config: SaveTaskConfig,
    ): Promise<void> {
        const key = doc.uri.toString();
        const newContent = doc.getText();
        const oldContent = this._contentCache.get(key) ?? '';

        this._contentCache.set(key, newContent);

        if (config.detection === 'dependencies') {
            if (!hasDependencyChanges(oldContent, newContent)) {
                return;
            }

            const summary = getDependencyChangeSummary(oldContent, newContent);
            this._logChange(doc, summary);
        }

        await this._runTask(config.command, doc.uri);
    }

    private _logChange(
        doc: vscode.TextDocument,
        summary: { added: string[]; removed: string[]; changed: string[] },
    ): void {
        const parts: string[] = [];
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
            this._getOutputChannel().appendLine(
                `[SaveTask] ${doc.fileName}: ${parts.join(' ')}`,
            );
        }
    }

    private _getOutputChannel(): vscode.OutputChannel {
        if (!this._outputChannel) {
            this._outputChannel = vscode.window.createOutputChannel('Saropa: Save Tasks');
        }
        return this._outputChannel;
    }

    private async _runTask(command: string, fileUri: vscode.Uri): Promise<void> {
        if (this._isRunning) { return; }
        this._isRunning = true;

        const workspaceFolder = vscode.workspace.getWorkspaceFolder(fileUri);
        const cwd = workspaceFolder?.uri.fsPath
            ?? vscode.Uri.joinPath(fileUri, '..').fsPath;

        try {
            this._showStatus('running', command);

            if (command.startsWith(TASK_PREFIX)) {
                await this._runVscodeTask(command.slice(TASK_PREFIX.length));
            } else {
                await this._runShellCommand(command, cwd);
            }

            this._showStatus('success', command);
        } catch (error) {
            this._showStatus('error', command);
            const message = error instanceof Error ? error.message : String(error);
            this._getOutputChannel().appendLine(`[SaveTask] Error: ${message}`);
            vscode.window.showErrorMessage(`Save task failed: ${message}`);
        } finally {
            this._isRunning = false;
        }
    }

    private async _runVscodeTask(taskName: string): Promise<void> {
        const tasks = await vscode.tasks.fetchTasks();
        const task = tasks.find(t => t.name === taskName);

        if (!task) {
            throw new Error(`Task "${taskName}" not found`);
        }

        const execution = await vscode.tasks.executeTask(task);

        await new Promise<void>((resolve, reject) => {
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
                    } else {
                        reject(new Error(`Task exited with code ${e.exitCode}`));
                    }
                }
            });
        });
    }

    private async _runShellCommand(command: string, cwd: string): Promise<void> {
        const terminal = vscode.window.createTerminal({
            name: 'Saropa: Save Task',
            cwd,
            hideFromUser: false,
        });

        terminal.sendText(command);
        terminal.show(true);

        await new Promise<void>(resolve => setTimeout(resolve, 500));
    }

    private _showStatus(
        state: 'running' | 'success' | 'error',
        command: string,
    ): void {
        if (!this._statusItem) {
            this._statusItem = vscode.window.createStatusBarItem(
                'saropaLints.packageVibrancy.saveTask',
                vscode.StatusBarAlignment.Left,
                100,
            );
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
                this._statusItem.backgroundColor = new vscode.ThemeColor(
                    'statusBarItem.errorBackground',
                );
                this._statusItem.show();
                this._scheduleHide();
                break;
        }
    }

    private _truncateCommand(command: string): string {
        const short = command.startsWith(TASK_PREFIX)
            ? command.slice(TASK_PREFIX.length)
            : command.split(' ')[0];
        return short.length > 20 ? short.slice(0, 17) + '...' : short;
    }

    private _scheduleHide(): void {
        this._statusTimeout = setTimeout(() => {
            this._statusItem?.hide();
            this._statusTimeout = null;
        }, STATUS_DISPLAY_MS);
    }

    dispose(): void {
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
