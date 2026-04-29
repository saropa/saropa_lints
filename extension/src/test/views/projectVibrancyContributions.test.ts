import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';

interface PackageJsonView {
  id: string;
  name: string;
  type?: string;
  when?: string;
}

/** package.json: Project Vibrancy is report-only (no duplicate sidebar webview). */

function loadPackageJsonViews(): PackageJsonView[] {
  const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
  const raw = fs.readFileSync(pkgPath, 'utf-8');
  const pkg = JSON.parse(raw) as {
    contributes: { views: { saropaLints: PackageJsonView[] } };
  };
  return pkg.contributes.views.saropaLints;
}

describe('projectVibrancyContributions', () => {
  const removedViewId = 'saropaLints.projectVibrancy';

  it('does not register a Project Vibrancy sidebar webview', () => {
    const views = loadPackageJsonViews();
    const view = views.find((v) => v.id === removedViewId);
    assert.strictEqual(view, undefined, 'Project Vibrancy should not duplicate the report in a sidebar view');
  });

  it('exposes report and settings commands without sidebar refresh', () => {
    const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
    const raw = fs.readFileSync(pkgPath, 'utf-8');
    const pkg = JSON.parse(raw) as {
      contributes: { commands: Array<{ command: string; title: string }> };
    };
    const commands = pkg.contributes.commands.map((c) => c.command);
    assert.ok(commands.includes('saropaLints.openProjectVibrancyReport'));
    assert.ok(commands.includes('saropaLints.openProjectVibrancySettings'));
    assert.ok(!commands.includes('saropaLints.refreshProjectVibrancySidebar'));
  });
});
