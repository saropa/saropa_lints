import * as fs from 'fs';
import * as path from 'path';

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
 * Strips an inline `# comment` and any leading/trailing quote characters from
 * a raw YAML list-item value. Handles the common hand-edited case where a
 * pattern was typed as an unquoted scalar but still closed with a trailing
 * quote out of habit: an unquoted scalar followed by `" # comment` is, per
 * YAML's rules, a literal value ending in a stray quote character, followed
 * by a comment — without stripping that, the value never string-equals the
 * clean pattern the optimizer generates, so an already-excluded pattern
 * looks unrecognized and gets re-added as a duplicate on the next write.
 */
function cleanExcludeValue(raw: string): string {
  // YAML only starts a comment at a `#` preceded by whitespace, so this is
  // safe even though glob patterns can't contain `#` themselves.
  const commentIdx = raw.search(/\s#/);
  let value = (commentIdx >= 0 ? raw.slice(0, commentIdx) : raw).trim();
  if ((value.startsWith('"') && value.endsWith('"') && value.length >= 2)
    || (value.startsWith("'") && value.endsWith("'") && value.length >= 2)) {
    value = value.slice(1, -1);
  } else {
    if (value.startsWith('"') || value.startsWith("'")) value = value.slice(1);
    if (value.endsWith('"') || value.endsWith("'")) value = value.slice(0, -1);
  }
  return value.trim();
}

interface ExcludeLine {
  pattern: string;
  /** Raw text after `- `, comment and stray quoting intact, for write-back preservation. */
  raw: string;
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
      const inlineMatch = stripped.match(/^\s+exclude\s*:\s*\[(.*)\]\s*$/);
      if (inlineMatch) {
        result.excludeStart = i;
        result.excludeEnd = i + 1;
        result.inlineItems = inlineMatch[1]
          .split(',')
          .map(item => item.trim())
          .filter(item => item.length > 0)
          .map(item => ({ pattern: cleanExcludeValue(item), raw: item }));
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
        result.items.push({ pattern: cleanExcludeValue(match[1]), raw: match[1].trim() });
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
    // Reuse each pattern's original raw line (comment and all) where one
    // exists, so applying a new exclusion doesn't wipe out the user's
    // hand-written explanations for every other entry in the block.
    const rawByPattern = new Map<string, string>();
    for (const item of found.inlineItems ?? found.items) {
      if (item.pattern && !rawByPattern.has(item.pattern)) {
        rawByPattern.set(item.pattern, item.raw);
      }
    }

    const indentUnit = found.indentUnit;
    const excludeBlock = patterns.length > 0
      ? `${indentUnit}exclude:\n${patterns
        .map(p => `${indentUnit}${indentUnit}- ${rawByPattern.get(p) ?? p}`)
        .join('\n')}`
      : `${indentUnit}exclude: []`;

    if (found.excludeStart >= 0) {
      lines.splice(found.excludeStart, found.excludeEnd - found.excludeStart, excludeBlock);
    } else {
      lines.splice(found.analyzerIdx + 1, 0, excludeBlock);
    }
  } else {
    const excludeBlock = patterns.length > 0
      ? `  exclude:\n${patterns.map(p => `    - ${p}`).join('\n')}`
      : '  exclude: []';
    lines.unshift(`analyzer:\n${excludeBlock}`, '');
  }

  return lines.join('\n');
}
