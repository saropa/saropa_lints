import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';

/** Static checks on sidebar provider source (webview enablement, script CSP hints). */

function loadSidebarSource(): string {
  const sourcePath = path.resolve(
    __dirname,
    '..',
    '..',
    '..',
    'src',
    'views',
    'projectVibrancySidebarProvider.ts',
  );
  return fs.readFileSync(sourcePath, 'utf-8');
}

describe('projectVibrancySidebar UI state wiring', () => {
  it('renders compact scope indicator and top risk list', () => {
    const source = loadSidebarSource();
    assert.ok(source.includes('class="scope"'));
    assert.ok(source.includes('Top Risk Functions'));
    assert.ok(source.includes('class="risk-list"'));
  });

  it('wires minimal primary actions', () => {
    const source = loadSidebarSource();
    assert.ok(source.includes('id="refreshScan"'));
    assert.ok(source.includes('id="openFullReport"'));
    assert.ok(source.includes('id="copyJson"'));
    assert.ok(source.includes('id="openPvSettings"'));
  });

  it('wires extension-first JSON copy, settings, and gate banner', () => {
    const source = loadSidebarSource();
    assert.ok(source.includes("type: 'copyJson'"));
    assert.ok(source.includes("type: 'openProjectVibrancySettings'"));
    assert.ok(source.includes('gate-warn'));
  });
});
