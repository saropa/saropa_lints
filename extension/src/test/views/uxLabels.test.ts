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
  it('registers a single flat Saropa Lints view in the activity bar', () => {
    const pkg = loadPackageJson();
    const views = pkg.contributes.views.saropaLints;
    // Flat-sidebar refactor: Dashboards + Overview & options collapsed into one
    // unified view. Any second view would reintroduce the structural split the
    // refactor exists to remove.
    assert.strictEqual(views.length, 1, 'expected exactly one Saropa view');
    const overview = views.find((view) => view.id === 'saropaLints.overview');
    assert.ok(overview, 'expected saropaLints.overview');
    assert.strictEqual(overview!.name, 'Saropa Lints');
    assert.ok(!views.some((v) => v.id === 'saropaLints.dashboardHub'), 'dashboardHub view removed');
    assert.ok(!views.some((v) => v.id === 'saropaLints.issues'), 'Violations tree view removed');
    assert.ok(!views.some((v) => v.id === 'saropaLints.summary'), 'Summary view removed');
  });

  it('renames config copy command to Triage wording', () => {
    const pkg = loadPackageJson();
    const cmd = pkg.contributes.commands.find((entry) => entry.command === 'saropaLints.config.copyAsJson');
    assert.ok(cmd, 'expected saropaLints.config.copyAsJson command to exist');
    assert.strictEqual(cmd?.title, 'Copy Triage as JSON');
  });

  it('uses Activity bar settings group title', () => {
    const pkg = loadPackageJson();
    const hasGroup = pkg.contributes.configuration.some((section) => section.title === 'Activity bar');
    assert.strictEqual(hasGroup, true, 'expected configuration title "Activity bar"');
  });

  it('contributes viewsWelcome on the unified view for non-Dart projects', () => {
    const pkg = loadPackageJson();
    // After the flat-sidebar refactor the Dart-but-no-report case is handled
    // inline by the provider (setup banner + action rows + status placeholder),
    // so the only remaining welcome is the non-Dart prompt.
    const welcome = pkg.contributes.viewsWelcome.filter((entry) => entry.view === 'saropaLints.overview');
    assert.strictEqual(welcome.length, 1);
    assert.strictEqual(welcome[0]!.contents.includes('pubspec.yaml'), true);
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
