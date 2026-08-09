import * as assert from 'assert';
import {
  computeFileCost,
  aggregateByFolder,
  buildExclusionRows,
  matchExclusionPattern,
} from '../../analysisOptimizer/scorer';
import type { FileAnalysisMetrics } from '../../analysisOptimizer/types';

function file(overrides: Partial<FileAnalysisMetrics>): FileAnalysisMetrics {
  return {
    relativePath: 'lib/foo.dart',
    lineCount: 10,
    classCount: 0,
    functionCount: 0,
    importCount: 0,
    hasWidgets: false,
    hasAsyncCode: false,
    isGenerated: false,
    daysSinceLastEdit: undefined,
    ...overrides,
  };
}

describe('scorer', () => {
  it('computeFileCost scales with lines, classes, functions, imports', () => {
    const base = computeFileCost(file({ lineCount: 100 }));
    const withClasses = computeFileCost(file({ lineCount: 100, classCount: 2 }));
    assert.ok(withClasses > base);
  });

  it('computeFileCost applies a widget multiplier', () => {
    const plain = computeFileCost(file({ lineCount: 100 }));
    const widget = computeFileCost(file({ lineCount: 100, hasWidgets: true }));
    assert.ok(widget > plain);
  });

  it('aggregateByFolder groups files by their first two path segments', () => {
    const files = [
      file({ relativePath: 'lib/src/a.dart', lineCount: 50 }),
      file({ relativePath: 'lib/src/b.dart', lineCount: 50 }),
      file({ relativePath: 'test/a_test.dart', lineCount: 20 }),
    ];
    const folders = aggregateByFolder(files);
    const libSrc = folders.find((f) => f.folderPath === 'lib/src');
    const test = folders.find((f) => f.folderPath === 'test');
    assert.strictEqual(libSrc?.fileCount, 2);
    assert.strictEqual(test?.fileCount, 1);
  });

  it('aggregateByFolder sorts folders by descending total cost', () => {
    const files = [
      file({ relativePath: 'lib/small/a.dart', lineCount: 10 }),
      file({ relativePath: 'lib/big/a.dart', lineCount: 1000, classCount: 10 }),
    ];
    const folders = aggregateByFolder(files);
    assert.strictEqual(folders[0].folderPath, 'lib/big');
  });

  it('aggregateByFolder computes recentEditRatio from daysSinceLastEdit', () => {
    const files = [
      file({ relativePath: 'lib/a/x.dart', daysSinceLastEdit: 5 }),
      file({ relativePath: 'lib/a/y.dart', daysSinceLastEdit: 60 }),
    ];
    const folders = aggregateByFolder(files);
    assert.strictEqual(folders[0].recentEditRatio, 0.5);
  });

  describe('matchExclusionPattern', () => {
    it('matches a suffix glob against file extension', () => {
      const files = [
        file({ relativePath: 'lib/a.g.dart' }),
        file({ relativePath: 'lib/b.g.dart' }),
        file({ relativePath: 'lib/c.dart' }),
      ];
      const result = matchExclusionPattern(files, '**/*.g.dart');
      assert.strictEqual(result.filesMatched, 2);
    });

    it('matches a directory glob against path prefix', () => {
      const files = [
        file({ relativePath: 'lib/gen/a.dart' }),
        file({ relativePath: 'lib/gen/sub/b.dart' }),
        file({ relativePath: 'lib/other.dart' }),
      ];
      const result = matchExclusionPattern(files, 'lib/gen/**');
      assert.strictEqual(result.filesMatched, 2);
    });

    it('falls back to exact-path match for arbitrary patterns', () => {
      const files = [
        file({ relativePath: 'lib/generated_plugin_registrant.dart' }),
        file({ relativePath: 'lib/other.dart' }),
      ];
      const result = matchExclusionPattern(files, 'lib/generated_plugin_registrant.dart');
      assert.strictEqual(result.filesMatched, 1);
    });

    it('reports hasActiveFiles when a matched file was edited within 7 days', () => {
      const files = [file({ relativePath: 'lib/a.g.dart', daysSinceLastEdit: 2 })];
      const result = matchExclusionPattern(files, '**/*.g.dart');
      assert.strictEqual(result.hasActiveFiles, true);
    });
  });

  describe('buildExclusionRows', () => {
    it('recommends generated-code suffix patterns by default', () => {
      const files = [
        file({ relativePath: 'lib/models/a.g.dart', isGenerated: true }),
        file({ relativePath: 'lib/models/b.g.dart', isGenerated: true }),
        file({ relativePath: 'lib/models/c.g.dart', isGenerated: true }),
      ];
      const folders = aggregateByFolder(files);
      const rows = buildExclusionRows(folders, files, []);
      const gDartRow = rows.find((r) => r.pattern === '**/*.g.dart');
      assert.ok(gDartRow, 'expected a **/*.g.dart row');
      assert.strictEqual(gDartRow?.estimatedFilesExcluded, 3);
      assert.strictEqual(gDartRow?.priority, 'high');
      assert.strictEqual(gDartRow?.isApplied, false);
    });

    it('never recommends excluding lib or lib/src', () => {
      const files = Array.from({ length: 10 }, (_, i) =>
        file({ relativePath: `lib/src/file${i}.dart`, lineCount: 500 }),
      );
      const folders = aggregateByFolder(files);
      const rows = buildExclusionRows(folders, files, []);
      assert.ok(!rows.some((r) => r.pattern === 'lib/**' || r.pattern === 'lib/src/**'));
    });

    it('marks an existing exclusion as applied instead of hiding it', () => {
      const files = [file({ relativePath: 'lib/models/a.g.dart', isGenerated: true })];
      const folders = aggregateByFolder(files);
      const rows = buildExclusionRows(folders, files, ['**/*.g.dart']);
      const gDartRow = rows.find((r) => r.pattern === '**/*.g.dart');
      assert.ok(gDartRow, 'applied pattern must still appear in the table');
      assert.strictEqual(gDartRow?.isApplied, true);
    });

    it('does not duplicate a pattern that is both a default candidate and already applied', () => {
      const files = [file({ relativePath: 'lib/models/a.g.dart', isGenerated: true })];
      const folders = aggregateByFolder(files);
      const rows = buildExclusionRows(folders, files, ['**/*.g.dart']);
      const matches = rows.filter((r) => r.pattern === '**/*.g.dart');
      assert.strictEqual(matches.length, 1);
    });

    it('includes a hand-added exclusion with no matching generated candidate', () => {
      const files = [file({ relativePath: 'lib/main.dart' })];
      const folders = aggregateByFolder(files);
      const rows = buildExclusionRows(folders, files, ['plans/**']);
      const custom = rows.find((r) => r.pattern === 'plans/**');
      assert.ok(custom, 'hand-added exclusion must appear in the table');
      assert.strictEqual(custom?.isApplied, true);
    });

    it('flags a folder with no recent edits as medium priority', () => {
      const files = Array.from({ length: 5 }, (_, i) =>
        file({ relativePath: `lib/legacy/file${i}.dart`, lineCount: 200, daysSinceLastEdit: 400 }),
      );
      const folders = aggregateByFolder(files);
      const rows = buildExclusionRows(folders, files, []);
      const legacyRow = rows.find((r) => r.pattern === 'lib/legacy/**');
      assert.strictEqual(legacyRow?.priority, 'medium');
      assert.strictEqual(legacyRow?.hasActiveFiles, false);
    });

    it('marks hasActiveFiles when a covering pattern includes a recently-edited file', () => {
      const files = [
        file({ relativePath: 'lib/models/a.g.dart', isGenerated: true, daysSinceLastEdit: 2 }),
      ];
      const folders = aggregateByFolder(files);
      const rows = buildExclusionRows(folders, files, []);
      const gDartRow = rows.find((r) => r.pattern === '**/*.g.dart');
      assert.strictEqual(gDartRow?.hasActiveFiles, true);
    });

    it('sorts recommended rows before applied rows', () => {
      const files = [
        file({ relativePath: 'lib/models/a.g.dart', isGenerated: true }),
        file({ relativePath: 'plans/notes.dart' }),
      ];
      const folders = aggregateByFolder(files);
      const rows = buildExclusionRows(folders, files, ['plans/**']);
      const firstAppliedIndex = rows.findIndex((r) => r.isApplied);
      const lastRecommendedIndex = rows.map((r) => r.isApplied).lastIndexOf(false);
      assert.ok(firstAppliedIndex === -1 || lastRecommendedIndex < firstAppliedIndex);
    });
  });
});
