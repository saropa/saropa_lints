import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';

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
  it('renders scope badge and filtered count placeholders', () => {
    const source = loadSidebarSource();
    assert.ok(source.includes('id="scopeBadge"'));
    assert.ok(source.includes('id="filteredCount"'));
  });

  it('wires since controls and persisted state fields', () => {
    const source = loadSidebarSource();
    assert.ok(source.includes('id="quickStub"'));
    assert.ok(source.includes('stub_tested'));
    assert.ok(source.includes("id=\"sinceRef\""));
    assert.ok(source.includes("id=\"applySince\""));
    assert.ok(source.includes("id=\"clearSince\""));
    assert.ok(source.includes('vscode.getState()'));
    assert.ok(source.includes('vscode.setState('));
    assert.ok(source.includes("type: 'setSinceRef'"));
  });

  it('wires extension-first JSON copy, settings, and gate banner', () => {
    const source = loadSidebarSource();
    assert.ok(source.includes("type: 'copyJson'"));
    assert.ok(source.includes("type: 'openProjectVibrancySettings'"));
    assert.ok(source.includes('gate-warn'));
  });
});
