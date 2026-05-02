/**
 * Structural snapshot harness for editor-area webview HTML.
 *
 * Captures a **normalized** form of a dashboard's rendered HTML so contributors
 * get a deterministic baseline they can diff against. Normalization strips:
 *
 *   - the CSP nonce (changes on every render)
 *   - inline `<script>` and `<style>` block contents (covered by token-matrix
 *     and individual unit tests; including them here would make every
 *     snapshot churn on every chrome edit)
 *   - extension version stamps
 *   - timestamp values that move on every render (replaced by `<TS>`)
 *
 * What survives normalization is the **structural skeleton**: the element
 * tree, class names, data attributes, the order of sections, and any
 * substantive text content. That is exactly what a structural regression
 * needs to be visible in.
 *
 * Use [normalizeForSnapshot] from a Mocha test:
 *
 * ```ts
 * const html = buildMyDashboardHtml(payload);
 * const normalized = normalizeForSnapshot(html);
 * assertSnapshot(normalized, 'my-dashboard.snapshot.txt', { update: process.env.UPDATE_SNAPSHOTS === '1' });
 * ```
 *
 * Set `UPDATE_SNAPSHOTS=1` in the environment to overwrite baselines on
 * intentional changes; CI runs without the flag, so unintended drift fails.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import * as assert from 'node:assert';

/**
 * Strip every per-render value that would otherwise produce noisy diffs
 * even when the structural content is unchanged.
 */
export function normalizeForSnapshot(html: string): string {
  let s = html;

  // CSP nonce — different on every render.
  s = s.replace(/nonce="[^"]+"/g, 'nonce="<NONCE>"');
  s = s.replace(/'nonce-[^']+'/g, "'nonce-<NONCE>'");

  // Inline <script>...</script> blocks: replaced by a stub so the test
  // captures their PRESENCE, not their content. Per-script tests cover
  // behavior; the snapshot covers structure.
  s = s.replace(/<script\b[^>]*>[\s\S]*?<\/script>/g, '<script><STRIPPED></script>');

  // Inline <style>...</style> blocks: same rationale. Token matrix covers
  // theme bindings; this snapshot covers HTML structure.
  s = s.replace(/<style\b[^>]*>[\s\S]*?<\/style>/g, '<style><STRIPPED></style>');

  // ISO timestamps (or anything matching the pattern).
  s = s.replace(/\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?\b/g, '<TS>');

  // Relative time strings produced by formatRelativeTimestamp.
  s = s.replace(/\b(?:just now|\d+[smhdwy]o? ago)\b/g, '<RELATIVE>');

  // Extension version stamps (e.g. "v13.0.2").
  s = s.replace(/v\d+\.\d+\.\d+(?:-[a-z0-9.]+)?/g, 'v<VERSION>');

  // Collapse multiple whitespace to single space (defensive — sometimes
  // template-string indentation drifts between Windows and Unix line endings).
  s = s.replace(/[ \t]+/g, ' ');
  s = s.replace(/\s+\n/g, '\n');

  return s.trim();
}

interface AssertSnapshotOptions {
  /** When true, overwrite the baseline instead of comparing. Set via env var in CI/dev. */
  update?: boolean;
  /** Directory to read/write baselines. Defaults to alongside the test file. */
  baselineDir?: string;
}

/**
 * Compare `actual` against the baseline file `<filename>` under `baselineDir`.
 *
 * - Missing baseline + update=false → test fails with "no baseline; run with UPDATE_SNAPSHOTS=1".
 * - Missing baseline + update=true → write the baseline and pass.
 * - Mismatched baseline + update=false → test fails with a diff hint.
 * - Mismatched baseline + update=true → overwrite the baseline.
 */
export function assertSnapshot(
  actual: string,
  filename: string,
  options: AssertSnapshotOptions = {},
): void {
  const dir = options.baselineDir ?? path.join(__dirname);
  const baselinePath = path.join(dir, filename);
  const update = options.update ?? false;

  if (!fs.existsSync(baselinePath)) {
    if (update) {
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(baselinePath, actual, 'utf8');
      return;
    }
    assert.fail(
      `Snapshot baseline not found: ${baselinePath}.\n` +
      `Re-run with UPDATE_SNAPSHOTS=1 to create it.`,
    );
  }

  const baseline = fs.readFileSync(baselinePath, 'utf8');
  if (actual === baseline) { return; }

  if (update) {
    fs.writeFileSync(baselinePath, actual, 'utf8');
    return;
  }

  // Mismatch — emit a small diff hint so the contributor sees the first
  // divergence. Mocha's default reporter handles longer string diffs OK.
  const firstDiffIndex = findFirstDiff(baseline, actual);
  const sliceStart = Math.max(0, firstDiffIndex - 40);
  const sliceEnd = Math.min(actual.length, firstDiffIndex + 80);
  assert.fail(
    `Snapshot mismatch at offset ${firstDiffIndex} (${baselinePath}).\n` +
    `Expected: …${baseline.slice(sliceStart, sliceEnd)}…\n` +
    `Actual:   …${actual.slice(sliceStart, sliceEnd)}…\n\n` +
    `Re-run with UPDATE_SNAPSHOTS=1 to overwrite the baseline if the change is intended.`,
  );
}

function findFirstDiff(a: string, b: string): number {
  const len = Math.min(a.length, b.length);
  for (let i = 0; i < len; i++) {
    if (a[i] !== b[i]) { return i; }
  }
  return len;
}
