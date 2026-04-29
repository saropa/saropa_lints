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
  it('renames Config view to Triage', () => {
    const pkg = loadPackageJson();
    const configView = pkg.contributes.views.saropaLints.find((view) => view.id === 'saropaLints.config');
    assert.ok(configView, 'expected saropaLints.config to exist');
    assert.strictEqual(configView?.name, 'Triage');
  });

  it('renames config copy command to Triage wording', () => {
    const pkg = loadPackageJson();
    const cmd = pkg.contributes.commands.find((entry) => entry.command === 'saropaLints.config.copyAsJson');
    assert.ok(cmd, 'expected saropaLints.config.copyAsJson command to exist');
    assert.strictEqual(cmd?.title, 'Copy Triage as JSON');
  });

  it('uses Activity bar sections settings group title', () => {
    const pkg = loadPackageJson();
    const hasGroup = pkg.contributes.configuration.some((section) => section.title === 'Activity bar sections');
    assert.strictEqual(hasGroup, true, 'expected configuration title "Activity bar sections"');
  });

  it('distinguishes no-analysis welcome state from no-violations state copy', () => {
    const pkg = loadPackageJson();
    const issuesWelcome = pkg.contributes.viewsWelcome.find((entry) => entry.view === 'saropaLints.issues');
    assert.ok(issuesWelcome, 'expected viewsWelcome entry for saropaLints.issues');
    assert.ok(
      issuesWelcome?.contents.includes('No analysis report yet.'),
      'issues welcome copy should communicate not-analyzed-yet state',
    );
    assert.ok(
      issuesWelcome?.contents.includes('[Run Analysis](command:saropaLints.runAnalysis)'),
      'issues welcome copy should include Run Analysis CTA',
    );
  });

  it('uses Open Analysis Options command title', () => {
    const pkg = loadPackageJson();
    const cmd = pkg.contributes.commands.find((entry) => entry.command === 'saropaLints.openConfig');
    assert.ok(cmd, 'expected saropaLints.openConfig command to exist');
    assert.strictEqual(cmd?.title, 'Saropa Lints: Open Analysis Options');
  });
});
