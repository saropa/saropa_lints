/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks).
 */

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

/** Flat key -> English string bundle for resolves %keys% contributed from package.json. */
type PackageNls = Record<string, string>;

/** package.json contributes: view names, commands, welcome copy (UX contract). */

function loadPackageJson(): PackageJsonShape {
  const pkgPath = path.resolve(__dirname, '..', '..', '..', 'package.json');
  return JSON.parse(fs.readFileSync(pkgPath, 'utf8')) as PackageJsonShape;
}

function loadPackageNls(): PackageNls {
  const nlsPath = path.resolve(__dirname, '..', '..', '..', 'package.nls.json');
  return JSON.parse(fs.readFileSync(nlsPath, 'utf8')) as PackageNls;
}

/** Resolves `%key%` placeholders the same way VS Code does at runtime (English bundle). */
function resolveNlsValue(raw: string, nls: PackageNls): string {
  const trimmed = raw.trim();
  const m = /^%([^%]+)%$/.exec(trimmed);
  if (!m) {
    return raw;
  }
  const resolved = nls[m[1]];
  assert.ok(resolved !== undefined, `missing package.nls.json entry for "${m[1]}"`);
  return resolved;
}

describe('UX labels in package.json', () => {
  it('registers the six sectioned panels in the saropaLints activity bar', () => {
    const pkg = loadPackageJson();
    const views = pkg.contributes.views.saropaLints;
    // Each section is its own VS Code view (collapsible panel via title bar).
    // Adding or removing a section here means updating SECTION_VIEW_IDS too.
    // Triage was merged into Settings — there is no longer a standalone
    // saropaLints.triage view. Triage rows render inside the Settings panel.
    // The standalone config-Suggestions view was removed (its "Enable the X rule
    // pack" list moved to the Manage Rule Packs webview + startup toast).
    const expected = [
      'saropaLints.banner',
      'saropaLints.editorDashboards',
      'saropaLints.actions',
      'saropaLints.status',
      'saropaLints.settings',
      'saropaLints.help',
    ].sort();
    const actual = views.map((v) => v.id).sort();
    assert.deepStrictEqual(actual, expected, 'sidebar = six section panels');
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
    const nls = loadPackageNls();
    const hasGroup = pkg.contributes.configuration.some(
      (section) => resolveNlsValue(section.title, nls) === 'Activity bar',
    );
    assert.strictEqual(hasGroup, true, 'expected configuration title "Activity bar"');
  });

  it('contributes viewsWelcome on the Banner view for non-Dart projects', () => {
    const pkg = loadPackageJson();
    const nls = loadPackageNls();
    // The Banner view stays visible whenever a banner is needed OR the
    // workspace is not a Dart project; its welcome content prompts for a
    // pubspec folder when the project type is wrong.
    const welcome = pkg.contributes.viewsWelcome.filter((entry) => entry.view === 'saropaLints.banner');
    assert.strictEqual(welcome.length, 1);
    const bannerCopy = resolveNlsValue(welcome[0]!.contents, nls);
    assert.strictEqual(bannerCopy.includes('pubspec.yaml'), true);
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
    const nls = loadPackageNls();
    const cmd = pkg.contributes.commands.find((entry) => entry.command === 'saropaLints.openConfig');
    assert.ok(cmd, 'expected saropaLints.openConfig command to exist');
    assert.strictEqual(resolveNlsValue(cmd!.title, nls), 'Saropa Lints: Open Analysis Options');
  });
});
