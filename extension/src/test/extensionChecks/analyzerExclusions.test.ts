/**
 * Unit tests for the analyzer-exclusions check (pure logic only), covering the
 * four findings and the edge cases in
 * bugs/proposal_infra_analyzer_exclude_folders_check.md.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import {
  addableFolders,
  evaluateAnalyzerExclusions,
  parseAnalyzerExclude,
  parsePathDependencies,
  RunToken,
  ExclusionInputs,
} from '../../analyzerExclusions';

function inputs(over: Partial<ExclusionInputs>): ExclusionInputs {
  return {
    existingFolders: [],
    dartFileCounts: {},
    settingsExcluded: [],
    analysisOptionsExcluded: [],
    pathDependencies: [],
    ramGb: 16,
    ...over,
  };
}

describe('analyzerExclusions: evaluateAnalyzerExclusions', () => {
  it('finding 1: candidate folder missing from settings', () => {
    const f = evaluateAnalyzerExclusions(inputs({ existingFolders: ['android', 'ios', 'lib'] }));
    assert.deepStrictEqual(f.map((x) => [x.kind, x.folder]), [['missing', 'android'], ['missing', 'ios']]);
  });

  it('finding 2: excluded only in analysis_options.yaml', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['android', 'custom_gen'],
      analysisOptionsExcluded: ['android', 'custom_gen'],
    }));
    assert.deepStrictEqual(f.map((x) => [x.kind, x.folder]), [['driftOnly', 'android'], ['driftOnly', 'custom_gen']]);
  });

  it('finding 3: many files and low RAM names both numbers', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['lib'], dartFileCounts: { lib: 3500 }, ramGb: 8,
    }));
    assert.deepStrictEqual(f, [{ kind: 'largeWorkspace', fileCount: 3500, ramGb: 8 }]);
  });

  it('finding 3: no finding with ample RAM or at/below threshold', () => {
    assert.deepStrictEqual(evaluateAnalyzerExclusions(inputs({
      existingFolders: ['lib'], dartFileCounts: { lib: 9000 }, ramGb: 32,
    })), []);
    assert.deepStrictEqual(evaluateAnalyzerExclusions(inputs({
      existingFolders: ['lib'], dartFileCounts: { lib: 3000 }, ramGb: 4,
    })), []);
  });

  it('edge 5: RAM unavailable reports the file count only', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['lib'], dartFileCounts: { lib: 4000 }, ramGb: undefined,
    }));
    assert.deepStrictEqual(f, [{ kind: 'largeWorkspace', fileCount: 4000 }]);
  });

  it('settings-excluded folders do not count toward analyzed files', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['lib', 'dependency_overrides'],
      dartFileCounts: { lib: 2000, dependency_overrides: 5000 },
      settingsExcluded: ['dependency_overrides'],
      ramGb: 8,
    }));
    assert.deepStrictEqual(f, []);
  });

  it('finding 4: imported candidate is not suggested', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['third_party', 'vendor'],
      pathDependencies: ['third_party/foo'],
    }));
    assert.deepStrictEqual(f.map((x) => [x.kind, x.folder]), [['imported', 'third_party'], ['missing', 'vendor']]);
    assert.deepStrictEqual(addableFolders(f), ['vendor']);
  });

  it('passes when all candidates are already listed (also via parent entry)', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['android', 'ios', '.claude/worktrees'],
      settingsExcluded: ['android/', './ios', '.claude'],
    }));
    assert.deepStrictEqual(f, []);
  });

  it('edge 3: test and lib are never candidates, even when excluded in analysis_options', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['test', 'lib'], analysisOptionsExcluded: ['test', 'lib'],
    }));
    assert.deepStrictEqual(f, []);
  });

  it('absent candidate folders produce no finding; agent worktrees are a candidate', () => {
    const f = evaluateAnalyzerExclusions(inputs({ existingFolders: ['lib', '.claude/worktrees'] }));
    assert.deepStrictEqual(f.map((x) => x.folder), ['.claude/worktrees']);
  });
});

describe('analyzerExclusions: parseAnalyzerExclude', () => {
  it('keeps plain folders, strips glob tails, drops file globs', () => {
    const yaml = [
      'include: package:x/y.yaml',
      'analyzer:',
      '  errors:',
      '    foo: ignore',
      '  exclude:',
      '    - "android/**"',
      '    - ./ios/ # comment',
      '    - "**/*.g.dart"',
      '    - build/*',
      '  plugins:',
      '    - saropa_lints',
      'linter:',
      '  exclude:',
      '    - nope',
    ].join('\n');
    assert.deepStrictEqual(parseAnalyzerExclude(yaml), ['android', 'ios', 'build']);
  });

  it('supports inline lists and a missing analyzer block', () => {
    assert.deepStrictEqual(parseAnalyzerExclude('analyzer:\n  exclude: [docs/**, "bugs"]\n'), ['docs', 'bugs']);
    assert.deepStrictEqual(parseAnalyzerExclude(''), []);
  });
});

describe('analyzerExclusions: parsePathDependencies', () => {
  it('reads path deps from dependencies and dev_dependencies only', () => {
    const yaml = [
      'name: app',
      'dependencies:',
      '  flutter:',
      '    sdk: flutter',
      '  local_a:',
      '    path: third_party/local_a',
      '  local_b: {path: ../sibling}',
      'dev_dependencies:',
      '  tool:',
      '    path: ./vendor/tool/',
      'dependency_overrides:',
      '  other:',
      '    path: dependency_overrides/other',
    ].join('\n');
    assert.deepStrictEqual(parsePathDependencies(yaml), ['third_party/local_a', '../sibling', 'vendor/tool']);
  });
});

describe('analyzerExclusions: nested excluded folders in file count', () => {
  it('subtracts a nested excluded folder from the analyzed total', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['lib'],
      dartFileCounts: { lib: 3500 },
      settingsExcluded: ['lib/generated'],
      nestedExcludedCounts: { 'lib/generated': 1000 },
      ramGb: undefined,
    }));
    assert.strictEqual(f.length, 0, '2500 analyzed is under the threshold');
  });

  it('still reports when the remainder exceeds the threshold', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['lib'],
      dartFileCounts: { lib: 5000 },
      settingsExcluded: ['lib/generated'],
      nestedExcludedCounts: { 'lib/generated': 1000 },
      ramGb: undefined,
    }));
    assert.strictEqual(f[0].fileCount, 4000);
  });

  it('does not double-subtract an entry nested in another excluded entry', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['lib'],
      dartFileCounts: { lib: 4000 },
      settingsExcluded: ['lib/gen', 'lib/gen/deep'],
      nestedExcludedCounts: { 'lib/gen': 500, 'lib/gen/deep': 200 },
      ramGb: undefined,
    }));
    assert.strictEqual(f[0].fileCount, 3500);
  });

  it('ignores nested entries under a fully excluded top-level folder', () => {
    const f = evaluateAnalyzerExclusions(inputs({
      existingFolders: ['lib', 'docs'],
      dartFileCounts: { lib: 3100, docs: 50 },
      settingsExcluded: ['docs', 'docs/x'],
      nestedExcludedCounts: { 'docs/x': 40 },
      ramGb: undefined,
    }));
    assert.strictEqual(f[0].fileCount, 3100);
  });
});

describe('analyzerExclusions: RunToken', () => {
  it('only the latest run is current', () => {
    const t = new RunToken();
    const a = t.next();
    assert.strictEqual(t.isLatest(a), true);
    const b = t.next();
    assert.strictEqual(t.isLatest(a), false);
    assert.strictEqual(t.isLatest(b), true);
  });
});
