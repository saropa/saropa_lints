/**
 * Pure text rewriters for rule renames: Dart ignore comments, analysis
 * options YAML keys and baseline JSON. No vscode or fs import.
 *
 * The new name usually starts with the old name (`x` -> `x_extended`), so
 * every match is a whole token and a second run changes nothing.
 */
import type { Finding, RenameEntry, RenameMap, RewriteResult } from './types';

const PREFIX = 'saropa_lints/';

/** Collapses chains (a->b, b->c gives a->c; b->null gives a->null). Cycles keep the last hop. */
export function buildRenameMap(entries: readonly RenameEntry[]): RenameMap {
  const direct = new Map<string, string | null>();
  for (const e of entries) direct.set(e.old, e.new);
  const out = new Map<string, string | null>();
  for (const [old, first] of direct) {
    let cur = first;
    const seen = new Set<string>([old]);
    while (cur !== null && direct.has(cur) && !seen.has(cur)) {
      seen.add(cur);
      cur = direct.get(cur) ?? null;
    }
    if (cur !== old) out.set(old, cur);
  }
  return out;
}

// Ported from lib/src/init/migration.dart; `\s` narrowed to [ \t] so a match never spans lines.
const IGNORE_RE = /(\/\/[ \t]*ignore(?:_for_file)?[ \t]*:[ \t]*)([\w/, \t-]+)/;

interface Segment {
  lead: string;
  tok: string;
  trail: string;
}

function splitList(list: string): Segment[] {
  return list.split(',').map((s) => {
    const m = /^(\s*)(.*?)(\s*)$/.exec(s) ?? ['', '', s, ''];
    return { lead: m[1], tok: m[2], trail: m[3] };
  });
}

/** Rewrites rule names in `// ignore:` and `// ignore_for_file:` comments. */
export function rewriteDartIgnores(text: string, renames: RenameMap): RewriteResult {
  const findings: Finding[] = [];
  let hits = 0;
  const parts = text.split(/(\r\n|\n|\r)/); // even = line, odd = EOL
  const out: string[] = [];
  for (let i = 0; i < parts.length; i += 2) {
    const line = parts[i];
    const eol = parts[i + 1] ?? '';
    const m = IGNORE_RE.exec(line);
    if (!m) {
      out.push(line + eol);
      continue;
    }
    const lineNo = i / 2 + 1;
    const segs = splitList(m[2]);
    const overallTrail = segs[segs.length - 1].trail;
    const kept: Segment[] = [];
    const present = new Set<string>(); // normalised prefixed names already kept
    let changed = false;
    for (const s of segs) {
      const norm = s.tok.replace(/-/g, '_');
      if (norm.startsWith(PREFIX)) {
        const bare = norm.slice(PREFIX.length);
        if (renames.has(bare)) {
          const target = renames.get(bare) ?? null;
          changed = true;
          hits++;
          if (target === null) continue;
          const spelled = s.tok.includes('-') ? target.replace(/_/g, '-') : target;
          const tok = `${PREFIX}${spelled}`;
          const key = `${PREFIX}${target}`;
          if (present.has(key) || segs.some((o) => o !== s && o.tok.replace(/-/g, '_') === key)) continue;
          present.add(key);
          kept.push({ ...s, tok });
          continue;
        }
      } else if (norm && renames.has(norm)) {
        findings.push({ kind: 'bareName', name: norm, line: lineNo });
      }
      present.add(norm);
      kept.push(s);
    }
    if (!changed) {
      out.push(line + eol);
      continue;
    }
    const before = line.slice(0, m.index);
    const after = line.slice(m.index + m[0].length);
    if (kept.length === 0) {
      const rest = before + after;
      if (rest.trim() === '') continue; // whole line was the comment: drop it with its EOL
      out.push(before.replace(/[ \t]+$/, '') + after + eol);
      continue;
    }
    const list = kept
      .map((s, idx) => (idx === 0 ? '' : s.lead) + s.tok)
      .join(',');
    out.push(before + m[1] + list + overallTrail + after + eol);
  }
  return { text: out.join(''), hits, findings };
}

