import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as assert from 'assert';
import {
  parseAnalyzerExcludes,
  mergeExclusions,
  readAnalyzerExcludes,
  writeAnalyzerExcludes,
  hasMalformedExcludeSyntax,
  fixMalformedExcludeSyntax,
  isPatternCovered,
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

  it('isPatternCovered treats an exact match as covered', () => {
    assert.strictEqual(isPatternCovered('build/**', ['build/**']), true);
  });

  it('isPatternCovered treats a narrower path as covered by a broader dir glob', () => {
    assert.strictEqual(
      isPatternCovered('dependency_overrides/flutter_contacts/**', ['dependency_overrides/**']),
      true,
    );
  });

  it('isPatternCovered does not match an unrelated pattern', () => {
    assert.strictEqual(isPatternCovered('lib/l10n/**', ['build/**', '.dart_tool/**']), false);
  });

  it('isPatternCovered does not treat a suffix glob as covering an unrelated dir pattern', () => {
    assert.strictEqual(isPatternCovered('lib/gen/**', ['**/*.g.dart']), false);
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
        assert.match(content, /^ {8}- "build\/\*\*"$/m);
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

  it('writeAnalyzerExcludes always quotes patterns that start with **, avoiding YAML alias syntax', () => {
    // An unquoted list item starting with `*` is a YAML alias reference, not
    // a literal string — a real YAML parser rejects `- **/*.g.dart` with
    // "Undefined alias". Every written pattern must be quoted regardless of
    // whether it's brand new or an unchanged existing entry.
    withTempProject('linter:\n  rules:\n    - avoid_print\n', (root) => {
      writeAnalyzerExcludes(root, ['**/*.g.dart', 'build/**']);
      const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
      assert.match(content, /- "\*\*\/\*\.g\.dart"/);
      assert.doesNotMatch(content, /^\s*-\s+\*\*/m);
    });
  });

  it('writeAnalyzerExcludes leaves an unrelated malformed entry untouched — Fix Syntax owns re-quoting, not every write', () => {
    // Applying/removing a specific pattern must never silently rewrite OTHER
    // entries' formatting. Repairing malformed syntax is Fix Syntax's job
    // (see fixMalformedExcludeSyntax below); a normal write only ever touches
    // the lines for patterns actually being added or removed.
    withTempProject(
      'analyzer:\n  exclude:\n    - **/*.bak" # Exclude backups\n',
      (root) => {
        const existing = readAnalyzerExcludes(root);
        assert.deepStrictEqual(existing, ['**/*.bak']);
        writeAnalyzerExcludes(root, mergeExclusions(existing, ['build/**']));
        const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
        assert.match(content, /- \*\*\/\*\.bak" # Exclude backups/);
        assert.match(content, /- "build\/\*\*"/);
      },
    );
  });

  describe('surgical minimal-edit writes (comments, grouping, and order must survive)', () => {
    const ORGANIZED_FILE = `analyzer:
  exclude:
    # === Generated Code ===
    - "bugs/**"
    - "doc/**"

    - "**/*.g.dart" # Exclude generated files
    - "**/*.freezed.dart" # Exclude generated files

    # === Build & Cache ===
    - ".dart_tool/**"
    - "build/**" # Exclude Flutter build output directory
  language:
    strict-casts: true
`;

    it('applying one new pattern leaves every existing line, comment, and blank line untouched', () => {
      withTempProject(ORGANIZED_FILE, (root) => {
        const existing = readAnalyzerExcludes(root);
        writeAnalyzerExcludes(root, mergeExclusions(existing, ['lib/l10n/**']));
        const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
        assert.match(content, /# === Generated Code ===/);
        assert.match(content, /# === Build & Cache ===/);
        assert.match(content, /- "bugs\/\*\*"\n {4}- "doc\/\*\*"\n\n {4}- "\*\*\/\*\.g\.dart"/);
        assert.match(content, /- "lib\/l10n\/\*\*"/);
      });
    });

    it('removing one pattern deletes only its own line, leaving section comments and ordering intact', () => {
      withTempProject(ORGANIZED_FILE, (root) => {
        const existing = readAnalyzerExcludes(root);
        const filtered = existing.filter(p => p !== 'doc/**');
        writeAnalyzerExcludes(root, filtered);
        const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
        assert.match(content, /# === Generated Code ===/);
        assert.doesNotMatch(content, /"doc\/\*\*"/);
        assert.match(content, /- "bugs\/\*\*"\n\n {4}- "\*\*\/\*\.g\.dart"/);
      });
    });

    it('does not alphabetically resort the block — existing order is preserved', () => {
      withTempProject(ORGANIZED_FILE, (root) => {
        const existing = readAnalyzerExcludes(root);
        writeAnalyzerExcludes(root, mergeExclusions(existing, ['zzz/**']));
        const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
        const bugsIdx = content.indexOf('"bugs/**"');
        const docIdx = content.indexOf('"doc/**"');
        const gDartIdx = content.indexOf('**/*.g.dart');
        assert.ok(bugsIdx < docIdx && docIdx < gDartIdx, 'original relative order must be preserved');
      });
    });
  });

  it('parseAnalyzerExcludes takes the first exclude: block and does not crash on a duplicate key', () => {
    // Invalid YAML (a mapping key repeated) but real files sometimes end up
    // this way from a bad manual merge — must degrade gracefully, not throw.
    const yaml = `
analyzer:
  exclude:
    - first/**
  exclude:
    - second/**
`;
    assert.doesNotThrow(() => parseAnalyzerExcludes(yaml));
    assert.deepStrictEqual(parseAnalyzerExcludes(yaml), ['first/**']);
  });

  describe('hasMalformedExcludeSyntax / fixMalformedExcludeSyntax', () => {
    it('detects an unquoted block-list entry starting with **', () => {
      withTempProject('analyzer:\n  exclude:\n    - **/*.bak" # Exclude backups\n', (root) => {
        assert.strictEqual(hasMalformedExcludeSyntax(root), true);
      });
    });

    it('detects an unquoted flow-sequence (inline array) entry starting with **', () => {
      withTempProject('analyzer:\n  exclude: [build/**, **/*.g.dart]\n', (root) => {
        assert.strictEqual(hasMalformedExcludeSyntax(root), true);
      });
    });

    it('does not flag a properly quoted exclude block', () => {
      withTempProject('analyzer:\n  exclude:\n    - "**/*.g.dart"\n    - build/**\n', (root) => {
        assert.strictEqual(hasMalformedExcludeSyntax(root), false);
      });
    });

    it('does not flag an unquoted pattern that merely starts with -, ?, or : followed by more text', () => {
      // -, ?, and : are only YAML indicators when followed by whitespace or
      // end-of-value (block-sequence / explicit-key / mapping-value syntax).
      // A pattern like "-legacy/**" is a perfectly valid unquoted scalar and
      // must not be flagged, or "Fix Syntax" would offer to fix a file that
      // was never broken.
      withTempProject(
        'analyzer:\n  exclude:\n    - -legacy/**\n    - :generated/**\n    - ?maybe/**\n',
        (root) => {
          assert.strictEqual(hasMalformedExcludeSyntax(root), false);
        },
      );
    });

    it('does not flag a quoted inline array', () => {
      withTempProject('analyzer:\n  exclude: ["build/**", "**/*.g.dart"]\n', (root) => {
        assert.strictEqual(hasMalformedExcludeSyntax(root), false);
      });
    });

    it('returns false when there is no exclude block at all', () => {
      withTempProject('analyzer:\n  language:\n    strict-casts: true\n', (root) => {
        assert.strictEqual(hasMalformedExcludeSyntax(root), false);
      });
    });

    it('returns false when analysis_options.yaml is missing', () => {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-analyzer-exclude-missing-'));
      try {
        assert.strictEqual(hasMalformedExcludeSyntax(root), false);
      } finally {
        fs.rmSync(root, { recursive: true, force: true });
      }
    });

    it('fixMalformedExcludeSyntax re-quotes everything and clears the malformed flag', () => {
      withTempProject(
        'analyzer:\n  exclude:\n    - **/*.bak" # Exclude backups\n    - **/*.g.dart\n',
        (root) => {
          assert.strictEqual(hasMalformedExcludeSyntax(root), true);
          const result = fixMalformedExcludeSyntax(root);
          assert.strictEqual(result.success, true);
          assert.strictEqual(result.duplicatesRemoved, 0);
          assert.strictEqual(hasMalformedExcludeSyntax(root), false);
          assert.deepStrictEqual(readAnalyzerExcludes(root), ['**/*.bak', '**/*.g.dart']);
        },
      );
    });

    it('fixMalformedExcludeSyntax collapses a literal duplicate pattern to one entry and reports the count', () => {
      withTempProject(
        'analyzer:\n  exclude:\n    - **/*.g.dart\n    - **/*.g.dart" # Exclude generated files (frozen Isar)\n',
        (root) => {
          const result = fixMalformedExcludeSyntax(root);
          assert.strictEqual(result.success, true);
          assert.strictEqual(result.duplicatesRemoved, 1);
          const content = fs.readFileSync(path.join(root, 'analysis_options.yaml'), 'utf8');
          const occurrences = content.match(/\*\*\/\*\.g\.dart/g) ?? [];
          assert.strictEqual(occurrences.length, 1);
        },
      );
    });

    it('fixMalformedExcludeSyntax returns success:false and no count when the file is missing', () => {
      const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-analyzer-exclude-missing-'));
      try {
        assert.deepStrictEqual(fixMalformedExcludeSyntax(root), { success: false, duplicatesRemoved: 0 });
      } finally {
        fs.rmSync(root, { recursive: true, force: true });
      }
    });
  });
});
