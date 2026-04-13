/**
 * Sync test: ensures the command catalog registry stays aligned with the
 * commands declared in package.json. Catches two classes of drift:
 *
 * 1. A command exists in package.json but is missing from the catalog registry.
 * 2. A catalog entry references a command that does not exist in package.json.
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  catalogCategoryOrder,
  catalogEntries,
  entriesByCategory,
} from '../views/commandCatalogRegistry';
import { buildCatalogSearchBlob } from '../views/commandCatalogSearch';

/** Read and deduplicate command IDs from package.json contributes.commands. */
function loadPackageJsonCommands(): Set<string> {
  // From compiled out-test/test/ the extension root is two levels up.
  const pkgPath = path.resolve(__dirname, '..', '..', 'package.json');
  const raw = fs.readFileSync(pkgPath, 'utf-8');
  const pkg = JSON.parse(raw) as {
    contributes: { commands: Array<{ command: string }> };
  };
  return new Set(pkg.contributes.commands.map((c) => c.command));
}

/** Load the commandPalette when-clauses from package.json menus. */
function loadCommandPaletteEntries(): Map<string, string> {
  const pkgPath = path.resolve(__dirname, '..', '..', 'package.json');
  const raw = fs.readFileSync(pkgPath, 'utf-8');
  const pkg = JSON.parse(raw) as {
    contributes: {
      menus: {
        commandPalette?: Array<{ command: string; when: string }>;
      };
    };
  };
  const entries = pkg.contributes.menus.commandPalette ?? [];
  return new Map(entries.map((e) => [e.command, e.when]));
}

