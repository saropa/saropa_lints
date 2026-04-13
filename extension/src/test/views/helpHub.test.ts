/**
 * Help hub: quick pick wiring and stable command-id list (regression vs. package.json targets).
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';
import * as vscode from 'vscode';
import { HELP_HUB_COMMAND_IDS, showHelpHubQuickPick } from '../../views/helpHub';
import { resetMocks, setQuickPickNextResult } from '../vibrancy/vscode-mock';

describe('helpHub', () => {
    afterEach(() => {
        sinon.restore();
        resetMocks();
    });

    it('HELP_HUB_COMMAND_IDS lists four unique Saropa commands (before/after: hub surface)', () => {
        assert.strictEqual(HELP_HUB_COMMAND_IDS.length, 4);
        assert.strictEqual(new Set(HELP_HUB_COMMAND_IDS).size, 4);
        for (const id of HELP_HUB_COMMAND_IDS) {
            assert.ok(id.startsWith('saropaLints.'), id);
        }
    });

    it('showHelpHubQuickPick does not execute when the user dismisses the pick', async () => {
        const exec = sinon.stub(vscode.commands, 'executeCommand').resolves(undefined);
        setQuickPickNextResult(undefined);
        await showHelpHubQuickPick();
        assert.strictEqual(exec.callCount, 0);
    });

    it('showHelpHubQuickPick runs executeCommand for the chosen row', async () => {
        const exec = sinon.stub(vscode.commands, 'executeCommand').resolves(undefined);
        setQuickPickNextResult({
            label: '$(mortar-board) Getting Started',
            description: 'Guided walkthrough',
            commandId: 'saropaLints.openWalkthrough',
        });
        await showHelpHubQuickPick();
        assert.ok(exec.calledOnceWithExactly('saropaLints.openWalkthrough'));
    });
});
