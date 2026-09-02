/**
 * Pure parsing functions for l10n diagnostic validation.
 *
 * Extracted from l10nDiagnostics.ts so they can be unit-tested
 * without VS Code API dependencies.
 */

/**
 * Advance past a string literal starting at position `i`.
 * Handles single/double quotes and template literals with nested
 * ${...} interpolations (which can themselves contain strings).
 * Returns position immediately after the closing quote.
 */
export function skipStringLiteral(text: string, i: number): number {
  const q = text[i];
  const n = text.length;
  i++;
  if (q === '`') {
    // Template literal — track interpolation brace depth so nested
    // strings and objects inside ${...} don't end the template early.
    let interpDepth = 0;
    while (i < n) {
      if (text[i] === '\\') { i += 2; continue; }
      if (interpDepth === 0 && text[i] === '`') return i + 1;
      if (interpDepth === 0 && text[i] === '$' && i + 1 < n && text[i + 1] === '{') {
        interpDepth++;
        i += 2;
        continue;
      }
      if (interpDepth > 0) {
        // Recurse for nested string literals inside the interpolation.
        if (text[i] === "'" || text[i] === '"' || text[i] === '`') {
          i = skipStringLiteral(text, i);
          continue;
        }
        if (text[i] === '{') { interpDepth++; i++; continue; }
        if (text[i] === '}') { interpDepth--; i++; continue; }
      }
      i++;
    }
    return i;
  }
  // Simple string literal (single or double quote).
  while (i < n) {
    if (text[i] === '\\') { i += 2; continue; }
    if (text[i] === q) return i + 1;
    i++;
  }
  return i;
}

/**
 * Replace comment contents with spaces so L10N_RE doesn't match
 * inside comments. Preserves string length and newlines for correct
 * position mapping back to the original document.
 *
 * Also skips regex literals (heuristic: `/` preceded by an operator
 * or statement-start token) so their contents don't look like `//`.
 */
export function blankComments(text: string): string {
  const out = text.split('');
  const n = text.length;
  let i = 0;
  while (i < n) {
    const c = text[i];
    // Skip strings — they can contain // and /* which aren't comments.
    if (c === "'" || c === '"' || c === '`') {
      i = skipStringLiteral(text, i);
      continue;
    }
    if (c === '/') {
      // Line comment: blank from // to end-of-line.
      if (i + 1 < n && text[i + 1] === '/') {
        const start = i;
        while (i < n && text[i] !== '\n') i++;
        for (let j = start; j < i; j++) out[j] = ' ';
        continue;
      }
      // Block comment: blank from /* to */, preserving newlines.
      if (i + 1 < n && text[i + 1] === '*') {
        const start = i;
        i += 2;
        while (i < n && !(text[i] === '*' && i + 1 < n && text[i + 1] === '/')) i++;
        if (i < n) i += 2;
        for (let j = start; j < i; j++) out[j] = text[j] === '\n' ? '\n' : ' ';
        continue;
      }
      // Regex literal: slash preceded by a token that can't end an
      // expression means this is /pattern/flags, not division.
      if (i + 1 < n) {
        let p = i - 1;
        while (p >= 0 && /\s/.test(text[p])) p--;
        const prev = p >= 0 ? text[p] : '\n';
        // These characters precede a regex but never end an expression.
        if ('=([,;!&|?:~^%{<>+-*'.includes(prev) || p < 0) {
          i++;
          while (i < n) {
            if (text[i] === '\\') { i += 2; continue; }
            if (text[i] === '/') { i++; break; }
            // Character class — / inside [...] doesn't end the regex.
            if (text[i] === '[') {
              i++;
              while (i < n && text[i] !== ']') {
                if (text[i] === '\\') { i += 2; continue; }
                i++;
              }
              if (i < n) i++;
              continue;
            }
            i++;
          }
          // Skip flags (g, i, m, s, u, y, d, v).
          while (i < n && /[gimsuyDdv]/.test(text[i])) i++;
          continue;
        }
      }
    }
    i++;
  }
  return out.join('');
}

