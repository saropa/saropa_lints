import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';

interface ContributedView {
  id: string;
  name: string;
}

interface PackageJsonShape {
  contributes: {
    views: {
      saropaLints: ContributedView[];
    };
    viewsWelcome: Array<{
      view: string;
      contents: string;
    }>;
    commands: Array<{
      command: string;
      title: string;
    }>;
    configuration: Array<{
      title: string;
    }>;
  };
}

/** package.json contributes: view names, commands, welcome copy (UX contract). */

function loadPackageJson(): PackageJsonShape {
  const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
  return JSON.parse(fs.readFileSync(pkgPath, 'utf8')) as PackageJsonShape;
}

describe('UX labels in package.json', () => {
  it('registers the six sectioned panels in the saropaLints activity bar', () => {
    const pkg = loadPackageJson();
    const views = pkg.contributes.views.saropaLints;
    // Each section is its own VS Code view (collapsible panel via title bar).
    // Adding or removing a section here means updating SECTION_VIEW_IDS too.
    // Triage was merged into Settings — there is no longer a standalone
    // saropaLints.triage view. Triage rows render inside the Settings panel.
    const expected = [
      'saropaLints.banner',
      'saropaLints.editorDashboards',
      'saropaLints.actions',
      'saropaLints.status',
      'saropaLints.settings',
      'saropaLints.help',
    ].sort();
    const actual = views.map((v) => v.id).sort();
    assert.deepStrictEqual(actual, expected, 'sidebar must contain exactly the six section panels');
    assert.ok(!views.some((v) => v.id === 'saropaLints.overview'), 'monolithic overview view removed');
    assert.ok(!views.some((v) => v.id === 'saropaLints.dashboardHub'), 'dashboardHub view removed');
    assert.ok(!views.some((v) => v.id === 'saropaLints.triage'), 'triage view merged into settings');
  });

  it('removes orphan copyAsJson commands without runtime handlers', () => {
    // saropaLints.config.copyAsJson and saropaLints.overview.copyAsJson were
    // declared in package.json but never registered with vscode.commands.
    // The Triage and Overview trees they targeted were merged into Settings
    // and the dashboards; their JSON-export commands were left behind as
    // dead palette entries until this cleanup removed them.
    const pkg = loadPackageJson();
    const orphan = pkg.contributes.commands.find(
      (entry) =>
        entry.command === 'saropaLints.config.copyAsJson' ||
        entry.command === 'saropaLints.overview.copyAsJson',
    );
    assert.strictEqual(orphan, undefined, 'orphan copyAsJson commands must stay deleted');
  });

  it('uses Activity bar settings group title', () => {
    const pkg = loadPackageJson();
    const hasGroup = pkg.contributes.configuration.some((section) => section.title === 'Activity bar');
    assert.strictEqual(hasGroup, true, 'expected configuration title "Activity bar"');
  });

  it('contributes viewsWelcome on the Banner view for non-Dart projects', () => {
    const pkg = loadPackageJson();
    // The Banner view stays visible whenever a banner is needed OR the
    // workspace is not a Dart project; its welcome content prompts for a
    // pubspec folder when the project type is wrong.
    const welcome = pkg.contributes.viewsWelcome.filter((entry) => entry.view === 'saropaLints.banner');
    assert.strictEqual(welcome.length, 1);
    assert.strictEqual(welcome[0]!.contents.includes('pubspec.yaml'), true);
    assert.ok(
      !pkg.contributes.viewsWelcome.some((entry) => entry.view === 'saropaLints.overview'),
      'old overview welcome removed',
    );
    assert.ok(
      !pkg.contributes.viewsWelcome.some((entry) => entry.view === 'saropaLints.dashboardHub'),
      'dashboardHub welcome removed',
    );
  });

  it('uses Open Analysis Options command title', () => {
    const pkg = loadPackageJson();
    const cmd = pkg.contributes.commands.find((entry) => entry.command === 'saropaLints.openConfig');
    assert.ok(cmd, 'expected saropaLints.openConfig command to exist');
    assert.strictEqual(cmd?.title, 'Saropa Lints: Open Analysis Options');
  });
});
