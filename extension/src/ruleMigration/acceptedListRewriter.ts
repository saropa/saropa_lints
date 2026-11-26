/**
 * Rule-rename rewriter for the accepted-findings list (`saropa_accepted.yaml`).
 * Pure text in, text out; no vscode or fs import.
 *
 * Without it, renaming a rule made every list entry for the old name invalid
 * (`Unknown rule`), so the reviewed findings it hid came back and the
 * reason recorded for them was orphaned.
 *
 * Only the value of a `rule:` key is rewritten (`- rule: x` or `  rule: x`,
 * bare or quoted, with an optional trailing comment); every other byte of the
 * file is kept. A rule that was removed (`new: null`) is left as is: the entry
 * carries a human-written reason, so it is not deleted silently. The
 * `--check-accepted` report flags it as an unknown rule for the author to
 * remove.
 */
import type { RenameMap, RewriteResult } from './types';

/** `rule:` key line: lead (indent and optional `- `), quote, name, tail. */
const RULE_LINE = /^(\s*(?:-\s+)?rule\s*:\s*)(["']?)([\w-]+)\2(\s*(?:#.*)?)$/;

/** Rewrites renamed rule names in an accepted-findings list. */
export function rewriteAcceptedList(text: string, renames: RenameMap): RewriteResult {
  let hits = 0;
  const parts = text.split(/(\r\n|\n|\r)/); // even = line, odd = EOL
  for (let i = 0; i < parts.length; i += 2) {
    const m = RULE_LINE.exec(parts[i]);
    if (!m) continue;
    const target = renames.get(m[3]);
    // Not renamed, or removed (null): keep the line (see the module note).
    if (target === undefined || target === null) continue;
    parts[i] = `${m[1]}${m[2]}${target}${m[2]}${m[4]}`;
    hits++;
  }
  return { text: hits === 0 ? text : parts.join(''), hits, findings: [] };
}
