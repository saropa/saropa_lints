/**
 * Tests for the sidebar section toggle command declaration in package.json.
 *
 * Verifies that `saropaLints.toggleSidebarSection` is:
 * 1. Declared in `contributes.commands` so VS Code recognizes tree-item
 *    click handlers (before this fix the command was only registered via
 *    `registerCommand`, which was silently ignored for TreeItem.command
 *    on some VS Code versions).
 * 2. Hidden from the command palette via a `when: "false"` entry in
 *    `contributes.menus.commandPalette`, because invoking it without the
 *    section-key argument is a no-op.
 */

import * as assert from 'node:assert';
import * as path from 'node:path';
import * as fs from 'node:fs';

interface PackageCommand {
    command: string;
    title: string;
}

interface PaletteEntry {
    command: string;
    when: string;
}

interface PackageJson {
    contributes: {
        commands: PackageCommand[];
        menus: {
            commandPalette: PaletteEntry[];
            [key: string]: unknown;
        };
    };
}

const TOGGLE_CMD = 'saropaLints.toggleSidebarSection';

function loadPackageJson(): PackageJson {
    // out-test/test/ → extension/ (two levels up)
    const pkgPath = path.resolve(__dirname, '..', '..', 'package.json');
    return JSON.parse(fs.readFileSync(pkgPath, 'utf8')) as PackageJson;
}

describe('sidebar toggle command — package.json', () => {
    let pkg: PackageJson;

    before(() => {
        pkg = loadPackageJson();
    });

    it('declares toggleSidebarSection in contributes.commands', () => {
        const cmd = pkg.contributes.commands.find((c) => c.command === TOGGLE_CMD);
        assert.ok(cmd, `command ${TOGGLE_CMD} not found in contributes.commands`);
        assert.ok(cmd.title.length > 0, 'title must not be empty');
    });

    it('hides toggleSidebarSection from the command palette', () => {
        const entry = pkg.contributes.menus.commandPalette.find(
            (e) => e.command === TOGGLE_CMD,
        );
        assert.ok(
            entry,
            `commandPalette entry for ${TOGGLE_CMD} not found — ` +
            'the command takes a programmatic argument and must not appear in the palette',
        );
        assert.strictEqual(
            entry.when,
            'false',
            `commandPalette when-clause must be "false"; got: ${entry.when}`,
        );
    });
});
