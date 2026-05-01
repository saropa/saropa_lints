/**
 * Drift Advisor integration commands remain in the palette / Findings dashboard;
 * the dedicated Drift activity-bar tree was removed (dashboard-first).
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
    views: { saropaLints: { id: string }[] };
  };
}

function loadPackageJson(): PackageJson {
  const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
  return JSON.parse(fs.readFileSync(pkgPath, 'utf8')) as PackageJson;
}

const ENABLE_ID = 'saropaLints.driftAdvisor.enableIntegration';
const DISABLE_ID = 'saropaLints.driftAdvisor.disableIntegration';

describe('Drift Advisor integration — package.json commands', () => {
  let pkg: PackageJson;

  before(() => {
    pkg = loadPackageJson();
  });

  it('declares enableIntegration command with plug icon', () => {
    const cmd = pkg.contributes.commands.find((c) => c.command === ENABLE_ID);
    assert.ok(cmd, `command ${ENABLE_ID} not found in contributes.commands`);
    assert.strictEqual(cmd.icon, '$(plug)', 'enableIntegration must use $(plug) icon');
  });

  it('declares disableIntegration command with circle-slash icon', () => {
    const cmd = pkg.contributes.commands.find((c) => c.command === DISABLE_ID);
    assert.ok(cmd, `command ${DISABLE_ID} not found in contributes.commands`);
    assert.strictEqual(cmd.icon, '$(circle-slash)', 'disableIntegration must use $(circle-slash) icon');
  });
});

describe('Drift Advisor — view / toolbar wiring', () => {
  it('toolbar enable/disable is consistent with whether Drift sidebar view exists', () => {
    const pkg = loadPackageJson();
    const hasDriftView = pkg.contributes.views.saropaLints.some((v) => v.id === 'saropaLints.driftAdvisor');
    const viewTitle = pkg.contributes.menus['view/title'] as MenuEntry[];
    for (const id of [ENABLE_ID, DISABLE_ID]) {
      const entry = viewTitle.find((e) => e.command === id);
      if (!entry) continue;
      if (hasDriftView) {
        assert.ok(
          entry.when.includes('saropaLints.driftAdvisor'),
          `${id} should target the Drift view toolbar when the view is contributed`,
        );
      } else {
        assert.ok(
          !entry.when.includes('view == saropaLints.driftAdvisor'),
          `${id} must not reference a removed driftAdvisor view`,
        );
      }
    }
  });
});
