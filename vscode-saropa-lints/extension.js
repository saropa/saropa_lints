const vscode = require('vscode');

let statusBarItem;
let outputChannel;

/**
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
    outputChannel = vscode.window.createOutputChannel('Saropa Lints');

    // Register the run command
    const runCommand = vscode.commands.registerCommand('saropa-lints.run', runLints);
    context.subscriptions.push(runCommand);

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
