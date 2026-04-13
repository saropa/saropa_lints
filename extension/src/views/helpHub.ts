/**
 * Help hub: single entry point for walkthrough, About, command catalog, and pub.dev.
 *
 * Mirrors the links historically shown only in conditional `viewsWelcome` content,
 * so users can reopen help after the welcome view is hidden (Dart project + data).
 *
 * **Tests:** `HELP_HUB_COMMAND_IDS` and `showHelpHubQuickPick` — see `src/test/views/helpHub.test.ts`.
 */

import * as vscode from 'vscode';

type HelpHubPick = vscode.QuickPickItem & { readonly commandId: string };

const HELP_HUB_SPECS = [
    {
        commandId: 'saropaLints.openWalkthrough',
        label: '$(mortar-board) Getting Started',
        description: 'Guided walkthrough',
    },
    {
        commandId: 'saropaLints.showAbout',
        label: '$(info) About Saropa Lints',
        description: 'Version and documentation',
    },
    {
        commandId: 'saropaLints.showCommandCatalog',
        label: '$(list-flat) Browse All Commands',
        description: 'Searchable command catalog',
    },
    {
        commandId: 'saropaLints.openPubDevSaropaLints',
        label: '$(link-external) Package on pub.dev',
        description: 'saropa_lints',
    },
] as const satisfies readonly HelpHubPick[];

/** Stable command order for unit tests (same order as the quick pick). */
export const HELP_HUB_COMMAND_IDS: readonly string[] = HELP_HUB_SPECS.map((s) => s.commandId);

const HELP_HUB_ITEMS: readonly HelpHubPick[] = HELP_HUB_SPECS;

/** Opens a quick pick; executing a choice runs the corresponding Saropa Lints command. */
export async function showHelpHubQuickPick(): Promise<void> {
    const picked = await vscode.window.showQuickPick([...HELP_HUB_ITEMS], {
        title: 'Saropa Lints — Help',
        placeHolder: 'Choose an option',
    });
    if (picked === undefined) return;
    await vscode.commands.executeCommand(picked.commandId);
}
