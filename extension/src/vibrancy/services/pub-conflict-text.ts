/**
 * Extracts pub's own version-solving explanation from a failed
 * `dart pub get` / `dart pub deps` stderr.
 *
 * In a resolved project the analyzer must RECONSTRUCT why a dependency sits
 * where it does (the diamond / floor / forbidden detectors), because pub prints
 * nothing on success. When resolution FAILS, pub emits the authoritative reason
 * itself — the `Because … is forbidden` / `… is required` lines users paste by
 * hand. Capturing them verbatim lets the failure log carry the real cause
 * instead of a bare "version solving failed", and gives the user the exact text
 * to act on.
 *
 * Pure — no I/O.
 */

/**
 * The solver-explanation lines from `stderr`, in order, de-duplicated and
 * trimmed. Returns an empty array when the output carries no recognizable
 * solver reasoning (e.g. a missing-`dart` or permissions failure).
 */
export function extractPubConflictExplanation(stderr: string): string[] {
    if (!stderr) { return []; }

    const lines: string[] = [];
    const seen = new Set<string>();

    for (const raw of stderr.split(/\r?\n/)) {
        const line = raw.trim();
        if (!line) { continue; }
        if (!isSolverReason(line)) { continue; }
        if (seen.has(line)) { continue; }
        seen.add(line);
        lines.push(line);
    }

    return lines;
}

/**
 * True when a line is part of pub's version-solving explanation. Matches the
 * solver's own vocabulary ("Because", "depends on", "is forbidden",
 * "is required", "which depends on", "version solving failed") rather than
 * generic stderr so a tool/permissions error is not misread as a conflict.
 */
function isSolverReason(line: string): boolean {
    return /^Because\b/.test(line)
        || /\bis forbidden\b/.test(line)
        || /\bis required\b/.test(line)
        || /\bwhich depends on\b/.test(line)
        || /\bversion solving failed\b/i.test(line)
        || /^So, because\b/.test(line);
}
