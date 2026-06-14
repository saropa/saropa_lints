/**
 * Resolve the current commit SHA for the cross-commit correlation the suite keys
 * on (plan requirement R6 / Drift Advisor plan §6): "at commit abc123, code had N
 * lint findings, the DB was at schema version V, and the session produced these
 * signals." Stamping each exported diagnostic with `commitSha` lets the three
 * tools align per commit.
 *
 * Reads the `.git` directory directly rather than spawning `git rev-parse`: the
 * export runs on every debounced analysis-settle tick, and a synchronous file read
 * is cheaper and cannot hang on a missing/locked git binary. Handles the common
 * checkout (HEAD → branch ref → loose or packed SHA), a detached HEAD, and a
 * linked worktree (where `.git` is a file pointing at the real gitdir and refs
 * live in the shared commondir). Returns undefined on anything unexpected — the
 * SHA is optional in the envelope, so a non-git workspace simply omits it.
 *
 * `vscode`-free so it is unit-testable against a temp `.git` fixture.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';

const SHA_RE = /^[0-9a-f]{40}$/i;

/** Read a file and trim it, or null on any IO error. */
function readTrimmed(filePath: string): string | null {
  try {
    return fs.readFileSync(filePath, 'utf-8').trim();
  } catch {
    return null;
  }
}

/**
 * Resolve the gitdir for `root`. Normally `<root>/.git` is a directory; in a
 * linked worktree it is a file containing `gitdir: <path>` pointing at the real
 * per-worktree git directory.
 */
function resolveGitDir(root: string): string | null {
  const dotGit = path.join(root, '.git');
  let stat: fs.Stats;
  try {
    stat = fs.statSync(dotGit);
  } catch {
    return null;
  }
  if (stat.isDirectory()) return dotGit;
  const content = readTrimmed(dotGit);
  const match = content ? /^gitdir:\s*(.+)$/m.exec(content) : null;
  if (!match) return null;
  const gitdir = match[1].trim();
  return path.isAbsolute(gitdir) ? gitdir : path.resolve(root, gitdir);
}

/** The directories where a ref may be stored: the gitdir and, for a worktree, its commondir. */
function refSearchDirs(gitDir: string): string[] {
  const dirs = [gitDir];
  // A linked worktree stores HEAD locally but shared refs (refs/heads/*) in the
  // commondir named by `<gitdir>/commondir`.
  const commonDirRel = readTrimmed(path.join(gitDir, 'commondir'));
  if (commonDirRel) {
    const commonDir = path.isAbsolute(commonDirRel)
      ? commonDirRel
      : path.resolve(gitDir, commonDirRel);
    dirs.push(commonDir);
  }
  return dirs;
}

/** Look up a ref (e.g. `refs/heads/main`) as a loose file, then in packed-refs. */
function resolveRef(searchDirs: readonly string[], ref: string): string | undefined {
  for (const dir of searchDirs) {
    const loose = readTrimmed(path.join(dir, ref));
    if (loose && SHA_RE.test(loose)) return loose;
  }
  for (const dir of searchDirs) {
    const packed = readTrimmed(path.join(dir, 'packed-refs'));
    if (!packed) continue;
    for (const line of packed.split('\n')) {
      // Skip comments and peeled-tag (`^…`) lines; entries are "<sha> <refname>".
      if (line.length === 0 || line.startsWith('#') || line.startsWith('^')) continue;
      const [sha, name] = line.trim().split(/\s+/);
      if (name === ref && sha && SHA_RE.test(sha)) return sha;
    }
  }
  return undefined;
}

/**
 * The current commit SHA for `root`, or undefined when it cannot be resolved
 * (no `.git`, unborn branch, malformed HEAD). Never throws.
 */
export function resolveCommitSha(root: string): string | undefined {
  const gitDir = resolveGitDir(root);
  if (!gitDir) return undefined;
  const head = readTrimmed(path.join(gitDir, 'HEAD'));
  if (!head) return undefined;
  // Detached HEAD: the file is the SHA itself.
  if (SHA_RE.test(head)) return head;
  const refMatch = /^ref:\s*(.+)$/.exec(head);
  if (!refMatch) return undefined;
  return resolveRef(refSearchDirs(gitDir), refMatch[1].trim());
}
