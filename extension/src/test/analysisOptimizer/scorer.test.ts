import * as assert from 'assert';
import {
  computeFileCost,
  aggregateByFolder,
  generateRecommendations,
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

  it('generateRecommendations recommends generated-code suffix patterns by default', () => {
    const files = [
      file({ relativePath: 'lib/models/a.g.dart', isGenerated: true }),
      file({ relativePath: 'lib/models/b.g.dart', isGenerated: true }),
      file({ relativePath: 'lib/models/c.g.dart', isGenerated: true }),
    ];
    const folders = aggregateByFolder(files);
    const recs = generateRecommendations(folders, files, []);
    const gDartRec = recs.find((r) => r.pattern === '**/*.g.dart');
    assert.ok(gDartRec, 'expected a **/*.g.dart recommendation');
    assert.strictEqual(gDartRec?.estimatedFilesExcluded, 3);
    assert.strictEqual(gDartRec?.priority, 'high');
  });

  it('generateRecommendations never recommends excluding lib or lib/src', () => {
    const files = Array.from({ length: 10 }, (_, i) =>
      file({ relativePath: `lib/src/file${i}.dart`, lineCount: 500 }),
    );
    const folders = aggregateByFolder(files);
    const recs = generateRecommendations(folders, files, []);
    assert.ok(!recs.some((r) => r.pattern === 'lib/**' || r.pattern === 'lib/src/**'));
  });

  it('generateRecommendations skips patterns already covered by an existing exclusion', () => {
    const files = [file({ relativePath: 'lib/models/a.g.dart', isGenerated: true })];
    const folders = aggregateByFolder(files);
    const recs = generateRecommendations(folders, files, ['**/*.g.dart']);
    assert.ok(!recs.some((r) => r.pattern === '**/*.g.dart'));
  });

  it('generateRecommendations flags a folder with no recent edits as medium priority', () => {
    const files = Array.from({ length: 5 }, (_, i) =>
      file({ relativePath: `lib/legacy/file${i}.dart`, lineCount: 200, daysSinceLastEdit: 400 }),
    );
    const folders = aggregateByFolder(files);
    const recs = generateRecommendations(folders, files, []);
    const legacyRec = recs.find((r) => r.pattern === 'lib/legacy/**');
    assert.strictEqual(legacyRec?.priority, 'medium');
    assert.strictEqual(legacyRec?.hasActiveFiles, false);
  });

  it('generateRecommendations marks hasActiveFiles when a covering pattern includes a recently-edited file', () => {
    const files = [
      file({ relativePath: 'lib/models/a.g.dart', isGenerated: true, daysSinceLastEdit: 2 }),
    ];
    const folders = aggregateByFolder(files);
    const recs = generateRecommendations(folders, files, []);
    const gDartRec = recs.find((r) => r.pattern === '**/*.g.dart');
    assert.strictEqual(gDartRec?.hasActiveFiles, true);
  });
});
