import * as fs from 'fs';
import * as path from 'path';

/** Matches a flow-sequence `exclude: [a, b]` line, capturing the bracket contents. */
const INLINE_EXCLUDE_PATTERN = /^\s+exclude\s*:\s*\[(.*)\]\s*$/;

/** `-`, `?`, `:` are YAML indicators only when followed by whitespace/EOL; `*&!|>%@` always. */
const INDICATOR_START = /^[*&!|>%@]|^[-?:](\s|$)/;

export function readAnalysisOptionsPath(root: string): string {
  return path.join(root, 'analysis_options.yaml');
}

export function readAnalyzerExcludes(root: string): string[] {
  const filePath = readAnalysisOptionsPath(root);
  if (!fs.existsSync(filePath)) return [];
  const content = fs.readFileSync(filePath, 'utf8');
  return parseAnalyzerExcludes(content);
}

/**
 * Splits a raw YAML list-item value into its clean pattern and its inline
 * comment (if any), stripping quote characters from the pattern.
 *
 * Handles the common hand-edited case where a pattern was typed as an
 * unquoted scalar but still closed with a trailing quote out of habit: an
 * unquoted scalar followed by `" # comment` is, per YAML's rules, a literal
 * value ending in a stray quote character, followed by a comment — without
 * stripping that, the value never string-equals the clean pattern the
 * optimizer generates, so an already-excluded pattern looks unrecognized and
 * gets re-added as a duplicate on the next write.
 */