describe('commandCatalogRegistry', () => {
  const packageCommands = loadPackageJsonCommands();
  const catalogCommands = new Set(catalogEntries.map((e) => e.command));

  // ── Sync: registry vs package.json ─────────────────────────────────────

  it('every catalog entry references a command that exists in package.json', () => {
    const orphaned = [...catalogCommands].filter(
      (cmd) => !packageCommands.has(cmd),
    );
    assert.deepStrictEqual(
      orphaned,
      [],
      'Catalog references commands not in package.json: ' +
        orphaned.join(', '),
    );
  });

  it('every package.json command has an entry in the catalog', () => {
    const missing = [...packageCommands].filter(
      (cmd) => !catalogCommands.has(cmd),
    );
    assert.deepStrictEqual(
      missing,
      [],
      'Commands in package.json missing from catalog: ' + missing.join(', '),
    );
  });

  // ── Data integrity ─────────────────────────────────────────────────────

  it('catalog has no duplicate command IDs', () => {
    const seen = new Set<string>();
    const dupes: string[] = [];
    for (const entry of catalogEntries) {
      if (seen.has(entry.command)) {
        dupes.push(entry.command);
      }
      seen.add(entry.command);
    }
    assert.deepStrictEqual(
      dupes,
      [],
      'Duplicate catalog entries: ' + dupes.join(', '),
    );
  });

  it('every catalog entry has a non-empty description', () => {
    const empty = catalogEntries
      .filter((e) => !e.description.trim())
      .map((e) => e.command);
    assert.deepStrictEqual(
      empty,
      [],
      'Entries with empty descriptions: ' + empty.join(', '),
    );
  });

  it('every catalog entry has a non-empty title', () => {
    const empty = catalogEntries
      .filter((e) => !e.title.trim())
      .map((e) => e.command);
    assert.deepStrictEqual(
      empty,
      [],
      'Entries with empty titles: ' + empty.join(', '),
    );
  });

  it('every catalog entry has a non-empty icon', () => {
    const empty = catalogEntries
      .filter((e) => !e.icon.trim())
      .map((e) => e.command);
    assert.deepStrictEqual(
      empty,
      [],
      'Entries with empty icons: ' + empty.join(', '),
    );
  });

  // ── Category structure ─────────────────────────────────────────────────

  it('every entry category is in the category order list', () => {
    const validCategories = new Set<string>(catalogCategoryOrder);
    const invalid = catalogEntries
      .filter((e) => !validCategories.has(e.category))
      .map((e) => `${e.command} → ${e.category}`);
    assert.deepStrictEqual(
      invalid,
      [],
      'Entries reference unknown categories: ' + invalid.join(', '),
    );
  });

  it('entriesByCategory returns categories in display order', () => {
    const grouped = entriesByCategory();
    const keys = [...grouped.keys()];
    // Filter catalogCategoryOrder to only categories that have entries.
    const expected = catalogCategoryOrder.filter(
      (cat) => grouped.has(cat),
    );
    assert.deepStrictEqual(
      keys,
      expected,
      'Category order does not match catalogCategoryOrder',
    );
  });

  it('entriesByCategory omits empty categories', () => {
    const grouped = entriesByCategory();
    for (const [cat, entries] of grouped) {
      assert.ok(
        entries.length > 0,
        `Category "${cat}" has no entries but was not removed`,
      );
    }
  });

  // ── Enablement audit: commands with when:false must be internal ────────

  it('commands hidden from palette (when:false) are marked internal in catalog', () => {
    const paletteEntries = loadCommandPaletteEntries();
    const hiddenCommands = [...paletteEntries.entries()]
      .filter(([, when]) => when === 'false')
      .map(([cmd]) => cmd);

    const notMarkedInternal = hiddenCommands.filter((cmd) => {
      const entry = catalogEntries.find((e) => e.command === cmd);
      // If the command isn't in the catalog at all, the sync test catches that.
      return entry && !entry.internal;
    });

    assert.deepStrictEqual(
      notMarkedInternal,
      [],
      'Commands hidden from palette (when:false) should be marked internal: ' +
        notMarkedInternal.join(', '),
    );
  });

  // ── Self-referencing: catalog includes itself ──────────────────────────

  it('the showCommandCatalog command is in the catalog', () => {
    assert.ok(
      catalogCommands.has('saropaLints.showCommandCatalog'),
      'The catalog command should catalog itself',
    );
  });

  // ── Display grouping & search index (explicit regression guards) ───────

  it('entriesByCategory sorts entries by title within each section (A→Z)', () => {
    const grouped = entriesByCategory();
    for (const [, list] of grouped) {
      const titles = list.map((e) => e.title);
      const sorted = [...titles].sort((a, b) =>
        a.localeCompare(b, 'en', { sensitivity: 'base' }),
      );
      assert.deepStrictEqual(
        titles,
        sorted,
        'Titles should be sorted: ' + titles.join(' | '),
      );
    }
  });

  it('Security Posture appears before Reporting & Export in sidebar order', () => {
    const si = catalogCategoryOrder.indexOf('Security Posture');
    const ri = catalogCategoryOrder.indexOf('Reporting & Export');
    assert.ok(si >= 0 && ri >= 0);
    assert.ok(si < ri, 'Security should precede Reporting');
  });

  it('export OWASP report is categorized under Security Posture', () => {
    const e = catalogEntries.find((x) => x.command === 'saropaLints.exportOwaspReport');
    assert.ok(e);
    assert.strictEqual(e.category, 'Security Posture');
  });

  it('show output is categorized under Analysis', () => {
    const e = catalogEntries.find((x) => x.command === 'saropaLints.showOutput');
    assert.ok(e);
    assert.strictEqual(e.category, 'Analysis');
  });
});

describe('buildCatalogSearchBlob', () => {
  it('indexes description so queries match help text, not only titles', () => {
    const blob = buildCatalogSearchBlob({
      command: 'saropaLints.runAnalysis',
      title: 'Run Analysis',
      description: 'Analyze the current project and refresh violation data.',
      category: 'Analysis',
      icon: 'play',
    });
    assert.ok(blob.includes('analyze the current project'));
  });

  it('indexes dotted id and spaced tokens for fragment queries', () => {
    const blob = buildCatalogSearchBlob({
      command: 'saropaLints.runAnalysis',
      title: 'Run Analysis',
      description: 'x',
      category: 'Analysis',
      icon: 'play',
    });
    // Command ids use camelCase; toLowerCase() does not insert underscores.
    assert.ok(blob.includes('saropalints.runanalysis'));
    assert.ok(blob.includes('saropalints runanalysis'));
    assert.ok(blob.includes('run analysis'));
  });
});
