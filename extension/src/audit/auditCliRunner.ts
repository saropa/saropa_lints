/**
 * Shared `dart run saropa_lints audit` process runner + JSON payload conversion.
 *
 * Extracted from audit-command.ts so the same CLI-spawning logic can be driven
 * both by the explorer context-menu "Audit Folder..." command (its own
 * notification progress) and by the Findings Dashboard's in-panel scope
 * selector (toolbar progress, no VS Code notification/quick-pick). Keeping one
 * copy of the spawn/kill/parse logic means a fix to cancellation or stderr
 * parsing lands for both callers at once.
 */
import * as cp from 'node:child_process';
import * as vscode from 'vscode';
import { killProcessTree, resolveCliCwd } from '../views/devCliRoot';
import { l10n } from '../i18n/runtime';
import { normalizeLegacyImpact, type Violation, type ViolationsData } from '../violationsReader';

/** Cross-platform tree-kill for the spawned audit CLI process — see doc comment in the original audit-command.ts. */
export function killAuditProcessTree(child: cp.ChildProcess): void {
  if (process.platform !== 'win32' && child.pid) {
    try {
      process.kill(-child.pid, 'SIGKILL');
      return;
    } catch {
      // Process group already gone (e.g. dart already exited) — fall
      // through to the shared best-effort path below.
    }
  }
  killProcessTree(child);
}

/** A single diagnostic from the audit JSON payload (`{ diagnostics: [...] }`). */
export interface AuditDiagnostic {
  filePath: string;
  line: number;
  column: number;
  ruleName: string;
  severity: string;
  impact: string | null;
  tier: string | null;
  problemMessage: string | null;
  correctionMessage: string | null;
  /** Present only when --baseline was used: 'new', 'unchanged', or 'resolved'. */
  baselineStatus: string | null;
}

/** Absolute progress percentage + a human-readable status line. */
export interface AuditCliProgressUpdate {
  pct: number;
  message: string;
}

/** Progress data parsed from a JSON line on stderr. */
interface AuditProgressLine {
  progress: number;
  total: number;
  elapsed: string;
  issues: number;
  file: string;
}

/**
 * Spawns `dart run saropa_lints audit` and collects the JSON output from
 * stdout. Returns the parsed JSON object, or null on failure/cancel.
 *
 * `onProgress` receives absolute percentages (not increments) so both a
 * `vscode.Progress` notification (which wants increments) and a webview
 * progress bar (which wants an absolute width) can consume it directly —
 * increment tracking is the notification caller's job, not this function's.
 *
 * @param onFailure Invoked with the localized failure/cancel message right
 *   before resolving null, so the caller can surface the same text wherever
 *   it renders results (a webview panel, a toast, or both).
 */
