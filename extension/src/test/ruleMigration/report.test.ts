import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';
import type { MigrationReport } from '../../ruleMigration/applyMigration';
import { listSome, reportParts, selectChanges, summarizeScan } from '../../ruleMigration/report';
import type { FileChange } from '../../ruleMigration/scanner';
import { catalogEntries } from '../../views/commandCatalogRegistry';

const change = (file: string, before: string, after: string, hits: number): FileChange => ({
  file,
  before,
  after,
  hits,
  findings: [],
});

describe('ruleMigration report', () => {
  const changes = [change('/a.dart', 'x', 'y', 2), change('/b.dart', 'x', 'x', 0), change('/c.yaml', 'x', 'z', 1)];

  it('summarizes only files that change', () => {
    const s = summarizeScan({ changes });
    assert.deepStrictEqual(s.files.map((f) => f.file), ['/a.dart', '/c.yaml']);
    assert.strictEqual(s.hits, 3);
  });

  it('selects picked files, or all when none given', () => {
    assert.deepStrictEqual(selectChanges(changes, new Set(['/c.yaml'])).map((c) => c.file), ['/c.yaml']);
    assert.strictEqual(selectChanges(changes).length, 3);
  });

  it('splits findings and skipped files for the result message', () => {
    const r: MigrationReport = {
      status: 'applied',
      filesChanged: ['/p/a.dart'],
      hits: 1,
      findings: [
        { kind: 'bareName', name: 'foo', line: 3, file: '/p/a.dart' },
        { kind: 'clash', name: 'bar', line: 9, file: '/p/o.yaml' },
      ],
      skipped: [{ file: '/p/g.g.dart', reason: 'generated' }],
    };
    const p = reportParts(r, (f) => path.basename(f));
    assert.deepStrictEqual(p.changedFiles, ['a.dart']);
    assert.deepStrictEqual(p.bareNames, ['foo (a.dart:3)']);
    assert.deepStrictEqual(p.clashes, ['bar (o.yaml:9)']);
    assert.deepStrictEqual(p.skipped, ['g.g.dart (generated)']);
  });

  it('truncates long lists', () => {
    assert.strictEqual(listSome(['a', 'b', 'c'], 2), 'a, b, +1');
    assert.strictEqual(listSome(['a'], 2), 'a');
  });
});

describe('saropaLints.migrateRuleNames wiring', () => {
  const id = 'saropaLints.migrateRuleNames';
  const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '../../../package.json'), 'utf8')) as {
    contributes: { commands: { command: string; title: string }[] };
  };

  it('is declared in package.json with a localized title', () => {
    const c = pkg.contributes.commands.find((x) => x.command === id);
    assert.ok(c);
    assert.strictEqual(c.title, '%command.migrateRuleNames.title%');
  });

  it('is in the command catalog', () => {
    assert.ok(catalogEntries.some((e) => e.command === id));
  });
});
