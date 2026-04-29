import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';

interface PackageJsonView {
  id: string;
  name: string;
  type?: string;
  when?: string;
}

/** package.json: Project Vibrancy sidebar view id and visibility clauses. */

function loadPackageJsonViews(): PackageJsonView[] {
  const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
  const raw = fs.readFileSync(pkgPath, 'utf-8');
  const pkg = JSON.parse(raw) as {
    contributes: { views: { saropaLints: PackageJsonView[] } };
  };
  return pkg.contributes.views.saropaLints;
}

describe('projectVibrancySidebar', () => {
  const viewId = 'saropaLints.projectVibrancy';

  it('exports expected view id', () => {
    const sourcePath = path.resolve(
      __dirname,
      '..',
      '..',
      '..',
      'src',
      'views',
      'projectVibrancySidebarProvider.ts',
    );
    const source = fs.readFileSync(sourcePath, 'utf-8');
    assert.ok(
      source.includes("export const PROJECT_VIBRANCY_VIEW_ID = 'saropaLints.projectVibrancy';"),
      'Expected provider source to export PROJECT_VIBRANCY_VIEW_ID',
    );
  });

  it('is registered in package.json as a webview', () => {
    const views = loadPackageJsonViews();
    const view = views.find((v) => v.id === viewId);
    assert.ok(view, `Expected package.json to contain view "${viewId}"`);
    assert.strictEqual(view?.type, 'webview');
    assert.ok(
      (view?.when ?? '').includes('saropaLints.isDartProject'),
      'Project Vibrancy view should be gated to Dart projects',
    );
  });

  it('is listed in the commands menu for direct access', () => {
    const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
    const raw = fs.readFileSync(pkgPath, 'utf-8');
    const pkg = JSON.parse(raw) as {
      contributes: { commands: Array<{ command: string; title: string }> };
    };
    const hasReport = pkg.contributes.commands.some(
      (entry) => entry.command === 'saropaLints.openProjectVibrancyReport',
    );
    const hasSettings = pkg.contributes.commands.some(
      (entry) => entry.command === 'saropaLints.openProjectVibrancySettings',
    );
    assert.ok(hasReport, 'Expected openProjectVibrancyReport command in package.json');
    assert.ok(hasSettings, 'Expected openProjectVibrancySettings command in package.json');
  });
});
