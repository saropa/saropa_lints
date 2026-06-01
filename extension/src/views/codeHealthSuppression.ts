/**
 * Merge a Code Health flag suppression into a Dart file's content.
 *
 * The Dart CLI scanner ([lib/src/cli/project_vibrancy.dart]) recognizes two
 * shapes at file scope:
 *   - `// ignore_for_file: code_health`              -> whole file suppressed
 *   - `// ignore_for_file: code_health:flag,flag`    -> only listed flags
 *     dropped from every row in this file
 *
 * This helper takes the current file content + a flag name (e.g. `complex`)
 * and returns the new file content with the suppression added or merged.
 * The merge logic is pure: no I/O, no VS Code dependencies — so it can be
 * unit-tested. The caller is responsible for `readFile` / `writeFile`.
 *
 * Merge rules:
 *   - If the file already carries `// ignore_for_file: code_health` (bare),
 *     it already covers everything — return content unchanged.
 *   - If it carries `// ignore_for_file: code_health:a,b`, extend to
 *     `// ignore_for_file: code_health:a,b,<flag>` (dedup, alphabetical).
 *   - If it carries `// ignore_for_file: <other_rule>`, append a NEW line
 *     `// ignore_for_file: code_health:<flag>` BELOW the existing one.
 *     We don't append to the existing comma list because that risks
 *     ambiguity with the analyzer's grammar (`code_health:complex` is not
 *     a valid analyzer rule name even though our scanner accepts it).
 *   - If no ignore directive exists, insert `// ignore_for_file: code_health:
 *     <flag>` at the very top of the file (line 1), preserving any shebang
 *     or BOM. Don't insert after `///` doc comments — analyzer file-level
 *     directives are conventionally first.
 */

/**
 * Result of [mergeCodeHealthSuppression]. `noChange` is `true` when the flag
 * was already suppressed (idempotent) so the caller can show a different toast
 * ("already suppressed") versus the success case.
 */
export interface SuppressionMergeResult {
  /** New file content to write back. Equal to input when `noChange` is true. */
  readonly content: string;
  /** True when no edit was needed (flag already covered or bare directive present). */
  readonly noChange: boolean;
}

const DIRECTIVE_PREFIX = '// ignore_for_file:';

/**
 * Pure merge function — see file header for rules.
 */
export function mergeCodeHealthSuppression(
  content: string,
  flag: string,
): SuppressionMergeResult {
  const trimmedFlag = flag.trim();
  if (trimmedFlag.length === 0) return { content, noChange: true };
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trimStart();
    if (!trimmed.startsWith(DIRECTIVE_PREFIX)) continue;
    const updated = tryUpdateDirective(lines[i], trimmedFlag);
    if (updated.noChange) return { content, noChange: true };
    if (updated.line !== undefined) {
      lines[i] = updated.line;
      return { content: lines.join('\n'), noChange: false };
    }
    // Existing ignore directive carries OTHER rules but not code_health.
    // Append a fresh code_health line directly below.
    lines.splice(i + 1, 0, `${DIRECTIVE_PREFIX} code_health:${trimmedFlag}`);
    return { content: lines.join('\n'), noChange: false };
  }
  // No directive found — insert at the top of the file, preserving any
  // initial empty line so the file doesn't gain a blank gap above the
  // directive on round-trip.
  return {
    content: `${DIRECTIVE_PREFIX} code_health:${trimmedFlag}\n${content}`,
    noChange: false,
  };
}

interface DirectiveUpdate {
  readonly line?: string;
  readonly noChange: boolean;
}

/**
 * Update a single `// ignore_for_file:` line. Returns:
 *   - `noChange: true` when the flag is already covered (bare `code_health`
 *     present, or `code_health:<flag>` already includes the target flag)
 *   - `{ line: <new line> }` when the existing `code_health:` flag list was
 *     extended in place
 *   - `{}` (neither `line` nor `noChange`) when this directive doesn't carry
 *     `code_health` at all — caller appends a new directive line below.
 */
function tryUpdateDirective(line: string, flag: string): DirectiveUpdate {
  const colon = line.indexOf(':');
  if (colon < 0) return { noChange: false };
  const head = line.slice(0, colon + 1);
  const rest = line.slice(colon + 1);
  const idx = rest.indexOf('code_health');
  if (idx < 0) return { noChange: false };
  // Token-boundary check left.
  if (idx > 0) {
    const left = rest[idx - 1];
    if (left !== ' ' && left !== ',' && left !== '\t') {
      return { noChange: false };
    }
  }
  const afterIdx = idx + 'code_health'.length;
  if (afterIdx >= rest.length || rest[afterIdx] !== ':') {
    // Bare `code_health` at end-of-line or followed by non-`:` — already
    // covers everything in this file, so adding a specific flag is a noop.
    return { noChange: true };
  }
  // Parse the existing flag list. The list ends at end-of-line, end-of-comment
  // (we trim trailing whitespace), or — defensively — at a token that looks
  // like another rule name following whitespace. Our scanner reads until
  // end-of-line, so match that.
  const flagListStart = afterIdx + 1;
  const flagListRaw = rest.slice(flagListStart).trimEnd();
  const existing = flagListRaw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  if (existing.includes(flag)) return { noChange: true };
  existing.push(flag);
  existing.sort();
  const newFlagList = existing.join(',');
  const newRest = `${rest.slice(0, flagListStart)}${newFlagList}`;
  return { line: head + newRest, noChange: false };
}
