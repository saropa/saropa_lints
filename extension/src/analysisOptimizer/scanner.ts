import * as vscode from 'vscode';
import * as cp from 'child_process';
import type { FileAnalysisMetrics } from './types';

const GENERATED_SUFFIXES = [
  '.g.dart',
  '.freezed.dart',
  '.mocks.dart',
  '.gr.dart',
  '.config.dart',
  '.gen.dart',
  '.chopper.dart',
  '.graphql.dart',
];

const CONCURRENCY = 30;
const RECENT_DAYS = 30;

export function computeFileMetrics(
  content: string,
  relativePath: string,
): Omit<FileAnalysisMetrics, 'daysSinceLastEdit'> {
  const lines = content.split('\n');
  const lineCount = lines.length;

  let importCount = 0;
  let classCount = 0;
  let functionCount = 0;
  let hasWidgets = false;
  let hasAsyncCode = false;

  for (const line of lines) {
    const trimmed = line.trimStart();
    if (trimmed.startsWith('import ')) importCount++;
    if (trimmed.startsWith('class ') || trimmed.startsWith('abstract class ') || trimmed.startsWith('mixin ')) classCount++;
    if (/^\s*\w[\w<>,\s]*\s+\w+\s*\(/.test(line) && !trimmed.startsWith('import ') && !trimmed.startsWith('//')) functionCount++;
    if (!hasWidgets && /\bWidget\b|\bState</.test(line)) hasWidgets = true;
    if (!hasAsyncCode && /\basync\b|\bFuture\b|\bStream\b/.test(line)) hasAsyncCode = true;
  }

  const isGenerated = GENERATED_SUFFIXES.some(s => relativePath.endsWith(s));

  return {
    relativePath,
    lineCount,
    classCount,
    functionCount,
    importCount,
    hasWidgets,
    hasAsyncCode,
    isGenerated,
  };
}

function queryGitRecency(root: string): Map<string, number> {
  const recency = new Map<string, number>();
  try {
    const since = `${RECENT_DAYS} days ago`;
    const now = Date.now();
    // Scoped to --since so the walk stays bounded by RECENT_DAYS regardless of
    // total repo history size — files outside the window are simply absent
    // from `recency` (their daysSinceLastEdit stays undefined upstream).
    const out = cp.execSync(
      `git log --diff-filter=M --name-only --format=">>>%aI" --since="${since}" -- "*.dart"`,
      { cwd: root, encoding: 'utf8', timeout: 15_000, maxBuffer: 10 * 1024 * 1024 },
    );
    let currentDate = now;
    for (const line of out.split('\n')) {
      const trimmed = line.trim();
      if (trimmed.startsWith('>>>')) {
        const iso = trimmed.slice(3);
        const parsed = new Date(iso).getTime();
        currentDate = Number.isFinite(parsed) ? parsed : now;
      } else if (trimmed.endsWith('.dart')) {
        const posix = trimmed.replace(/\\/g, '/');
        const days = Math.max(0, Math.floor((now - currentDate) / 86_400_000));
        const existing = recency.get(posix);
        if (existing === undefined || days < existing) {
          recency.set(posix, days);
        }
      }
    }
  } catch {
    // git unavailable — all files get undefined recency
  }
  return recency;
}

export async function scanWorkspace(
  root: string,
  progress: vscode.Progress<{ message?: string; increment?: number }>,
  token: vscode.CancellationToken,
): Promise<FileAnalysisMetrics[]> {
  const files = await vscode.workspace.findFiles(
    new vscode.RelativePattern(root, '**/*.dart'),
    '**/build/**',
    50_000,
  );
  if (token.isCancellationRequested) return [];

  const total = files.length;
  progress.report({ message: `Found ${total} Dart files` });

  const gitRecency = queryGitRecency(root);

  const results: FileAnalysisMetrics[] = [];
  let completed = 0;
  let lastReportedPct = 0;

  const rootUri = vscode.Uri.file(root);

  async function processFile(uri: vscode.Uri): Promise<void> {
    if (token.isCancellationRequested) return;
    try {
      const raw = await vscode.workspace.fs.readFile(uri);
      const content = Buffer.from(raw).toString('utf8');
      const relativePath = vscode.workspace.asRelativePath(uri, false).replace(/\\/g, '/');
      const metrics = computeFileMetrics(content, relativePath);
      const days = gitRecency.get(relativePath);
      results.push({ ...metrics, daysSinceLastEdit: days });
    } catch {
      // skip unreadable files
    }
    completed++;
    const pct = Math.floor((completed / total) * 100);
    if (pct > lastReportedPct) {
      lastReportedPct = pct;
      progress.report({
        message: `Scanning: ${completed}/${total} files (${pct}%)`,
        increment: pct - lastReportedPct,
      });
    }
  }

  for (let i = 0; i < files.length; i += CONCURRENCY) {
    if (token.isCancellationRequested) break;
    const batch = files.slice(i, i + CONCURRENCY);
    await Promise.all(batch.map(f => processFile(f)));
  }

  return results;
}
