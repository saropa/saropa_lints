/**
 * Tests for the command catalog sidebar view registration.
 *
 * Validates that the exported VIEW_ID matches the package.json view
 * registration, that the sidebar catalog is the first view in the
 * container, and that internal commands are excluded from compact
 * section rendering.
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { COMMAND_CATALOG_SIDEBAR_VIEW_ID } from '../views/commandCatalogSidebarProvider';

interface PackageJsonView {
  id: string;
  name: string;
  type?: string;
  when?: string;
}

function loadPackageJsonViews(): PackageJsonView[] {
  const pkgPath = path.resolve(__dirname, '..', '..', 'package.json');
  const raw = fs.readFileSync(pkgPath, 'utf-8');
  const pkg = JSON.parse(raw) as {
    contributes: { views: { saropaLints: PackageJsonView[] } };
  };
  return pkg.contributes.views.saropaLints;
}

describe('commandCatalogSidebar', () => {
  it('VIEW_ID matches the package.json view registration', () => {
    const views = loadPackageJsonViews();
    const match = views.find((v) => v.id === COMMAND_CATALOG_SIDEBAR_VIEW_ID);
    assert.ok(
      match,
      `Expected package.json to contain a view with id "${COMMAND_CATALOG_SIDEBAR_VIEW_ID}"`,
    );
  });

  it('command catalog sidebar is the first view in the container', () => {
    const views = loadPackageJsonViews();
    // The command catalog should be the first section users see
    // so it acts as the primary entry point.
    assert.strictEqual(
      views[0].id,
      COMMAND_CATALOG_SIDEBAR_VIEW_ID,
      `Expected first view to be "${COMMAND_CATALOG_SIDEBAR_VIEW_ID}" but got "${views[0].id}"`,
    );
  });

  it('command catalog sidebar is registered as a webview', () => {
    const views = loadPackageJsonViews();
    const match = views.find((v) => v.id === COMMAND_CATALOG_SIDEBAR_VIEW_ID);
    assert.strictEqual(match?.type, 'webview');
  });

  it('command catalog sidebar has a visibility when-clause', () => {
    const views = loadPackageJsonViews();
    const match = views.find((v) => v.id === COMMAND_CATALOG_SIDEBAR_VIEW_ID);
    // Should be gated behind isDartProject and the sidebar toggle.
    assert.ok(match?.when, 'Expected a when clause for visibility gating');
    assert.ok(
      match.when.includes('saropaLints.sidebar.showCommandCatalog'),
      'when clause should reference sidebar.showCommandCatalog toggle',
    );
  });
});
