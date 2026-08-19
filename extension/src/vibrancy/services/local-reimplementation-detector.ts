/**
 * Detects local reimplementation: project code that declares its own
 * class/mixin/extension/function whose NAME matches something a dependency
 * already exports. This is the scanner's unique value — no human or AI
 * session can efficiently diff a project's utility files against a
 * dependency's full source at scale, but name matching over the two symbol
 * sets already collected elsewhere (`readDartSources`,
 * `collectSymbolOccurrences`) is cheap.
 *
 * Deliberately name-based, not AST/type-based: two same-named symbols with
 * different signatures still match. This is a starting point ("does the
 * project maybe already have this?") for a human/AI to verify, not a
 * resolved-reference-accurate finding — same textual-matching ceiling
 * `collectSymbolOccurrences` documents for usage matching.
 *
 * Pure: string/data in, structured data out. No `vscode` import.
 */

import type { DartSource } from './import-scanner';

/** What kind of declaration a matched symbol is. */
export type DeclaredSymbolKind = 'class' | 'mixin' | 'extension' | 'function' | 'extensionMember';

/** One top-level (or extension-member) declaration found in a source file. */
export interface DeclaredSymbol {
    readonly name: string;
    readonly kind: DeclaredSymbolKind;
    readonly filePath: string;
    readonly line: number;
}

/** A project declaration whose name matches something the package exports. */
export interface LocalReimplementation {
    readonly name: string;
    readonly kind: DeclaredSymbolKind;
    readonly filePath: string;
    readonly line: number;
}

// Keywords that can start a statement at brace-depth 0 and superficially look
// like `Type name(` (a control-flow line, not a top-level declaration).
// Excluding these keeps the function-declaration heuristic from matching
// `if (foo(` or `switch (bar) {`.
const CONTROL_FLOW_KEYWORDS = new Set([
    'if', 'for', 'while', 'switch', 'catch', 'return', 'throw', 'new',
    'assert', 'do', 'else', 'super', 'this',
]);

const CLASS_PATTERN = /^(?:abstract\s+|final\s+|base\s+|sealed\s+|interface\s+)*class\s+([A-Za-z_]\w*)/;
const MIXIN_PATTERN = /^mixin\s+([A-Za-z_]\w*)/;
const NAMED_EXTENSION_PATTERN = /^extension\s+([A-Za-z_]\w*)\s+on\s+/;
const ANONYMOUS_EXTENSION_PATTERN = /^extension\s+on\s+/;
// A plausible top-level function/method declaration: `ReturnType name(`.
// Requires a return-type token before the name so bare calls (`retry(`) at
// depth 0 (which shouldn't occur, but guards malformed input) don't match.
const FUNCTION_PATTERN = /^[A-Za-z_][\w<>,\s?.]*[\s*]([A-Za-z_]\w*)\s*(?:<[^>(]*>)?\s*\(/;
const GETTER_PATTERN = /^[A-Za-z_][\w<>,\s?.]*\s+get\s+([A-Za-z_]\w*)/;

/**
 * Extract top-level class/mixin/extension/function declarations, plus
 * members declared directly inside a named extension body (the shape
 * Dart utility packages use for `list.isNullOrEmpty`-style helpers — the
 * highest-value match target since these are exactly the "reimplements a
 * library extension" cases the bug that motivated this module called out).
 *
 * Heuristic brace-depth tracking, not an AST — acceptable for name-based
 * matching the same way `classifyLines` accepts heuristic comment detection:
 * the failure modes (a stray brace in a string/comment miscounts depth) are
 * rare and only cost a missed or extra candidate, never a wrong file/line.
 */
export function extractDeclaredSymbols(source: DartSource): DeclaredSymbol[] {
    const out: DeclaredSymbol[] = [];
    const lines = source.text.split('\n');

    let depth = 0;
    // Depth at which the extension body's direct members live, or null when
    // not currently inside a named extension.
    let extensionMemberDepth: number | null = null;

    for (let i = 0; i < lines.length; i++) {
        const trimmed = lines[i].trim();
        const lineNumber = i + 1;

        if (depth === 0 && extensionMemberDepth === null) {
            matchTopLevel(trimmed, source.path, lineNumber, out);
            if (NAMED_EXTENSION_PATTERN.test(trimmed) || ANONYMOUS_EXTENSION_PATTERN.test(trimmed)) {
                extensionMemberDepth = depth + 1;
            }
        } else if (extensionMemberDepth !== null && depth === extensionMemberDepth) {
            matchExtensionMember(trimmed, source.path, lineNumber, out);
        }

        depth += countChar(trimmed, '{') - countChar(trimmed, '}');
        if (extensionMemberDepth !== null && depth < extensionMemberDepth) {
            extensionMemberDepth = null;
        }
    }

    return out;
}

/** Match a class/mixin/extension/function declaration at brace-depth 0. */
function matchTopLevel(
    trimmed: string, filePath: string, line: number, out: DeclaredSymbol[],
): void {
    const classMatch = trimmed.match(CLASS_PATTERN);
    if (classMatch) {
        out.push({ name: classMatch[1], kind: 'class', filePath, line });
        return;
    }
    const mixinMatch = trimmed.match(MIXIN_PATTERN);
    if (mixinMatch) {
        out.push({ name: mixinMatch[1], kind: 'mixin', filePath, line });
        return;
    }
    const extMatch = trimmed.match(NAMED_EXTENSION_PATTERN);
    if (extMatch) {
        out.push({ name: extMatch[1], kind: 'extension', filePath, line });
        return;
    }
    const funcMatch = trimmed.match(FUNCTION_PATTERN);
    if (funcMatch && !CONTROL_FLOW_KEYWORDS.has(funcMatch[1])) {
        out.push({ name: funcMatch[1], kind: 'function', filePath, line });
    }
}

/** Match a method or getter declared directly inside an extension body. */
function matchExtensionMember(
    trimmed: string, filePath: string, line: number, out: DeclaredSymbol[],
): void {
    const getterMatch = trimmed.match(GETTER_PATTERN);
    if (getterMatch) {
        out.push({ name: getterMatch[1], kind: 'extensionMember', filePath, line });
        return;
    }
    const methodMatch = trimmed.match(FUNCTION_PATTERN);
    if (methodMatch && !CONTROL_FLOW_KEYWORDS.has(methodMatch[1])) {
        out.push({ name: methodMatch[1], kind: 'extensionMember', filePath, line });
    }
}

function countChar(text: string, char: string): number {
    let count = 0;
    for (const c of text) { if (c === char) { count++; } }
    return count;
}

/**
 * Cross-reference the project's own declared symbols against the names a
 * dependency exports. A match means the project may be reimplementing
 * something the package already provides — worth a human/AI look, not a
 * confirmed duplicate (see module doc for the name-only-matching ceiling).
 */
export function detectLocalReimplementations(
    projectDeclarations: readonly DeclaredSymbol[],
    packageSymbolNames: ReadonlySet<string>,
): LocalReimplementation[] {
    if (packageSymbolNames.size === 0) { return []; }
    return projectDeclarations
        .filter(d => packageSymbolNames.has(d.name))
        .map(d => ({
            name: d.name, kind: d.kind, filePath: d.filePath, line: d.line,
        }));
}
