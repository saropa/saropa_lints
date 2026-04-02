/**
 * Tests for the Drift Advisor integration toggle toolbar buttons.
 *
 * These tests validate package.json metadata — command declarations and
 * view/title menu entries — so that regressions (wrong context-key name,
 * missing entry, broken when-clause) are caught without requiring a full
 * VS Code host.
 *
 * Before: users had to open Settings and manually toggle
 *   `saropaLints.driftAdvisor.integration`.
 * After:  two mutually-exclusive toolbar icons (plug / circle-slash) let
 *   users enable or disable integration directly from the Drift Advisor view.
 */

import * as assert from 'node:assert';
import * as path from 'node:path';
import * as fs from 'node:fs';

interface PackageCommand {
  command: string;
  title: string;
  icon?: string;
}

interface MenuEntry {
  command: string;
  when: string;
  group?: string;
}

interface PackageJson {
  contributes: {
    commands: PackageCommand[];
    menus: {
      'view/title': MenuEntry[];
      [key: string]: unknown;
    };
  };
}

function loadPackageJson(): PackageJson {
  const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
  return JSON.parse(fs.readFileSync(pkgPath, 'utf8')) as PackageJson;
}

const ENABLE_ID = 'saropaLints.driftAdvisor.enableIntegration';
const DISABLE_ID = 'saropaLints.driftAdvisor.disableIntegration';
const INTEGRATION_CTX = 'saropaLints.driftAdvisor.integration';

describe('Drift Advisor integration toggle — package.json commands', () => {
  let pkg: PackageJson;

  before(() => {
    pkg = loadPackageJson();
  });

  it('declares enableIntegration command with plug icon', () => {
    const cmd = pkg.contributes.commands.find((c) => c.command === ENABLE_ID);
    assert.ok(cmd, `command ${ENABLE_ID} not found in contributes.commands`);
    assert.strictEqual(cmd.icon, '$(plug)', 'enableIntegration must use $(plug) icon');
    assert.ok(cmd.title.length > 0, 'title must not be empty');
  });

  it('declares disableIntegration command with circle-slash icon', () => {
    const cmd = pkg.contributes.commands.find((c) => c.command === DISABLE_ID);
    assert.ok(cmd, `command ${DISABLE_ID} not found in contributes.commands`);
    assert.strictEqual(cmd.icon, '$(circle-slash)', 'disableIntegration must use $(circle-slash) icon');
    assert.ok(cmd.title.length > 0, 'title must not be empty');
  });
});

describe('Drift Advisor integration toggle — view/title menu entries', () => {
  let viewTitle: MenuEntry[];

  before(() => {
    const pkg = loadPackageJson();
    viewTitle = pkg.contributes.menus['view/title'];
  });

  it('has a view/title entry for enableIntegration', () => {
    const entry = viewTitle.find((e) => e.command === ENABLE_ID);
    assert.ok(entry, `view/title entry for ${ENABLE_ID} not found`);
    assert.strictEqual(entry.group, 'navigation');
  });

  it('has a view/title entry for disableIntegration', () => {
    const entry = viewTitle.find((e) => e.command === DISABLE_ID);
    assert.ok(entry, `view/title entry for ${DISABLE_ID} not found`);
    assert.strictEqual(entry.group, 'navigation');
  });

  it('enableIntegration when-clause uses the correct context key negated', () => {
    const entry = viewTitle.find((e) => e.command === ENABLE_ID)!;
    assert.ok(
      entry.when.includes(`!${INTEGRATION_CTX}`),
      `enableIntegration when-clause must include "!${INTEGRATION_CTX}"; got: ${entry.when}`,
    );
  });

  it('disableIntegration when-clause uses the correct context key (not negated)', () => {
    const entry = viewTitle.find((e) => e.command === DISABLE_ID)!;
    assert.ok(
      entry.when.includes(INTEGRATION_CTX),
      `disableIntegration when-clause must include "${INTEGRATION_CTX}"; got: ${entry.when}`,
    );
    assert.ok(
      !entry.when.includes(`!${INTEGRATION_CTX}`),
      `disableIntegration when-clause must NOT negate the context key; got: ${entry.when}`,
    );
  });

  it('both entries are scoped to the driftAdvisor view', () => {
    for (const id of [ENABLE_ID, DISABLE_ID]) {
      const entry = viewTitle.find((e) => e.command === id)!;
      assert.ok(
        entry.when.includes('view == saropaLints.driftAdvisor'),
        `${id} when-clause must be scoped to view == saropaLints.driftAdvisor; got: ${entry.when}`,
      );
    }
  });

  it('when-clauses are mutually exclusive (one negates, the other does not)', () => {
    const enable = viewTitle.find((e) => e.command === ENABLE_ID)!;
    const disable = viewTitle.find((e) => e.command === DISABLE_ID)!;
    // Enable shows when integration is false, disable shows when integration is true.
    // Exactly one of the two when-clauses must contain "!saropaLints.driftAdvisor.integration".
    const enableNegates = enable.when.includes(`!${INTEGRATION_CTX}`);
    const disableNegates = disable.when.includes(`!${INTEGRATION_CTX}`);
    assert.ok(enableNegates, 'enable when-clause must negate the context key');
    assert.ok(!disableNegates, 'disable when-clause must NOT negate the context key');
  });
});
