/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * VS Code views: trees, dashboards, or webview HTML builders.
 */

/**
 * Fetches the live rule-count summary from `dart run saropa_lints:rule_count
 * --format json`, so the About panel never shows a hand-typed count that
 * drifts stale as rules are added (the "2100+" strings scattered across
 * docs/marketing copy were exactly this problem — see
 * plans/history/2026.08/2026.08.19/rule_count_correction.md).
 *
 * Best-effort: any failure (no workspace, CLI missing, non-zero exit,
 * malformed JSON) resolves to `null` and the caller renders without the
 * live figure rather than blocking or erroring the whole About panel.
 */
import { spawn } from 'node:child_process';
import { resolveCliCwd } from './devCliRoot';

export interface RuleCountSummary {
  readonly essential: number;
  readonly recommended: number;
  readonly professional: number;
  readonly comprehensive: number;
  readonly pedantic: number;
  readonly stylistic: number;
  readonly total: number;
}

// Same shell:true rationale as projectVibrancyCliRunner.ts: Windows needs it
// for dart.bat resolution (PATHEXT) and Node's CVE-2024-27980 mitigation.
const SPAWN_USE_SHELL = process.platform === 'win32';

/** Resolves to the live rule-count summary, or `null` on any failure. */
export function fetchRuleCounts(projectRoot: string): Promise<RuleCountSummary | null> {
  return new Promise((resolve) => {
    const cliCwd = resolveCliCwd(projectRoot);
    let child;
    try {
      child = spawn('dart', ['run', 'saropa_lints:rule_count', '--format', 'json'], {
        cwd: cliCwd,
        shell: SPAWN_USE_SHELL,
      });
    } catch {
      resolve(null);
      return;
    }

    let stdout = '';
    let settled = false;
    const finish = (result: RuleCountSummary | null): void => {
      if (settled) return;
      settled = true;
      resolve(result);
    };

    // The count itself is a pure in-memory set computation, but `dart run`
    // must first compile a kernel snapshot on a cold invocation — measured
    // at ~8.4s on a warm-ish machine, leaving almost no margin under a 10s
    // cap on a genuinely cold toolchain start (first run after boot, slower
    // disk/CPU). 25s keeps the "stop waiting eventually" guarantee without
    // false-negativing on legitimate cold starts.
    const timeout = setTimeout(() => {
      try { child.kill(); } catch { /* best-effort */ }
      finish(null);
    }, 25_000);

    child.stdout?.on('data', (chunk: Buffer) => { stdout += chunk.toString(); });
    child.on('error', () => { clearTimeout(timeout); finish(null); });
    child.on('close', (code) => {
      clearTimeout(timeout);
      if (code !== 0) { finish(null); return; }
      try {
        const parsed = JSON.parse(stdout) as Partial<RuleCountSummary>;
        if (typeof parsed.total !== 'number') { finish(null); return; }
        finish({
          essential: parsed.essential ?? 0,
          recommended: parsed.recommended ?? 0,
          professional: parsed.professional ?? 0,
          comprehensive: parsed.comprehensive ?? 0,
          pedantic: parsed.pedantic ?? 0,
          stylistic: parsed.stylistic ?? 0,
          total: parsed.total,
        });
      } catch {
        finish(null);
      }
    });
  });
}