function splitPatternAndComment(raw: string): { pattern: string; comment: string } {
  // YAML only starts a comment at a `#` preceded by whitespace, so this is
  // safe even though glob patterns can't contain `#` themselves.
  const commentIdx = raw.search(/\s#/);
  const comment = commentIdx >= 0 ? raw.slice(commentIdx).trim() : '';
  let value = (commentIdx >= 0 ? raw.slice(0, commentIdx) : raw).trim();
  if ((value.startsWith('"') && value.endsWith('"') && value.length >= 2)
    || (value.startsWith("'") && value.endsWith("'") && value.length >= 2)) {
    value = value.slice(1, -1);
  } else {
    if (value.startsWith('"') || value.startsWith("'")) value = value.slice(1);
    if (value.endsWith('"') || value.endsWith("'")) value = value.slice(0, -1);
  }
  return { pattern: value.trim(), comment };
}

/**
 * Double-quotes a pattern for YAML output, escaping backslashes and quotes.
 * Every written pattern is quoted unconditionally — glob patterns routinely
 * start with a double star, and an UNQUOTED scalar starting with `*` is YAML
 * alias syntax (a reference to an anchor), not a literal string. An unquoted
 * double-star glob is invalid YAML ("Undefined alias") the moment a real
 * parser reads it, even though this module's own line-scanner is lenient
 * enough to read it back. Quoting sidesteps every other YAML indicator
 * character (`&`, `!`, `|`, `>`, `%`, `@`, leading `-`/`?`/`:`) too.
 */
function quoteYamlPattern(pattern: string): string {
  return `"${pattern.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

interface ExcludeLine {
  pattern: string;
  /** Trailing `# comment` text, verbatim, or '' if the entry has none. */
  comment: string;
  /** Index into the source `lines` array for a block-list item, or -1 for an inline-array item. */
  lineIndex: number;
}

/** Locates the `analyzer: exclude:` block and returns its list items in file order, raw. */
function findExcludeLines(lines: string[]): {
  analyzerIdx: number;
  analyzerIndent: number;
  indentUnit: string;
  excludeStart: number;
  excludeEnd: number;
  inlineItems: ExcludeLine[] | null;
  items: ExcludeLine[];
} {
  const analyzerIdx = lines.findIndex(l => /^analyzer\s*:/.test(l));
  const result = {
    analyzerIdx,
    analyzerIndent: -1,
    indentUnit: '  ',
    excludeStart: -1,
    excludeEnd: -1,
    inlineItems: null as ExcludeLine[] | null,
    items: [] as ExcludeLine[],
  };
  if (analyzerIdx < 0) return result;

  result.analyzerIndent = lines[analyzerIdx].length - lines[analyzerIdx].trimStart().length;
  let indentUnitFound = false;
  let excludeIndent = -1;
  let inExclude = false;

  for (let i = analyzerIdx + 1; i < lines.length; i++) {
    const stripped = lines[i].replace(/\r$/, '');
    if (/^\s*#/.test(stripped) || stripped.trim() === '') {
      if (inExclude) continue;
      continue;
    }
    const indent = stripped.length - stripped.trimStart().length;

    if (!inExclude && indent <= result.analyzerIndent) break;

    if (!indentUnitFound && indent > result.analyzerIndent) {
      result.indentUnit = stripped.slice(result.analyzerIndent, indent);
      indentUnitFound = true;
    }

    if (!inExclude && /^\s+exclude\s*:/.test(stripped)) {
      const inlineMatch = stripped.match(INLINE_EXCLUDE_PATTERN);
      if (inlineMatch) {
        result.excludeStart = i;
        result.excludeEnd = i + 1;
        result.inlineItems = inlineMatch[1]
          .split(',')
          .map(item => item.trim())
          .filter(item => item.length > 0)
          .map(item => ({ ...splitPatternAndComment(item), lineIndex: -1 }));
        return result;
      }
      result.excludeStart = i;
      excludeIndent = indent;
      inExclude = true;
      continue;
    }

    if (inExclude) {
      if (indent <= excludeIndent) {
        result.excludeEnd = i;
        break;
      }
      const match = stripped.match(/^\s+-\s+(.+)/);
      if (match) {
        result.items.push({ ...splitPatternAndComment(match[1]), lineIndex: i });
      }
    }
  }

  if (result.excludeStart >= 0 && result.excludeEnd < 0) {
    result.excludeEnd = lines.length;
  }
  return result;
}

export function parseAnalyzerExcludes(content: string): string[] {
  const found = findExcludeLines(content.split('\n'));
  const rawItems = found.inlineItems ?? found.items;
  const seen = new Set<string>();
  const result: string[] = [];
  for (const item of rawItems) {
    if (!item.pattern || seen.has(item.pattern)) continue;
    seen.add(item.pattern);
    result.push(item.pattern);
  }
  return result;
}

/**
 * True if `pattern` is already excluded by `existing` — either an exact
 * match, or a narrower path already covered by a broader `dir/**` entry
 * (e.g. `dependency_overrides/flutter_contacts/**` is covered by an existing
 * `dependency_overrides/**`). Without the coverage check, a folder-level
 * recommendation for an already-excluded subtree would show as
 * "Recommended" forever, since its exact string never appears in the file.
 */
export function isPatternCovered(pattern: string, existing: readonly string[]): boolean {
  return existing.some(e =>
    e === pattern
    || (e.endsWith('/**') && pattern.startsWith(e.slice(0, -2))));
}

/**
 * True if the `analyzer: exclude:` block contains at least one list item
 * written as an unquoted scalar starting with a YAML indicator character —
 * the same shape that produces a real "Undefined alias" (or similar) parse
 * error the moment the Dart analyzer reads the file, even though this
 * module's own line-scanner reads such lines back without complaint. Used
 * to proactively flag files with a syntax problem before the user changes
 * any exclusion.
 *
 * `*`, `&`, `!`, `|`, `>`, `%`, `@` are unsafe as the first character of a
 * plain scalar unconditionally. `-`, `?`, `:` are YAML indicators ONLY when
 * followed by whitespace or end-of-value (`- `/`- `/`? `/`: ` are
 * block-sequence / explicit-key / mapping-value syntax) — a pattern that
 * merely starts with one of those characters immediately followed by more
 * text (`-legacy/**`) is a perfectly valid unquoted scalar and must not be
 * flagged, or "Fix Syntax" would claim to fix files that were never broken.
 */
export function hasMalformedExcludeSyntax(root: string): boolean {
  const filePath = readAnalysisOptionsPath(root);
  if (!fs.existsSync(filePath)) return false;
  const lines = fs.readFileSync(filePath, 'utf8').split('\n');
  const found = findExcludeLines(lines);
  if (found.excludeStart < 0) return false;

  if (found.inlineItems !== null) {
    // Flow-sequence scalars (`exclude: [a, b]`) follow the same plain-scalar
    // rules as block-list items — an unquoted `*`-leading value inside `[...]`
    // is just as much an alias reference in YAML's flow context.
    const inlineMatch = lines[found.excludeStart].match(INLINE_EXCLUDE_PATTERN);
    if (!inlineMatch) return false;
    return inlineMatch[1]
      .split(',')
      .map(item => item.trim())
      .filter(item => item.length > 0)
      .some(item => !item.startsWith('"') && !item.startsWith("'") && INDICATOR_START.test(item));
  }

  for (let i = found.excludeStart; i < found.excludeEnd && i < lines.length; i++) {
    const stripped = lines[i].replace(/\r$/, '');
    const match = stripped.match(/^\s+-\s+(.+)/);
    if (!match) continue;
    const rawValue = match[1].trim();
    if (rawValue.startsWith('"') || rawValue.startsWith("'")) continue;
    if (INDICATOR_START.test(rawValue)) return true;
  }
  return false;
}

/**
 * Re-quotes only the specific lines that are actually malformed, and deletes
 * only the exact line(s) that are a literal duplicate of an earlier pattern.
 * Every other line — comments, blank lines, already-correct entries, their
 * order — is left byte-for-byte untouched. This is a surgical repair, not a
 * block rebuild: earlier versions of this tool regenerated the entire
 * exclude block from a flat pattern list on every write, which silently
 * discarded section-header comments and blank-line grouping that aren't
 * attached to any single pattern, and re-sorted everything alphabetically.
 */
export function fixMalformedExcludeSyntax(root: string): { success: boolean; duplicatesRemoved: number } {
  const filePath = readAnalysisOptionsPath(root);
  if (!fs.existsSync(filePath)) return { success: false, duplicatesRemoved: 0 };
  const lines = fs.readFileSync(filePath, 'utf8').split('\n');
  const found = findExcludeLines(lines);
  if (found.excludeStart < 0) return { success: true, duplicatesRemoved: 0 };

  if (found.inlineItems !== null) {
    const seen = new Set<string>();
    const rebuilt: string[] = [];
    let duplicatesRemoved = 0;
    for (const item of found.inlineItems) {
      if (!item.pattern) continue;
      if (seen.has(item.pattern)) { duplicatesRemoved++; continue; }
      seen.add(item.pattern);
      rebuilt.push(quoteYamlPattern(item.pattern));
    }
    lines[found.excludeStart] = lines[found.excludeStart].replace(/\[(.*)\]/, `[${rebuilt.join(', ')}]`);
    fs.writeFileSync(filePath, lines.join('\n'), 'utf8');
    return { success: true, duplicatesRemoved };
  }

  const seenPatterns = new Set<string>();
  const deleteIndices: number[] = [];
  let duplicatesRemoved = 0;

  for (const item of found.items) {
    if (!item.pattern) continue;
    if (seenPatterns.has(item.pattern)) {
      deleteIndices.push(item.lineIndex);
      duplicatesRemoved++;
      continue;
    }
    seenPatterns.add(item.pattern);

    const stripped = lines[item.lineIndex].replace(/\r$/, '');
    const match = stripped.match(/^(\s+-\s+)(.+)/);
    if (!match) continue;
    const rawValue = match[2].trim();
    if (rawValue.startsWith('"') || rawValue.startsWith("'")) continue;
    if (!INDICATOR_START.test(rawValue)) continue;

    lines[item.lineIndex] = `${match[1]}${quoteYamlPattern(item.pattern)}${item.comment ? ` ${item.comment}` : ''}`;
  }

  for (const idx of deleteIndices.sort((a, b) => b - a)) {
    lines.splice(idx, 1);
  }

  fs.writeFileSync(filePath, lines.join('\n'), 'utf8');
  return { success: true, duplicatesRemoved };
}

/**
 * Computes the analysis_options.yaml content that `writeAnalyzerExcludes` would
 * write, without touching disk. Used to render a diff preview before the user
 * commits to a write.
 */
export function computeAnalyzerExcludesContent(
  root: string,
  patterns: string[],
): { before: string; after: string } | null {
  const filePath = readAnalysisOptionsPath(root);
  if (!fs.existsSync(filePath)) return null;
  const before = fs.readFileSync(filePath, 'utf8');
  const after = replaceOrInsertExcludes(before, patterns);
  if (after === null) return null;
  return { before, after };
}

export function writeAnalyzerExcludes(
  root: string,
  patterns: string[],
): boolean {
  const filePath = readAnalysisOptionsPath(root);
  if (!fs.existsSync(filePath)) return false;
  const content = fs.readFileSync(filePath, 'utf8');
  const updated = replaceOrInsertExcludes(content, patterns);
  if (updated === null) return false;
  fs.writeFileSync(filePath, updated, 'utf8');
  return true;
}

export function mergeExclusions(
  existing: string[],
  toAdd: string[],
): string[] {
  const merged = new Set([...existing, ...toAdd]);
  const sorted = [...merged].sort();
  return sorted.filter(p => {
    return !sorted.some(broader =>
      broader !== p
      && broader.endsWith('/**')
      && p.startsWith(broader.replace('/**', '/'))
    );
  });
}

/**
 * Rewrites the exclude block to contain exactly `patterns`, editing MINIMALLY:
 * lines for patterns being removed are deleted, lines for brand-new patterns
 * are appended, and every line for a pattern that's staying is left
 * completely untouched — same quoting, same comment, same position. This
 * means unrelated content (section-header comments, blank-line grouping,
 * manual ordering) survives every Apply/Remove, not just the pattern lines
 * this specific action changes.
 */
function replaceOrInsertExcludes(
  content: string,
  patterns: string[],
): string | null {
  const lines = content.split('\n');
  const found = findExcludeLines(lines);

  if (found.analyzerIdx < 0) {
    const excludeBlock = patterns.length > 0
      ? `  exclude:\n${patterns.map(p => `    - ${quoteYamlPattern(p)}`).join('\n')}`
      : '  exclude: []';
    lines.unshift(`analyzer:\n${excludeBlock}`, '');
    return lines.join('\n');
  }

  const indentUnit = found.indentUnit;

  // Wiping to zero, or an inline-array source: a full-block rebuild is
  // acceptable here — inline arrays are single-line so there's no
  // structure (comments/grouping) to lose, and wiping to zero patterns
  // has nothing left worth preserving either way.
  if (patterns.length === 0 || found.inlineItems !== null) {
    const commentByPattern = new Map<string, string>();
    for (const item of found.inlineItems ?? found.items) {
      if (item.pattern && !commentByPattern.has(item.pattern)) {
        commentByPattern.set(item.pattern, item.comment);
      }
    }
    const excludeBlock = patterns.length > 0
      ? `${indentUnit}exclude:\n${patterns
        .map((p) => {
          const comment = commentByPattern.get(p);
          return `${indentUnit}${indentUnit}- ${quoteYamlPattern(p)}${comment ? ` ${comment}` : ''}`;
        })
        .join('\n')}`
      : `${indentUnit}exclude: []`;

    if (found.excludeStart >= 0) {
      lines.splice(found.excludeStart, found.excludeEnd - found.excludeStart, excludeBlock);
    } else {
      lines.splice(found.analyzerIdx + 1, 0, excludeBlock);
    }
    return lines.join('\n');
  }

  if (found.excludeStart < 0) {
    const excludeBlock = `${indentUnit}exclude:\n${patterns
      .map(p => `${indentUnit}${indentUnit}- ${quoteYamlPattern(p)}`)
      .join('\n')}`;
    lines.splice(found.analyzerIdx + 1, 0, excludeBlock);
    return lines.join('\n');
  }

  // Block-list, non-empty target: minimal surgical edit. Known limitation:
  // a standalone section-header comment (`# === Generated Code ===`) isn't
  // tracked as belonging to any specific pattern below it, so removing the
  // last pattern under a header leaves that header orphaned with nothing
  // beneath it. Still strictly better than the prior full-rebuild behavior,
  // which discarded the header entirely on every write.
  const desired = new Set(patterns);
  const seenDesired = new Set<string>();
  const deleteIndices: number[] = [];
  const existingPatterns = new Set<string>();
  for (const item of found.items) {
    if (!item.pattern) continue;
    existingPatterns.add(item.pattern);
    if (!desired.has(item.pattern) || seenDesired.has(item.pattern)) {
      deleteIndices.push(item.lineIndex);
    } else {
      seenDesired.add(item.pattern);
    }
  }

  let insertionPoint = found.excludeEnd;
  for (const idx of deleteIndices.slice().sort((a, b) => b - a)) {
    lines.splice(idx, 1);
    if (idx < insertionPoint) insertionPoint--;
  }

  const newPatterns = patterns.filter(p => !existingPatterns.has(p));
  if (newPatterns.length > 0) {
    const newLines = newPatterns.map(p => `${indentUnit}${indentUnit}- ${quoteYamlPattern(p)}`);
    lines.splice(insertionPoint, 0, ...newLines);
  }

  return lines.join('\n');
}
