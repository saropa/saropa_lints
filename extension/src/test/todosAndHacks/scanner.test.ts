/**
 * Unit tests for the TODOs & Hacks scanner: regex extraction and exclude-pattern merging.
 * Uses scannerCore (no vscode) so tests run in Node without mocks.
 */

import * as assert from 'assert';
import {
  buildRegex,
  extractMarkersFromLines,
  getExcludePattern,
} from '../../services/todosAndHacksScannerCore';

describe('todosAndHacks scanner', () => {
  describe('buildRegex', () => {
    it('builds regex that matches // TODO: style', () => {
      const regex = buildRegex(['TODO', 'FIXME']);
      const line = '  // TODO: fix this later';
      const m = line.match(regex);
      assert.ok(m);
      assert.strictEqual(m![1], 'TODO');
      assert.strictEqual((m![3] ?? '').trim(), 'fix this later');
    });

    it('builds regex that matches # FIXME style', () => {
      const regex = buildRegex(['TODO', 'FIXME']);
      const line = '# FIXME: remove before release';
      const m = line.match(regex);
      assert.ok(m);
      assert.strictEqual(m![1], 'FIXME');
      assert.strictEqual((m![3] ?? '').trim(), 'remove before release');
    });

    it('builds regex that matches <!-- HACK --> style', () => {
      const regex = buildRegex(['HACK']);
      const line = '  <!-- HACK: workaround for IE -->';
      const m = line.match(regex);
      assert.ok(m);
      assert.strictEqual(m![1], 'HACK');
      const snippet = (m![3] ?? '').trim();
      assert.ok(snippet.includes('workaround'));
    });

    it('returns non-matching regex when tags are empty', () => {
      const regex = buildRegex([]);
      assert.strictEqual(regex.source, '^$');
    });
  });

  describe('extractMarkersFromLines', () => {
    it('returns correct markers for multi-line content (built-in regex)', () => {
      const regex = buildRegex(['TODO', 'FIXME', 'HACK']);
      const content = [
        'void main() {',
        '  // TODO: add tests',
        '  return;',
        '  # FIXME: hardcoded path',
        '  // HACK: temporary',
      ].join('\n');
      const markers = extractMarkersFromLines(content, regex, false);
      assert.strictEqual(markers.length, 3);
      assert.strictEqual(markers[0].tag, 'TODO');
      assert.strictEqual(markers[0].snippet, 'add tests');
      assert.strictEqual(markers[0].lineIndex, 1);
      assert.strictEqual(markers[1].tag, 'FIXME');
      assert.strictEqual(markers[1].snippet, 'hardcoded path');
      assert.strictEqual(markers[1].lineIndex, 3);
      assert.strictEqual(markers[2].tag, 'HACK');
      assert.strictEqual(markers[2].snippet, 'temporary');
      assert.strictEqual(markers[2].lineIndex, 4);
    });

    it('uses tag as snippet when snippet is empty', () => {
      const regex = buildRegex(['XXX']);
      const content = '// XXX:';
      const markers = extractMarkersFromLines(content, regex, false);
      assert.strictEqual(markers.length, 1);
      assert.strictEqual(markers[0].tag, 'XXX');
      assert.strictEqual(markers[0].snippet, 'XXX');
    });

    it('trims trailing --> for HTML comments (built-in)', () => {
      const regex = buildRegex(['TODO']);
      const content = '<!-- TODO: fix this -->';
      const markers = extractMarkersFromLines(content, regex, false);
      assert.strictEqual(markers.length, 1);
      assert.ok(!markers[0].snippet.endsWith('-->'));
    });

    it('custom regex: two capture groups use second as snippet', () => {
      const customRegex = /^\s*-\s+(TODO|FIXME)\s*:\s*(.*)$/;
      const content = '- TODO: item one\n- FIXME: item two';
      const markers = extractMarkersFromLines(content, customRegex, true);
      assert.strictEqual(markers.length, 2);
      assert.strictEqual(markers[0].tag, 'TODO');
      assert.strictEqual(markers[0].snippet, 'item one');
      assert.strictEqual(markers[1].tag, 'FIXME');
      assert.strictEqual(markers[1].snippet, 'item two');
    });
  });

  describe('getExcludePattern', () => {
    it('returns single pattern when one part', () => {
      const out = getExcludePattern(['**/build/**'], undefined);
      assert.strictEqual(out, '**/build/**');
    });

    it('merges multiple globs with braces', () => {
      const out = getExcludePattern(
        ['**/node_modules/**', '**/build/**'],
        undefined,
      );
      assert.strictEqual(out, '{**/node_modules/**,**/build/**}');
    });

    it('merges search.exclude (true values only)', () => {
      const out = getExcludePattern(
        ['**/build/**'],
        { '**/.git': true, '**/out': false, '**/dist': true },
      );
      assert.ok(out.includes('**/build/**'));
      assert.ok(out.includes('**/.git'));
      assert.ok(out.includes('**/dist'));
      assert.ok(!out.includes('**/out'));
    });

    it('returns empty string when no parts', () => {
      const out = getExcludePattern([], undefined);
      assert.strictEqual(out, '');
    });
  });
});
