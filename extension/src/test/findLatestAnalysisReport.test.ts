// Tests for findLatestAnalysisReport — the helper that powers the
// "Copy Report" / "Open Report" buttons on the post-analysis popup.
//
// Uses a per-test scratch directory under os.tmpdir() and `fs.utimesSync`
// to pin mtimes deterministically, since the helper resolves the newest
// report by mtime (not filename) so runs within the same second still
// disambiguate correctly.

import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';

import { findLatestAnalysisReport } from '../reportWriter';

function makeTempRoot(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-report-finder-'));
}

function writeFileWithMtime(filePath: string, content: string, mtimeMs: number): void {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, 'utf-8');
  const mtime = new Date(mtimeMs);
  fs.utimesSync(filePath, mtime, mtime);
}

function rmRecursive(dir: string): void {
  fs.rmSync(dir, { recursive: true, force: true });
}

describe('findLatestAnalysisReport', () => {
  let root: string;

  beforeEach(() => {
    root = makeTempRoot();
  });

  afterEach(() => {
    rmRecursive(root);
  });

  it('returns undefined when reports/ does not exist', () => {
    assert.strictEqual(findLatestAnalysisReport(root), undefined);
  });

  it('returns undefined when reports/ exists but has no matching files', () => {
    fs.mkdirSync(path.join(root, 'reports', '20260424'), { recursive: true });
    fs.writeFileSync(
      path.join(root, 'reports', '20260424', 'something_else.txt'),
      'noise',
      'utf-8',
    );
    assert.strictEqual(findLatestAnalysisReport(root), undefined);
  });

  it('returns the sole matching report when only one exists', () => {
    const target = path.join(root, 'reports', '20260424', '20260424_093000_saropa_lint_report.log');
    writeFileWithMtime(target, 'body', Date.UTC(2026, 3, 24, 9, 30, 0));
    assert.strictEqual(findLatestAnalysisReport(root), target);
  });

  it('picks the newest by mtime when multiple reports exist in the same date folder', () => {
    const dateFolder = path.join(root, 'reports', '20260424');
    const older = path.join(dateFolder, '20260424_093000_saropa_lint_report.log');
    const newer = path.join(dateFolder, '20260424_135316_saropa_lint_report.log');
    writeFileWithMtime(older, 'old', Date.UTC(2026, 3, 24, 9, 30, 0));
    writeFileWithMtime(newer, 'new', Date.UTC(2026, 3, 24, 13, 53, 16));
    assert.strictEqual(findLatestAnalysisReport(root), newer);
  });

  it('scans across date folders, not just today', () => {
    // Regression for the near-midnight case where today's folder is empty
    // but yesterday's has the most recent report — caller wants THAT one,
    // not "undefined because today/ is empty".
    const yesterday = path.join(root, 'reports', '20260423', 'yesterday_saropa_lint_report.log');
    const today = path.join(root, 'reports', '20260424', 'today_saropa_lint_report.log');
    writeFileWithMtime(yesterday, 'y', Date.UTC(2026, 3, 23, 23, 59, 0));
    writeFileWithMtime(today, 't', Date.UTC(2026, 3, 24, 0, 0, 5));
    assert.strictEqual(findLatestAnalysisReport(root), today);
  });

  it('ignores hidden / system dot-folders like .saropa_lints', () => {
    // `.saropa_lints` is where the plugin writes `violations.json`; it is
    // NOT where the human-readable report lives, and we must not mistake
    // a stray file there for the report.
    const hiddenChild = path.join(
      root,
      'reports',
      '.saropa_lints',
      'fake_saropa_lint_report.log',
    );
    const realChild = path.join(
      root,
      'reports',
      '20260424',
      'real_saropa_lint_report.log',
    );
    writeFileWithMtime(hiddenChild, 'hidden', Date.UTC(2026, 3, 25, 0, 0, 0));
    writeFileWithMtime(realChild, 'real', Date.UTC(2026, 3, 24, 12, 0, 0));
    // Hidden has NEWER mtime, but we must skip dot-prefixed folders.
    assert.strictEqual(findLatestAnalysisReport(root), realChild);
  });

  it('ignores non-matching filenames even when they are newer', () => {
    const dateFolder = path.join(root, 'reports', '20260424');
    const report = path.join(dateFolder, '20260424_090000_saropa_lint_report.log');
    const extension = path.join(dateFolder, '20260424_100000_saropa_extension.md');
    writeFileWithMtime(report, 'r', Date.UTC(2026, 3, 24, 9, 0, 0));
    writeFileWithMtime(extension, 'e', Date.UTC(2026, 3, 24, 10, 0, 0));
    // Extension .md is newer but does NOT end with _saropa_lint_report.log,
    // so it must not be returned.
    assert.strictEqual(findLatestAnalysisReport(root), report);
  });
});
