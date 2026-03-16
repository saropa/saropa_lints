import { PubOutdatedEntry } from '../types';
import { runDartPubOutdated } from './flutter-cli';

/** Result of running `dart pub outdated --json`. */
export interface PubOutdatedResult {
    readonly entries: readonly PubOutdatedEntry[];
    readonly success: boolean;
}

/** Run `dart pub outdated --json` and parse the output. */
export async function fetchPubOutdated(
    cwd: string,
): Promise<PubOutdatedResult> {
    const result = await runDartPubOutdated(cwd);
    if (!result.success) {
        return { entries: [], success: false };
    }
    const entries = parsePubOutdatedJson(result.output);
    return { entries, success: true };
}

/** Extract version string from a pub outdated version object. */
function extractVersion(
    obj: Record<string, unknown> | null | undefined,
): string | null {
    if (!obj || typeof obj !== 'object') { return null; }
    const version = (obj as Record<string, unknown>).version;
    return typeof version === 'string' ? version : null;
}

/** Parse the JSON output of `dart pub outdated --json`. */
export function parsePubOutdatedJson(
    jsonOutput: string,
): PubOutdatedEntry[] {
    const jsonStart = jsonOutput.indexOf('{');
    if (jsonStart < 0) { return []; }

    let parsed: Record<string, unknown>;
    try {
        parsed = JSON.parse(jsonOutput.substring(jsonStart));
    } catch {
        return [];
    }

    const packages = parsed.packages;
    if (!Array.isArray(packages)) { return []; }

    const entries: PubOutdatedEntry[] = [];
    for (const pkg of packages) {
        if (!pkg || typeof pkg.package !== 'string') { continue; }
        entries.push({
            package: pkg.package,
            current: extractVersion(pkg.current),
            upgradable: extractVersion(pkg.upgradable),
            resolvable: extractVersion(pkg.resolvable),
            latest: extractVersion(pkg.latest),
        });
    }
    return entries;
}
