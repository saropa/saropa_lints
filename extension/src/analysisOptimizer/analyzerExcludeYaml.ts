import * as fs from 'fs';
import * as path from 'path';

/** Matches a flow-sequence `exclude: [a, b]` line, capturing the bracket contents. */
const INLINE_EXCLUDE_PATTERN = /^\s+exclude\s*:\s*\[(.*)\]\s*$/;

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
          .map(item => splitPatternAndComment(item));
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
        result.items.push(splitPatternAndComment(match[1]));
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

  const indicatorStart = /^[*&!|>%@]|^[-?:](\s|$)/;

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
      .some(item => !item.startsWith('"') && !item.startsWith("'") && indicatorStart.test(item));
  }

  for (let i = found.excludeStart; i < found.excludeEnd && i < lines.length; i++) {
    const stripped = lines[i].replace(/\r$/, '');
    const match = stripped.match(/^\s+-\s+(.+)/);
    if (!match) continue;
    const rawValue = match[1].trim();
    if (rawValue.startsWith('"') || rawValue.startsWith("'")) continue;
    if (indicatorStart.test(rawValue)) return true;
  }
  return false;
}

/**
 * Re-quotes every existing exclude pattern in place. Also collapses any
 * literal duplicate pattern down to one entry, since `readAnalyzerExcludes`
 * dedupes — a duplicate line is itself a symptom of the same malformed-entry
 * class this exists to fix, so that's a feature of the fix, not a side effect.
 * `duplicatesRemoved` lets the caller surface that count rather than silently
 * dropping data the user might not expect to lose.
 */
export function fixMalformedExcludeSyntax(root: string): { success: boolean; duplicatesRemoved: number } {
  const filePath = readAnalysisOptionsPath(root);
  if (!fs.existsSync(filePath)) return { success: false, duplicatesRemoved: 0 };
  const found = findExcludeLines(fs.readFileSync(filePath, 'utf8').split('\n'));
  const rawCount = (found.inlineItems ?? found.items).filter(item => item.pattern).length;
  const cleanPatterns = readAnalyzerExcludes(root);
  const success = writeAnalyzerExcludes(root, cleanPatterns);
  return { success, duplicatesRemoved: success ? Math.max(0, rawCount - cleanPatterns.length) : 0 };
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

function replaceOrInsertExcludes(
  content: string,
  patterns: string[],
): string | null {
  const lines = content.split('\n');
  const found = findExcludeLines(lines);

  if (found.analyzerIdx >= 0) {
    // Reuse each pattern's original comment where one exists, so applying a
    // new exclusion doesn't wipe out the user's hand-written explanations for
    // every other entry in the block. The pattern itself is always re-quoted
    // (see quoteYamlPattern) rather than preserved verbatim — an existing
    // entry may be exactly the malformed unquoted-`**` form that caused the
    // parse error in the first place, and blindly preserving it would leave
    // that error in place forever.
    const commentByPattern = new Map<string, string>();
    for (const item of found.inlineItems ?? found.items) {
      if (item.pattern && !commentByPattern.has(item.pattern)) {
        commentByPattern.set(item.pattern, item.comment);
      }
    }

    const indentUnit = found.indentUnit;
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
  } else {
    const excludeBlock = patterns.length > 0
      ? `  exclude:\n${patterns.map(p => `    - ${quoteYamlPattern(p)}`).join('\n')}`
      : '  exclude: []';
    lines.unshift(`analyzer:\n${excludeBlock}`, '');
  }

  return lines.join('\n');
}
