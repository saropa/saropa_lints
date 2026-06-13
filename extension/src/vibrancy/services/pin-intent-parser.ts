/**
 * Parses do-not-upgrade / do-not-use INTENT from pubspec comments.
 *
 * The dependency parser discards comments, so an intentional pin ("DO NOT BUMP
 * home_widget", "COMMERCIAL PACKAGE - DO NOT USE", "Pin MUST stay at exactly
 * 0.9.1") was indistinguishable from neglect — the scanner nagged to upgrade a
 * dep the maintainer deliberately froze. This reads the comment block attached
 * to each dependency and extracts the intent so the UI can mark a deliberate
 * hold instead of reporting a missed upgrade.
 *
 * Pure — string in, map out. No I/O.
 */

import { PinIntent } from '../types';

/** Phrases that signal a deliberate do-not-upgrade hold. */
const DO_NOT_UPGRADE = [
    'do not bump', "don't bump", 'do not upgrade', "don't upgrade",
    'never bump', 'never upgrade', 'must stay', 'must remain', 'pin must',
    'do not raise', 'do not raise the cap', 'leave it alone', 'frozen',
    'pinned to exactly', 'stay at exactly', 'prefer_caret_version_syntax',
];

/** Phrases that signal a do-not-use package (commercial, banned). */
const DO_NOT_USE = ['do not use', 'commercial package'];

/** A pubspec line that declares a dependency at 2-space indent. */
const DEP_LINE = /^\s{2}(\w[\w_]*)\s*:/;

/** Lowercase scan for the first phrase from `needles` present in `text`. */
function containsAny(text: string, needles: readonly string[]): boolean {
    const lower = text.toLowerCase();
    return needles.some(n => lower.includes(n));
}

/** Strip leading/trailing comment markers and box characters from a line. */
function cleanComment(line: string): string {
    return line
        .replace(/^[#\s]+/, '')
        .replace(/[#\s]+$/, '')
        .trim();
}

/**
 * From a buffered comment block, return the first cleaned line that names the
 * intent (carries a keyword and survives box-character stripping). Falls back
 * to the first non-empty cleaned line so a hold is never reasonless.
 */
function pickReason(
    buffer: readonly string[], needles: readonly string[],
): string {
    for (const raw of buffer) {
        const cleaned = cleanComment(raw);
        if (cleaned && containsAny(cleaned, needles)) { return cleaned; }
    }
    for (const raw of buffer) {
        const cleaned = cleanComment(raw);
        if (cleaned) { return cleaned; }
    }
    return '';
}

/** Classify a dependency's preceding comment block into a PinIntent, or null. */
function classifyBlock(buffer: readonly string[]): PinIntent | null {
    const joined = buffer.join('\n');
    if (containsAny(joined, DO_NOT_USE)) {
        return { reason: pickReason(buffer, DO_NOT_USE), kind: 'do-not-use' };
    }
    if (containsAny(joined, DO_NOT_UPGRADE)) {
        return {
            reason: pickReason(buffer, DO_NOT_UPGRADE),
            kind: 'do-not-upgrade',
        };
    }
    return null;
}

/**
 * Parse pin intents from pubspec content. Returns a map from package name to
 * its intent for every dependency whose preceding/trailing comments document a
 * do-not-upgrade or do-not-use hold.
 *
 * Only the comment block IMMEDIATELY preceding a dependency (plus its trailing
 * inline comment) is considered, so an intent comment binds to the next dep,
 * not to one ten lines down. A blank line clears the buffer.
 */
export function parsePinIntents(content: string): Map<string, PinIntent> {
    const intents = new Map<string, PinIntent>();
    let buffer: string[] = [];

    for (const rawLine of content.split('\n')) {
        const line = rawLine.trimEnd();
        const depMatch = line.match(DEP_LINE);

        if (depMatch) {
            // Include the trailing inline comment on the dep line itself.
            const hashIdx = line.indexOf('#');
            const block = hashIdx >= 0 ? [...buffer, line.slice(hashIdx)] : buffer;
            const intent = classifyBlock(block);
            if (intent) { intents.set(depMatch[1], intent); }
            buffer = [];
            continue;
        }

        const trimmed = line.trim();
        if (trimmed.startsWith('#')) {
            buffer.push(trimmed);
        } else if (trimmed.length === 0) {
            // Blank line breaks the association — an intent comment must sit
            // directly above its dependency to count.
            buffer = [];
        }
        // Any other non-comment, non-dep line (rare inside deps) is ignored
        // and does not clear the buffer, tolerating wrapped YAML values.
    }

    return intents;
}

/**
 * Attach parsed pin intents to scan results. Returns a new array; results whose
 * package has no documented intent are returned with `pinIntent: null`.
 */
export function attachPinIntents<T extends { package: { name: string } }>(
    results: readonly T[],
    pubspecContent: string,
): Array<T & { pinIntent: PinIntent | null }> {
    const intents = parsePinIntents(pubspecContent);
    return results.map(r => ({
        ...r,
        pinIntent: intents.get(r.package.name) ?? null,
    }));
}
