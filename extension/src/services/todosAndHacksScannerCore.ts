/**
 * Pure helpers for task-marker regex and exclude pattern.
 * No vscode dependency so unit tests can run without mocking.
 */

/** Escape special regex characters in a tag for use in a character group or alternation. */
export function escapeTagForRegex(tag: string): string {
  const re = new RegExp(String.raw`[.*+?^${'$'}{}()|[\]\\]`, 'g');
  return tag.replaceAll(re, (m) => '\x5c' + m);
}

/**
 * Build a line-based regex that matches comment prefix (//, #, <!--) then one of the tags.
 * Captures: tag, optional colon, rest of line (snippet).
 */
export function buildRegex(tags: string[]): RegExp {
  if (tags.length === 0) return /^$/;
  const alternation = tags.map(escapeTagForRegex).join('|');
  const commentPrefix = '\x2f\x2f'; // //
  const pattern =
    String.raw`^\s*(?:` + commentPrefix + String.raw`|#|<!--)\s*(` + alternation + String.raw`)(\s*:)?\s*(.*)$`;
  return new RegExp(pattern);
}

export interface MarkerLine {
  lineIndex: number;
  tag: string;
  snippet: string;
  fullLine: string;
}

/**
 * Extract marker data from file content using the tag regex (no URI).
 * Built-in regex: m[1]=tag, m[2]=optional colon, m[3]=snippet.
 * Custom regex: m[1]=tag, m[2]=snippet (optional; if missing, use full line).
 */
export function extractMarkersFromLines(
  content: string,
  regex: RegExp,
  isCustomRegex: boolean,
): MarkerLine[] {
  const result: MarkerLine[] = [];
  const lines = content.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const m = regex.exec(line);
    if (regex.global) regex.lastIndex = 0; // allow same regex to be reused on next line
    if (!m) continue;
    const tag = m[1];
    let snippet: string;
    if (isCustomRegex) {
      snippet = (m[2] ?? line.trim()).trim();
    } else {
      snippet = (m[3] ?? '').trim();
      if (snippet.endsWith('-->')) {
        snippet = snippet.slice(0, -3).trim();
      }
    }
    result.push({
      lineIndex: i,
      tag,
      snippet: snippet || tag,
      fullLine: line.trim(),
    });
  }
  return result;
}

/** Merge excludeGlobs with search.exclude keys (where value is true) into one pattern for findFiles. */
export function getExcludePattern(
  excludeGlobs: string[],
  searchExclude: Record<string, boolean> | undefined,
): string {
  const parts = [...excludeGlobs];
  if (searchExclude && typeof searchExclude === 'object') {
    for (const [key, value] of Object.entries(searchExclude)) {
      if (value && key) parts.push(key);
    }
  }
  if (parts.length === 0) return '';
  if (parts.length === 1) return parts[0];
  return '{' + parts.join(',') + '}';
}