export function spawnAuditCli(
  root: string,
  sinceRef: string | null,
  useBaseline: boolean,
  token: vscode.CancellationToken,
  onProgress: (update: AuditCliProgressUpdate) => void,
  onFailure: (message: string, canceled: boolean) => void,
): Promise<Record<string, unknown> | null> {
  return new Promise((resolve) => {
    const args = ['run', 'saropa_lints', 'audit', root, '--quiet'];
    if (sinceRef) {
      args.push('--since', sinceRef);
    }
    if (useBaseline) {
      args.push('--baseline');
    }

    const child = cp.spawn('dart', args, {
      cwd: resolveCliCwd(root),
      shell: true,
      // POSIX only (no-op on win32, where killProcessTree's `taskkill /T`
      // walks the tree by PID instead). Makes the spawned shell the leader
      // of a NEW process group, so the dart grandchild it launches shares
      // that group id — required for killAuditProcessTree's negative-pid
      // kill below to reach it.
      detached: process.platform !== 'win32',
    });

    let stdout = '';
    let stderrBuf = '';
    const stderrLines: string[] = [];
    let lastPct = 0;
    // Cancellation already resolved + surfaced a message; taskkill's forced
    // tree-kill still fires 'close' afterward with truncated/empty stdout,
    // which would otherwise JSON.parse-fail and produce a second,
    // contradictory failure report on top of the cancellation.
    let canceled = false;

    child.stdout.on('data', (d: Buffer) => (stdout += d.toString()));

    child.stderr.on('data', (d: Buffer) => {
      stderrBuf += d.toString();
      const lines = stderrBuf.split('\n');
      stderrBuf = lines.pop() ?? '';
      stderrLines.push(...lines);

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed.startsWith('{')) continue;
        try {
          const p = JSON.parse(trimmed) as Partial<AuditProgressLine>;
          if (typeof p.progress === 'number' && typeof p.total === 'number' && p.total > 0) {
            lastPct = Math.round((p.progress / p.total) * 100);
            const shortFile = (p.file ?? '').split(/[/\\]/).pop() ?? '';
            onProgress({
              pct: lastPct,
              message: l10n('audit.progress.message', {
                pct: String(lastPct),
                scanned: String(p.progress),
                total: String(p.total),
                issues: String(p.issues ?? 0),
                file: shortFile,
              }),
            });
          }
        } catch {
          // Not a progress line — ignore.
        }
      }
    });

    token.onCancellationRequested(() => {
      canceled = true;
      killAuditProcessTree(child);
      const message = l10n('audit.error.canceled');
      onFailure(message, true);
      resolve(null);
    });

    child.on('error', (e: Error) => {
      if (canceled) return;
      const message = l10n('audit.error.spawnFailed', { message: e.message });
      onFailure(message, false);
      resolve(null);
    });

    child.on('close', (code: number | null) => {
      if (canceled) return;

      if (lastPct < 100) {
        onProgress({ pct: 100, message: l10n('audit.progress.title') });
      }

      // Exit 2 = invalid args or not a Dart project.
      if (code === 2) {
        const first = stderrLines.find((l) => l.trim().length > 0 && !l.trim().startsWith('{')) ?? '';
        const message = l10n('audit.error.invalidProject', { details: first });
        onFailure(message, false);
        resolve(null);
        return;
      }

      // Exit 0 or 1 = audit completed (0 = clean, 1 = findings found).
      try {
        const json = JSON.parse(stdout) as Record<string, unknown>;
        resolve(json);
      } catch {
        const message = l10n('audit.error.parseFailed');
        onFailure(message, false);
        resolve(null);
      }
    });
  });
}

/**
 * Converts an audit CLI JSON payload (`{ diagnostics: AuditDiagnostic[] }`)
 * into the same `ViolationsData` shape the Findings Dashboard already renders
 * from live diagnostics — same field mapping `liveDiagnosticsModel.ts` uses
 * (file/line/rule/message/severity/impact), so the dashboard's filtering,
 * grouping, and table code needs no audit-specific branches.
 *
 * Summary/config are intentionally left undefined: every downstream consumer
 * (severity/impact counts, top rule, files-affected, KPI cards) already
 * computes its own aggregate straight from the `violations` array rather than
 * trusting a precomputed summary — see `buildViolationsDataFromDiagnostics`,
 * which follows the same minimal-payload convention for live diagnostics.
 *
 * `impact` IS legacy-normalized (unlike `buildViolationsDataFromDiagnostics`,
 * which has no legacy path since it reads the in-process analyzer plugin
 * bundled with THIS extension) — the audit CLI runs the scanned project's own
 * pinned `saropa_lints`, which can be an older version still emitting the
 * pre-collapse 5-bucket impact vocabulary. See the inline comment below.
 */
export function auditPayloadToViolationsData(payload: Record<string, unknown>): ViolationsData {
  const diagnostics = Array.isArray(payload['diagnostics'])
    ? (payload['diagnostics'] as AuditDiagnostic[])
    : [];
  const violations: Violation[] = diagnostics.map((d) => {
    const severity = (d.severity ?? 'info').toLowerCase();
    // `spawnAuditCli` runs the SCANNED PROJECT's own pinned `saropa_lints`
    // (via resolveCliCwd), not necessarily the version bundled with this
    // extension — a project pinned to <13.4.x can still emit the legacy
    // 5-bucket `impact` vocabulary (critical/high/medium/low/opinionated)
    // even though the extension's own dashboard code has moved on to the
    // 3-bucket error/warning/info model. `readViolations()` normalizes this
    // exact case for the batch violations.json export (see
    // normalizeLegacyImpact's doc comment, issue #208's "401 findings / 0
    // shown" regression); apply the same normalization here so an old
    // project's audit run doesn't silently show 0 rows under the default
    // {error, warning, info} severity filter.
    const impact = normalizeLegacyImpact(d.impact) ?? severity;
    return {
      file: d.filePath,
      line: d.line,
      rule: d.ruleName,
      message: d.problemMessage ?? '',
      severity,
      impact,
      correction: d.correctionMessage ?? undefined,
    };
  });
  return {
    timestamp: typeof payload['timestamp'] === 'string' ? (payload['timestamp'] as string) : new Date().toISOString(),
    violations,
  };
}