/**
 * Extract a balanced { ... } block starting at position `start`,
 * handling nested braces and string literals.
 */
export function extractParamsBlock(text: string, start: number): string | undefined {
  let i = start;
  const n = text.length;
  // Skip whitespace, expect comma then opening brace.
  while (i < n && /\s/.test(text[i])) i++;
  if (i >= n || text[i] !== ',') return undefined;
  i++;
  while (i < n && /\s/.test(text[i])) i++;
  if (i >= n || text[i] !== '{') return undefined;

  let depth = 0;
  const objStart = i;
  while (i < n) {
    const c = text[i];
    if (c === "'" || c === '"' || c === '`') { i = skipStringLiteral(text, i); continue; }
    if (c === '{') { depth++; }
    else if (c === '}') { depth--; if (depth === 0) return text.slice(objStart, i + 1); }
    i++;
  }
  return undefined;
}

/**
 * State-machine extraction of top-level keys from a JS object literal.
 * Tracks nesting for {}/()/ [] and skips strings, spread expressions
 * (including chained calls like ...fn().member), and trailing commas.
 */
export function extractTopLevelKeys(block: string): Set<string> {
  const keys = new Set<string>();
  const n = block.length;
  let i = 1; // Past opening brace.
  let depth = 0;
  while (i < n) {
    const c = block[i];
    if (c === "'" || c === '"' || c === '`') { i = skipStringLiteral(block, i); continue; }
    if (c === '{' || c === '(' || c === '[') { depth++; i++; continue; }
    if (c === '}' || c === ')' || c === ']') {
      if (depth === 0) break;
      depth--; i++; continue;
    }
    if (depth === 0) {
      // Consume the full spread operand expression (handles fn().x,
      // obj[key], ternaries, etc.) until a top-level comma or brace.
      if (c === '.' && i + 2 < n && block[i + 1] === '.' && block[i + 2] === '.') {
        i += 3;
        let spreadDepth = 0;
        while (i < n) {
          const sc = block[i];
          if (sc === "'" || sc === '"' || sc === '`') { i = skipStringLiteral(block, i); continue; }
          if (sc === '(' || sc === '[' || sc === '{') { spreadDepth++; i++; continue; }
          if (sc === ')' || sc === ']') { spreadDepth--; i++; continue; }
          if (sc === '}') {
            if (spreadDepth === 0) break; // outer closing brace
            spreadDepth--; i++; continue;
          }
          if (spreadDepth === 0 && sc === ',') break;
          i++;
        }
        continue;
      }
      // Match an identifier — a key candidate.
      if (/[a-zA-Z_$]/.test(c)) {
        const start = i;
        while (i < n && /[\w$]/.test(block[i])) i++;
        const ident = block.slice(start, i);
        // Peek past whitespace for the delimiter that confirms it's a key.
        let j = i;
        while (j < n && /\s/.test(block[j])) j++;
        if (j < n && block[j] === ':') {
          // Explicit key — consume the value expression after the colon
          // so value identifiers aren't misdetected as keys.
          keys.add(ident);
          i = j + 1;
          let valDepth = 0;
          while (i < n) {
            const vc = block[i];
            if (vc === "'" || vc === '"' || vc === '`') { i = skipStringLiteral(block, i); continue; }
            if (vc === '(' || vc === '[' || vc === '{') { valDepth++; i++; continue; }
            if (vc === ')' || vc === ']') { valDepth--; i++; continue; }
            if (vc === '}') {
              if (valDepth === 0) break;
              valDepth--; i++; continue;
            }
            if (valDepth === 0 && vc === ',') break;
            i++;
          }
          continue;
        }
        if (j < n && (block[j] === ',' || block[j] === '}')) {
          keys.add(ident);
        }
        continue;
      }
    }
    i++;
  }
  return keys;
}
