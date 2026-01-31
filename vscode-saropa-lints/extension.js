const vscode = require('vscode');

let statusBarItem;
let outputChannel;

/**
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
    outputChannel = vscode.window.createOutputChannel('Saropa Lints');

    // Register commands
    const runCommand = vscode.commands.registerCommand('saropa-lints.run', runLints);
    const scanCommand = vscode.commands.registerCommand('saropa-lints.scanPath', scanPath);
    context.subscriptions.push(runCommand, scanCommand);

    // Create status bar item
    statusBarItem = vscode.window.createStatusBarItem(
        vscode.StatusBarAlignment.Right,
        100
    );
    statusBarItem.command = 'saropa-lints.run';
    statusBarItem.text = '$(search) Lints';
    statusBarItem.tooltip = 'Run Saropa Lints (Ctrl+Shift+B)';
    context.subscriptions.push(statusBarItem);

    // Show status bar when a Dart file is open
    context.subscriptions.push(
        vscode.window.onDidChangeActiveTextEditor(updateStatusBarVisibility)
    );
    updateStatusBarVisibility();
}

function updateStatusBarVisibility() {
    const editor = vscode.window.activeTextEditor;
    if (editor && editor.document.languageId === 'dart') {
        statusBarItem.show();
    } else {
        // Still show it if we're in a Flutter/Dart project
        const workspaceFolders = vscode.workspace.workspaceFolders;
        if (workspaceFolders) {
            statusBarItem.show();
        } else {
            statusBarItem.hide();
        }
    }
}

/**
 * Scans a file or folder for diagnostics from the analysis server.
 * @param {vscode.Uri} uri - The file or folder URI from the explorer context menu.
 */
async function scanPath(uri) {
    if (!uri) {
        vscode.window.showErrorMessage('No file or folder selected');
        return;
    }

    try {
        const stat = await vscode.workspace.fs.stat(uri);
        const isFolder = stat.type === vscode.FileType.Directory;
        const targetPath = uri.fsPath.toLowerCase();

        const allDiagnostics = vscode.languages.getDiagnostics();
        const matched = allDiagnostics.filter(([fileUri]) => {
            const filePath = fileUri.fsPath.toLowerCase();
            return isFolder ? filePath.startsWith(targetPath) : filePath === targetPath;
        });

        outputChannel.clear();
        outputChannel.show(true);
        formatScanResults(uri.fsPath, isFolder, matched);
    } catch (error) {
        vscode.window.showErrorMessage(`Scan failed: ${error.message}`);
    }
}

/**
 * Formats and displays scan results in the output channel.
 * @param {string} targetPath - Display path for the header.
 * @param {boolean} isFolder - Whether the target is a folder.
 * @param {[vscode.Uri, vscode.Diagnostic[]][]} matched - Filtered diagnostics.
 */
function formatScanResults(targetPath, isFolder, matched) {
    const severityLabel = ['ERROR', 'WARNING', 'INFO', 'HINT'];
    let errors = 0, warnings = 0, infos = 0;

    for (const [, diagnostics] of matched) {
        for (const d of diagnostics) {
            if (d.severity === 0) errors++;
            else if (d.severity === 1) warnings++;
            else infos++;
        }
    }

    const total = errors + warnings + infos;
    const label = isFolder ? 'Folder' : 'File';

    outputChannel.appendLine('Saropa Lints \u2014 Scan Results');
    outputChannel.appendLine(`${label}: ${targetPath}`);
    outputChannel.appendLine('\u2500'.repeat(50));
    outputChannel.appendLine(`${errors} errors, ${warnings} warnings, ${infos} info`);
    outputChannel.appendLine('');

    if (total === 0) {
        outputChannel.appendLine('No issues found.');
        vscode.window.showInformationMessage('Saropa Lints: No issues found.');
        return;
    }

    for (const [fileUri, diagnostics] of matched) {
        if (diagnostics.length === 0) continue;
        const fileName = fileUri.fsPath.split(/[\\/]/).pop();
        outputChannel.appendLine(`${fileName} (${diagnostics.length} issues)`);
        for (const d of diagnostics) {
            const line = d.range.start.line + 1;
            const sev = severityLabel[d.severity] || 'INFO';
            outputChannel.appendLine(`  Line ${line}: [${sev}] ${d.message.split('\n')[0]}`);
        }
        outputChannel.appendLine('');
    }

    vscode.window.showInformationMessage(`Saropa Lints: ${total} issue(s) found.`);
}

async function runLints() {
    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders || workspaceFolders.length === 0) {
        vscode.window.showErrorMessage('No workspace folder open');
        return;
    }

    // Update status bar to show running state
    statusBarItem.text = '$(sync~spin) Linting...';

    try {
        // Try to run the existing task first
        const tasks = await vscode.tasks.fetchTasks();
        const lintTask = tasks.find(t =>
            t.name === 'Run Saropa Lints' ||
            t.name === 'custom_lint'
        );

        if (lintTask) {
            await vscode.tasks.executeTask(lintTask);
        } else {
            // Fallback: create and run a shell task
            const task = new vscode.Task(
                { type: 'shell' },
                workspaceFolders[0],
                'Run Saropa Lints',
                'saropa',
                new vscode.ShellExecution('dart run custom_lint'),
                '$custom_lint'
            );
            task.presentationOptions = {
                reveal: vscode.TaskRevealKind.Always,
                panel: vscode.TaskPanelKind.Dedicated,
                clear: true
            };
            await vscode.tasks.executeTask(task);
        }

        // Show problems panel
        vscode.commands.executeCommand('workbench.actions.view.problems');
    } catch (error) {
        vscode.window.showErrorMessage(`Failed to run lints: ${error.message}`);
    }

    // Reset status bar after a delay (task runs asynchronously)
    setTimeout(() => {
        statusBarItem.text = '$(search) Lints';
    }, 2000);
}

function deactivate() {
    if (outputChannel) {
        outputChannel.dispose();
    }
}

module.exports = {
    activate,
    deactivate
};
