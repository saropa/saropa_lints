/**
 * Unit tests for {@link computeBaselineDiff} — the deferred Phase 4 "diff" requirement for the
 * Config file tab's Baseline card (create + view already existed; this pins the new diff logic
 * that compares the baseline file's (file, rule, line) entries against a live violation set).
 */
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as assert from 'assert';
import { computeBaselineDiff } from '../../rulePacks/baselineReader';

/** Writes a minimal `saropa_baseline.json` matching `lib/src/baseline/baseline_file.dart`'s shape. */
function writeBaseline(root: string, violations: Record<string, Record<string, number[]>>): void {
  fs.writeFileSync(
    path.join(root, 'saropa_baseline.json'),
    JSON.stringify({ version: 1, generated: '2026-01-01T00:00:00.000Z', violations }),
    'utf-8',
  );
}

describe('computeBaselineDiff', () => {
  it('returns undefined when no baseline file exists', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-baseline-diff-'));
    try {
      assert.strictEqual(computeBaselineDiff(root, []), undefined);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  it('reports no drift when the live set matches the baseline exactly', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-baseline-diff-'));
    try {
      writeBaseline(root, { 'lib/foo.dart': { avoid_print: [10, 20] } });
      const diff = computeBaselineDiff(root, [
        { file: 'lib/foo.dart', rule: 'avoid_print', line: 10 },
        { file: 'lib/foo.dart', rule: 'avoid_print', line: 20 },
      ]);
      assert.ok(diff);
      assert.strictEqual(diff.resolvedCount, 0);
      assert.strictEqual(diff.newCount, 0);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  it('classifies a baselined violation no longer present as resolved', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-baseline-diff-'));
    try {
      writeBaseline(root, { 'lib/foo.dart': { avoid_print: [10] } });
      // Empty live set — the line 10 finding was fixed since the baseline was taken.
      const diff = computeBaselineDiff(root, []);
      assert.ok(diff);
      assert.strictEqual(diff.resolvedCount, 1);
      assert.deepStrictEqual(diff.resolved[0], { file: 'lib/foo.dart', rule: 'avoid_print', line: 10 });
      assert.strictEqual(diff.newCount, 0);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  it('classifies a live violation absent from the baseline as new-since', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-baseline-diff-'));
    try {
      writeBaseline(root, { 'lib/foo.dart': { avoid_print: [10] } });
      const diff = computeBaselineDiff(root, [
        { file: 'lib/foo.dart', rule: 'avoid_print', line: 10 },
        // Never baselined — introduced after the snapshot.
        { file: 'lib/bar.dart', rule: 'prefer_final', line: 5 },
      ]);
      assert.ok(diff);
      assert.strictEqual(diff.resolvedCount, 0);
      assert.strictEqual(diff.newCount, 1);
      assert.deepStrictEqual(diff.newSince[0], { file: 'lib/bar.dart', rule: 'prefer_final', line: 5 });
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  it('distinguishes same file+rule at a different line (line is part of the identity key)', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-baseline-diff-'));
    try {
      writeBaseline(root, { 'lib/foo.dart': { avoid_print: [10] } });
      // Same file/rule, but the line moved — must count as resolved AND new, not "unchanged",
      // since the (file, rule, line) triple is the baseline's unit of identity, not (file, rule).
      const diff = computeBaselineDiff(root, [{ file: 'lib/foo.dart', rule: 'avoid_print', line: 11 }]);
      assert.ok(diff);
      assert.strictEqual(diff.resolvedCount, 1);
      assert.strictEqual(diff.newCount, 1);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  it('caps each bucket at 50 rows but reports the true count', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-baseline-diff-'));
    try {
      // 60 baselined lines, none present live — 60 resolved entries, only 50 rendered.
      const lines = Array.from({ length: 60 }, (_, i) => i + 1);
      writeBaseline(root, { 'lib/foo.dart': { avoid_print: lines } });
      const diff = computeBaselineDiff(root, []);
      assert.ok(diff);
      assert.strictEqual(diff.resolvedCount, 60);
      assert.strictEqual(diff.resolved.length, 50);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  it('gracefully ignores a malformed baseline file (missing violations key)', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-baseline-diff-'));
    try {
      fs.writeFileSync(path.join(root, 'saropa_baseline.json'), JSON.stringify({ version: 1 }), 'utf-8');
      const diff = computeBaselineDiff(root, [{ file: 'lib/foo.dart', rule: 'avoid_print', line: 1 }]);
      assert.ok(diff);
      // No baseline entries at all → everything live is "new since baseline".
      assert.strictEqual(diff.resolvedCount, 0);
      assert.strictEqual(diff.newCount, 1);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
});
