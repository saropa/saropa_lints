import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { buildWatcherExcludeSectionHtml } from '../../rulePacks/watcherExcludeSection';

const rows = {
  'watcherExclude.maxFileKb': '<tr id="setting-row-a"></tr>',
  'watcherExclude.maxFolderFiles': '<tr id="setting-row-b"></tr>',
};

describe('buildWatcherExcludeSectionHtml', () => {
  it('shows counts and lists for files, folders and recommended excludes', () => {
    const html = buildWatcherExcludeSectionHtml(rows, {
      hazards: [
        { relative: 'a/big.bin', size: 9 },
        { relative: 'gen', size: 0, fileCount: 2000 },
      ],
      missingExcludes: ['**/.gradle/**', '**/DerivedData/**'],
    });
    assert.ok(html.includes('id="setting-row-a"') && html.includes('id="setting-row-b"'));
    assert.ok(html.includes('<code>a/big.bin</code>'));
    assert.ok(html.includes('<code>gen/ (2000)</code>'));
    assert.ok(html.includes('<code>**/.gradle/**</code>'));
    assert.strictEqual((html.match(/<details>/g) ?? []).length, 3);
    assert.ok(html.includes('2 affected'));
  });

  it('omits the List control when nothing is affected and shows scanning before data', () => {
    const empty = buildWatcherExcludeSectionHtml(rows, { hazards: [], missingExcludes: [] });
    assert.ok(!empty.includes('<details>'));
    assert.ok(empty.includes('0 affected'));
    const pending = buildWatcherExcludeSectionHtml(rows, undefined);
    assert.ok(pending.includes('Scanning'));
  });

  it('escapes paths', () => {
    const html = buildWatcherExcludeSectionHtml(rows, {
      hazards: [{ relative: '<x>.bin', size: 1 }],
      missingExcludes: [],
    });
    assert.ok(html.includes('&lt;x&gt;.bin'));
  });
});