const KEY_RE = /^(\s*)(["']?)([\w-]+)\2(\s*:)(.*)$/;

function indentOf(line: string): number {
  return line.length - line.trimStart().length;
}

function isBlankOrComment(line: string): boolean {
  const t = line.trim();
  return t === '' || t.startsWith('#');
}

/** Index one past the last line of the block belonging to the key at `start`. */
function blockEnd(lines: string[], start: number, indent: number): number {
  let end = start + 1;
  let last = end;
  while (end < lines.length) {
    if (!isBlankOrComment(lines[end]) && indentOf(lines[end]) <= indent) break;
    end++;
    if (!isBlankOrComment(lines[end - 1])) last = end;
  }
  return last;
}

/**
 * Rewrites rule keys.
 * - `options` (analysis_options.yaml): only direct children of
 *   `plugins: saropa_lints: diagnostics:`; `analyzer: errors:` is never touched.
 * - `custom` (analysis_options_custom.yaml): top-level keys.
 */
export function rewriteYamlKeys(
  text: string,
  renames: RenameMap,
  mode: 'options' | 'custom' = 'options',
): RewriteResult {
  const parts = text.split(/(\r\n|\n|\r)/);
  const lines: string[] = [];
  const eols: string[] = [];
  for (let i = 0; i < parts.length; i += 2) {
    lines.push(parts[i]);
    eols.push(parts[i + 1] ?? '');
  }
  const findings: Finding[] = [];
  let hits = 0;

  // Locate the line range [from, to) whose direct children are rule keys, and their indent.
  let from = -1;
  let to = -1;
  let childIndent = 0;
  if (mode === 'custom') {
    from = 0;
    to = lines.length;
    childIndent = 0;
  } else {
    const path = ['plugins', 'saropa_lints', 'diagnostics'];
    let depth = 0;
    let cursor = 0;
    let parentIndent = -1;
    for (let i = 0; i < lines.length && depth < path.length; i++) {
      const l = lines[i];
      if (isBlankOrComment(l)) continue;
      const ind = indentOf(l);
      if (ind <= parentIndent && depth > 0) break; // left the parent block without finding the next key
      const k = KEY_RE.exec(l);
      if (k && k[3] === path[depth] && (depth > 0 || ind === 0)) {
        depth++;
        parentIndent = ind;
        cursor = i;
      }
    }
    if (depth < path.length) return { text, hits: 0, findings };
    from = cursor + 1;
    to = blockEnd(lines, cursor, parentIndent);
    for (let i = from; i < to; i++) {
      if (!isBlankOrComment(lines[i])) {
        childIndent = indentOf(lines[i]);
        break;
      }
    }
  }

  const keyAt = (i: number): RegExpExecArray | null =>
    isBlankOrComment(lines[i]) || indentOf(lines[i]) !== childIndent ? null : KEY_RE.exec(lines[i]);

  const existing = new Set<string>();
  for (let i = from; i < to; i++) {
    const k = keyAt(i);
    if (k) existing.add(k[3]);
  }

  const drop = new Set<number>();
  for (let i = from; i < to; i++) {
    const k = keyAt(i);
    if (!k || !renames.has(k[3])) continue;
    const target = renames.get(k[3]) ?? null;
    hits++;
    if (target === null || existing.has(target)) {
      if (target !== null) findings.push({ kind: 'clash', name: k[3], line: i + 1 });
      const end = blockEnd(lines, i, childIndent);
      for (let j = i; j < end; j++) drop.add(j);
      continue;
    }
    lines[i] = `${k[1]}${k[2]}${target}${k[2]}${k[4]}${k[5]}`;
  }
  if (hits === 0) return { text, hits, findings };
  let result = '';
  for (let i = 0; i < lines.length; i++) if (!drop.has(i)) result += lines[i] + eols[i];
  return { text: result, hits, findings };
}

/** Rewrites rule keys under `violations.<file>` in a baseline JSON document. */
export function rewriteBaseline(json: string, renames: RenameMap): RewriteResult {
  let doc: unknown;
  try {
    doc = JSON.parse(json);
  } catch {
    return { text: json, hits: 0, findings: [] };
  }
  const violations = (doc as { violations?: unknown } | null)?.violations;
  if (violations === null || typeof violations !== 'object' || Array.isArray(violations)) {
    return { text: json, hits: 0, findings: [] };
  }
  let hits = 0;
  const files = violations as Record<string, unknown>;
  for (const file of Object.keys(files)) {
    const rules = files[file];
    if (rules === null || typeof rules !== 'object' || Array.isArray(rules)) continue;
    const src = rules as Record<string, unknown>;
    if (!Object.keys(src).some((k) => renames.has(k))) continue;
    const next: Record<string, unknown> = {};
    for (const key of Object.keys(src)) {
      if (!renames.has(key)) {
        if (key in next) next[key] = mergeLines(next[key], src[key]);
        else next[key] = src[key];
        continue;
      }
      hits++;
      const target = renames.get(key) ?? null;
      if (target === null) continue;
      if (target in next) next[target] = mergeLines(next[target], src[key]);
      else if (target in src) next[target] = mergeLines(src[target], src[key]);
      else next[target] = src[key];
    }
    files[file] = next;
  }
  if (hits === 0) return { text: json, hits, findings: [] };
  const indent = /^[ \t]+(?=")/m.exec(json)?.[0] ?? '  ';
  const eol = json.includes('\r\n') ? '\r\n' : '\n';
  let text = JSON.stringify(doc, null, indent).replace(/\n/g, eol);
  if (/(\r?\n)$/.test(json)) text += eol;
  return { text, hits, findings: [] };
}

function mergeLines(a: unknown, b: unknown): unknown {
  if (!Array.isArray(a) || !Array.isArray(b)) return a;
  return [...new Set([...(a as number[]), ...(b as number[])])].sort((x, y) => x - y);
}
