import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as assert from 'assert';
import {
  parseAnalyzerExcludes,
  mergeExclusions,
  readAnalyzerExcludes,
  writeAnalyzerExcludes,
} from '../../analysisOptimizer/analyzerExcludeYaml';

function withTempProject(analysisOptionsContent: string, fn: (root: string) => void): void {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-analyzer-exclude-'));
  try {
    fs.writeFileSync(path.join(root, 'analysis_options.yaml'), analysisOptionsContent, 'utf8');
    fn(root);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

describe('analyzerExcludeYaml', () => {
  it('parseAnalyzerExcludes reads a standard list block', () => {
    const yaml = `
analyzer:
  exclude:
    - build/**
    - "**/*.g.dart"
  language:
    strict-casts: true
`;
    assert.deepStrictEqual(parseAnalyzerExcludes(yaml), ['build/**', '**/*.g.dart']);
  });

  it('parseAnalyzerExcludes returns empty when no analyzer key exists', () => {
    assert.deepStrictEqual(parseAnalyzerExcludes('linter:\n  rules:\n    - avoid_print\n'), []);
  });

  it('parseAnalyzerExcludes returns empty when analyzer has no exclude child', () => {
    const yaml = 'analyzer:\n  language:\n    strict-casts: true\n';
    assert.deepStrictEqual(parseAnalyzerExcludes(yaml), []);
  });

  it('parseAnalyzerExcludes preserves other analyzer children unaffected', () => {
    const yaml = `
analyzer:
  language:
    strict-casts: true
  exclude:
    - build/**
  errors:
    todo: ignore
`;
    assert.deepStrictEqual(parseAnalyzerExcludes(yaml), ['build/**']);
  });

  it('parseAnalyzerExcludes reads inline array syntax without data loss', () => {
    const yaml = 'analyzer:\n  exclude: [build/**, "**/*.g.dart"]\n';
    assert.deepStrictEqual(parseAnalyzerExcludes(yaml), ['build/**', '**/*.g.dart']);
  });

  it('parseAnalyzerExcludes skips comment lines inside the block', () => {
    const yaml = `
analyzer:
  exclude:
    # generated code
    - build/**
    - "**/*.g.dart"
`;
    assert.deepStrictEqual(parseAnalyzerExcludes(yaml), ['build/**', '**/*.g.dart']);
  });

  it('parseAnalyzerExcludes strips an inline comment after a quoted pattern', () => {
    const yaml = 'analyzer:\n  exclude:\n    - "**/*.g.dart" # Exclude generated files\n';
    assert.deepStrictEqual(parseAnalyzerExcludes(yaml), ['**/*.g.dart']);
  });

  it('parseAnalyzerExcludes strips a stray trailing quote before an inline comment', () => {
    // Real-world malformed entry: no opening quote, but a trailing `"` before
    // the comment. Per YAML's rules this is the literal scalar `**/*.g.dart"`
    // followed by a comment — the trailing quote must be stripped for this
    // to compare equal to the clean pattern the optimizer generates.
    const yaml = 'analyzer:\n  exclude:\n    - **/*.g.dart" # Exclude generated files (frozen Isar)\n';
    assert.deepStrictEqual(parseAnalyzerExcludes(yaml), ['**/*.g.dart']);
  });

  it('parseAnalyzerExcludes dedupes a pattern that appears twice with different comments', () => {
    const yaml = `
analyzer:
  exclude:
    - **/*.g.dart
    - **/*.g.dart" # Exclude generated files (frozen Isar)
    - build/**
`;
    assert.deepStrictEqual(parseAnalyzerExcludes(yaml), ['**/*.g.dart', 'build/**']);
  });

  it('writeAnalyzerExcludes recognizes a comment-decorated existing pattern and does not duplicate it', () => {
    withTempProject(
      'analyzer:\n  exclude:\n    - **/*.g.dart" # Exclude generated files (frozen Isar)\n    - .dart_tool/**\n',
      (root) => {
        const existing = readAnalyzerExcludes(root);
        assert.deepStrictEqual(existing, ['**/*.g.dart', '.dart_tool/**']);
        // Simulates applying the same already-present pattern again, as the
        // optimizer would if it failed to detect the existing entry.
        const merged = mergeExclusions(existing, ['**/*.g.dart']);
        const ok = writeAnalyzerExcludes(root, merged);
        assert.strictEqual(ok, true);
        const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
        const occurrences = content.match(/\*\*\/\*\.g\.dart/g) ?? [];
        assert.strictEqual(occurrences.length, 1, 'pattern must not be duplicated on write');
      },
    );
  });

  it('writeAnalyzerExcludes preserves the original comment for an unchanged pattern', () => {
    withTempProject(
      'analyzer:\n  exclude:\n    - "**/*.g.dart" # Exclude generated files\n',
      (root) => {
        const existing = readAnalyzerExcludes(root);
        const merged = mergeExclusions(existing, ['build/**']);
        writeAnalyzerExcludes(root, merged);
        const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
        assert.match(content, /# Exclude generated files/);
      },
    );
  });

  it('mergeExclusions dedupes and sorts', () => {
    const result = mergeExclusions(['build/**'], ['build/**', 'lib/gen/**']);
    assert.deepStrictEqual(result, ['build/**', 'lib/gen/**']);
  });

  it('mergeExclusions drops patterns subsumed by a broader directory glob', () => {
    const result = mergeExclusions([], ['build/**', 'build/generated/**']);
    assert.deepStrictEqual(result, ['build/**']);
  });

  it('mergeExclusions keeps unrelated file-suffix globs alongside directory globs', () => {
    const result = mergeExclusions([], ['build/**', '**/*.g.dart']);
    assert.deepStrictEqual(result, ['**/*.g.dart', 'build/**']);
  });

  it('writeAnalyzerExcludes inserts a new analyzer.exclude block when none exists', () => {
    withTempProject('linter:\n  rules:\n    - avoid_print\n', (root) => {
      const ok = writeAnalyzerExcludes(root, ['build/**']);
      assert.strictEqual(ok, true);
      assert.deepStrictEqual(readAnalyzerExcludes(root), ['build/**']);
    });
  });

  it('writeAnalyzerExcludes replaces an existing block without touching other analyzer children', () => {
    withTempProject(
      'analyzer:\n  language:\n    strict-casts: true\n  exclude:\n    - old/**\n  errors:\n    todo: ignore\n',
      (root) => {
        const ok = writeAnalyzerExcludes(root, ['build/**', 'lib/gen/**']);
        assert.strictEqual(ok, true);
        const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
        assert.match(content, /strict-casts: true/);
        assert.match(content, /todo: ignore/);
        assert.deepStrictEqual(readAnalyzerExcludes(root), ['build/**', 'lib/gen/**']);
      },
    );
  });

  it('writeAnalyzerExcludes replaces existing inline array syntax without losing it in the merge', () => {
    withTempProject('analyzer:\n  exclude: [build/**]\n', (root) => {
      const existing = readAnalyzerExcludes(root);
      const merged = mergeExclusions(existing, ['lib/gen/**']);
      const ok = writeAnalyzerExcludes(root, merged);
      assert.strictEqual(ok, true);
      assert.deepStrictEqual(readAnalyzerExcludes(root), ['build/**', 'lib/gen/**']);
    });
  });

  it('writeAnalyzerExcludes matches an existing 4-space indent unit instead of assuming 2', () => {
    withTempProject(
      'analyzer:\n    language:\n        strict-casts: true\n',
      (root) => {
        const ok = writeAnalyzerExcludes(root, ['build/**']);
        assert.strictEqual(ok, true);
        const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
        assert.match(content, /^ {4}exclude:$/m);
        assert.match(content, /^ {8}- build\/\*\*$/m);
        assert.deepStrictEqual(readAnalyzerExcludes(root), ['build/**']);
      },
    );
  });

  it('writeAnalyzerExcludes returns false when analysis_options.yaml is missing', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-analyzer-exclude-missing-'));
    try {
      assert.strictEqual(writeAnalyzerExcludes(root, ['build/**']), false);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
});
