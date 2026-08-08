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

export function parseAnalyzerExcludes(content: string): string[] {
  const lines = content.split('\n');
  const excludes: string[] = [];
  let inAnalyzer = false;
  let inExclude = false;
  let analyzerIndent = -1;
  let excludeIndent = -1;

  for (const line of lines) {
    const stripped = line.replace(/\r$/, '');
    if (/^\s*#/.test(stripped) || stripped.trim() === '') {
      if (inExclude) continue;
      continue;
    }

    const indent = stripped.length - stripped.trimStart().length;

    if (/^analyzer\s*:/.test(stripped)) {
      inAnalyzer = true;
      analyzerIndent = indent;
      inExclude = false;
      continue;
    }

    if (inAnalyzer && indent <= analyzerIndent && stripped.trim() !== '') {
      inAnalyzer = false;
      inExclude = false;
      continue;
    }

    if (inAnalyzer && /^\s+exclude\s*:/.test(stripped)) {
      const inlineMatch = stripped.match(/^\s+exclude\s*:\s*\[(.*)\]\s*$/);
      if (inlineMatch) {
        for (const item of inlineMatch[1].split(',')) {
          const trimmedItem = item.trim().replace(/^['"]|['"]$/g, '');
          if (trimmedItem) excludes.push(trimmedItem);
        }
        continue;
      }
      inExclude = true;
      excludeIndent = indent;
      continue;
    }

    if (inExclude) {
      if (indent <= excludeIndent && stripped.trim() !== '') {
        inExclude = false;
        if (indent <= analyzerIndent) inAnalyzer = false;
        continue;
      }
      const match = stripped.match(/^\s+-\s+(.+)/);
      if (match) {
        excludes.push(match[1].trim().replace(/^['"]|['"]$/g, ''));
      }
    }
  }

  return excludes;
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
  const analyzerIdx = lines.findIndex(l => /^analyzer\s*:/.test(l));

  if (analyzerIdx >= 0) {
    let excludeStart = -1;
    let excludeEnd = -1;
    const analyzerIndent = lines[analyzerIdx].length - lines[analyzerIdx].trimStart().length;
    // Infer this file's existing indent unit from the first child of `analyzer:`
    // rather than assuming 2 spaces — a mismatched unit would make the new
    // `exclude:` key a sibling with a different indent than its neighbors,
    // which most YAML parsers reject.
    let indentUnit = '  ';
    let indentUnitFound = false;

    for (let i = analyzerIdx + 1; i < lines.length; i++) {
      const line = lines[i];
      const stripped = line.replace(/\r$/, '');
      if (/^\s*#/.test(stripped) || stripped.trim() === '') continue;
      const indent = stripped.length - stripped.trimStart().length;
      if (indent <= analyzerIndent) break;

      if (!indentUnitFound) {
        indentUnit = stripped.slice(analyzerIndent, indent);
        indentUnitFound = true;
      }

      if (/^\s+exclude\s*:/.test(stripped)) {
        excludeStart = i;
        for (let j = i + 1; j < lines.length; j++) {
          const eLine = lines[j].replace(/\r$/, '');
          if (/^\s*#/.test(eLine) || eLine.trim() === '') continue;
          const eIndent = eLine.length - eLine.trimStart().length;
          if (eIndent <= indent) { excludeEnd = j; break; }
        }
        if (excludeEnd < 0) excludeEnd = lines.length;
        break;
      }
    }

    const excludeBlock = patterns.length > 0
      ? `${indentUnit}exclude:\n${patterns.map(p => `${indentUnit}${indentUnit}- ${p}`).join('\n')}`
      : `${indentUnit}exclude: []`;

    if (excludeStart >= 0) {
      lines.splice(excludeStart, excludeEnd - excludeStart, excludeBlock);
    } else {
      lines.splice(analyzerIdx + 1, 0, excludeBlock);
    }
  } else {
    const excludeBlock = patterns.length > 0
      ? `  exclude:\n${patterns.map(p => `    - ${p}`).join('\n')}`
      : '  exclude: []';
    lines.unshift(`analyzer:\n${excludeBlock}`, '');
  }

  return lines.join('\n');
}
