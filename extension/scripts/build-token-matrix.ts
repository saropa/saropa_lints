/**
 * Token coverage matrix generator (UX guidelines §19.4).
 *
 * Walks every `*-styles.ts` and inline-style file under `extension/src/`,
 * extracts `var(--vscode-*)` references, and emits a markdown table mapping
 * tokens × surfaces. Re-run after any CSS change; CI flags the diff.
 *
 * Usage:
 *
 *   npx ts-node extension/scripts/build-token-matrix.ts
 *
 * Output: `extension/src/test/views/snapshots/token-matrix.md`
 */

import * as fs from 'node:fs';
import * as path from 'node:path';

const REPO_ROOT = path.resolve(__dirname, '..');
const SRC_ROOT = path.join(REPO_ROOT, 'src');
const OUTPUT = path.join(REPO_ROOT, 'src/test/views/snapshots/token-matrix.md');

/** Files matching these patterns are scanned for theme tokens. */
const SCAN_PATTERNS = [
  /\.styles\.ts$/,
  /-styles\.ts$/,
  /-html\.ts$/,
  /Html\.ts$/,
  /HtmlBuilder\.ts$/,
  /Webview\.ts$/,
  /WebviewHtml\.ts$/,
  /Panel\.ts$/,
  /Tree\.ts$/,
  /Provider\.ts$/,
];

/** Skip these directories entirely. */
const SKIP_DIRS = new Set(['node_modules', 'out', 'out-test', 'dist', '.vscode-test', 'test']);

interface SurfaceTokens {
  surface: string; // file basename used as the column header
  tokens: Set<string>;
}

function shouldScan(filename: string): boolean {
  return SCAN_PATTERNS.some((p) => p.test(filename));
}

function walkDir(dir: string, results: string[]): void {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) { continue; }
      walkDir(path.join(dir, entry.name), results);
    } else if (entry.isFile() && shouldScan(entry.name)) {
      results.push(path.join(dir, entry.name));
    }
  }
}

function extractTokens(content: string): Set<string> {
  const tokens = new Set<string>();
  // Match `--vscode-foo-bar`, `--surface-1`, `--accent-error`, etc.
  const re = /var\(\s*(--[a-zA-Z][a-zA-Z0-9-]*)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(content)) !== null) {
    tokens.add(m[1]);
  }
  return tokens;
}

function main(): void {
  const files: string[] = [];
  walkDir(SRC_ROOT, files);

  const surfaces: SurfaceTokens[] = files.map((file) => {
    const content = fs.readFileSync(file, 'utf8');
    return {
      surface: path.basename(file).replace(/\.ts$/, ''),
      tokens: extractTokens(content),
    };
  }).filter((s) => s.tokens.size > 0);

  // Build the union of all tokens.
  const allTokens = new Set<string>();
  for (const s of surfaces) {
    for (const t of s.tokens) {
      allTokens.add(t);
    }
  }
  const sortedTokens = [...allTokens].sort();

  // Sort surfaces for stable output.
  surfaces.sort((a, b) => a.surface.localeCompare(b.surface));

  // Emit markdown. To keep the table from blowing up width-wise, list
  // surfaces as a separate index then emit one row per token with a
  // comma-separated list of surfaces using it.
  const out: string[] = [];
  out.push('# Token coverage matrix');
  out.push('');
  out.push(`Generated: ${new Date().toISOString()}`);
  out.push('');
  out.push(`Scanned ${surfaces.length} surface files; ${sortedTokens.length} unique tokens referenced.`);
  out.push('');
  out.push('## Index — surfaces');
  out.push('');
  surfaces.forEach((s, i) => {
    out.push(`${i + 1}. \`${s.surface}\``);
  });
  out.push('');
  out.push('## Tokens × surfaces');
  out.push('');
  out.push('| Token | Used by (surface index) |');
  out.push('|-------|--------------------------|');
  for (const token of sortedTokens) {
    const using = surfaces
      .map((s, i) => (s.tokens.has(token) ? i + 1 : null))
      .filter((x): x is number => x !== null);
    out.push(`| \`${token}\` | ${using.join(', ')} |`);
  }
  out.push('');
  out.push('## How to read this matrix');
  out.push('');
  out.push('- Each row pins a CSS variable used somewhere in the webview HTML / CSS.');
  out.push('- The surface index tells you which files reference it. A token with only one or two surfaces using it is a candidate for inlining or chrome consolidation.');
  out.push('- A token used by 5+ surfaces lives in chrome (`dashboardChromeStyles.ts`) by definition; if it appears here referenced from multiple `*-styles.ts` files, those should consume it from chrome rather than redefining.');
  out.push('- When VS Code deprecates a token, this matrix tells you exactly which surfaces need migration.');
  out.push('');

  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, out.join('\n'), 'utf8');
  console.log(`Wrote ${OUTPUT} — ${sortedTokens.length} tokens × ${surfaces.length} surfaces`);
}

main();
