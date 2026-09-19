/**
 * Derives which packages the Flutter SDK pins to an exact version, from the
 * real environment: the SDK's own package pubspecs (e.g. flutter depends on
 * `meta: 1.18.0`), cross-checked against the locked version in pubspec.lock.
 * Falls back to the documented SDK_PINNED_PACKAGES table only when nothing
 * can be derived (no Flutter SDK found / non-Flutter project).
 */

import * as fs from 'fs';
import * as path from 'path';
import { execFile } from 'child_process';
import { SDK_PACKAGES } from '../sdk-packages';

/**
 * What counts as a pin: ONLY an exact version (`meta: 1.18.0`) in an SDK
 * package's `dependencies:`. A caret/range entry (`meta: ^1.18.3`, `>=1 <2`)
 * is a floor/ceiling, not a pin: any version inside it is allowed, so it never
 * yields a pin here (inventing one caused false "sdk-blocked" verdicts on
 * newer Flutter). Whether a range excludes a target is decided by the
 * data-driven checks in upgrade-blast-radius (lock + dependents' ranges).
 */
const EXACT = /^\d+\.\d+\.\d+(?:[-+][\w.]+)?$/;

/** Pure: exact-version entries under `dependencies:` of an SDK pubspec. */
export function parseExactPins(pubspecYaml: string): Map<string, string> {
    const pins = new Map<string, string>();
    let inDeps = false;
    for (const raw of pubspecYaml.split(/\r?\n/)) {
        if (/^\S/.test(raw)) { inDeps = /^dependencies:\s*$/.test(raw); continue; }
        if (!inDeps) { continue; }
        const m = raw.match(/^ {2}([\w-]+):\s*["']?([^\s"'#]+)["']?\s*(?:#.*)?$/);
        if (m && EXACT.test(m[2])) { pins.set(m[1], m[2]); }
    }
    return pins;
}

/** Pure: package -> locked version from pubspec.lock content. */
export function parseLockedVersions(lock: string): Map<string, string> {
    const out = new Map<string, string>();
    let name: string | null = null;
    for (const line of lock.split(/\r?\n/)) {
        const n = line.match(/^ {2}([\w-]+):\s*$/);
        if (n) { name = n[1]; continue; }
        const v = line.match(/^ {4}version:\s*"([^"]+)"/);
        if (v && name) { out.set(name, v[1]); }
    }
    return out;
}

/**
 * Pure: merge SDK-package pins; a locked version wins over the SDK pubspec's
 * (it is what actually resolved). Empty map = nothing derived.
 */
export function mergePins(
    sdkPubspecs: readonly string[], lock: string | null,
): Map<string, string> {
    const pins = new Map<string, string>();
    for (const y of sdkPubspecs) {
        for (const [k, v] of parseExactPins(y)) { pins.set(k, v); }
    }
    const locked = lock ? parseLockedVersions(lock) : new Map<string, string>();
    for (const k of pins.keys()) {
        const l = locked.get(k);
        if (l && !SDK_PACKAGES.has(k)) { pins.set(k, l); }
    }
    return pins;
}

/** Default flutterRoot lookup: `flutter --version --machine`. Null on failure. */
function detectFlutterRoot(): Promise<string | null> {
    return new Promise(resolve => {
        execFile('flutter', ['--version', '--machine'],
            { timeout: 15000, shell: process.platform === 'win32' },
            (err, stdout) => {
                if (err) { return resolve(null); }
                try { resolve(JSON.parse(stdout).flutterRoot ?? null); }
                catch { resolve(null); }
            });
    });
}

/** Derived SDK pins; empty map when nothing derivable. */
export async function deriveSdkPins(
    workspaceRoot: string,
    findFlutterRoot: () => Promise<string | null> = detectFlutterRoot,
): Promise<Map<string, string>> {
    return (await deriveSdkPinsOrNull(workspaceRoot, findFlutterRoot)) ?? new Map();
}

/**
 * Like deriveSdkPins but null when the SDK could not be inspected (so callers
 * may apply curated fallback pins); an empty map means "SDK read, no exact pins".
 */
export async function deriveSdkPinsOrNull(
    workspaceRoot: string,
    findFlutterRoot: () => Promise<string | null> = detectFlutterRoot,
): Promise<Map<string, string> | null> {
    try {
        const root = await findFlutterRoot();
        if (!root) { return null; }
        const specs: string[] = [];
        for (const pkg of SDK_PACKAGES) {
            try {
                specs.push(fs.readFileSync(
                    path.join(root, 'packages', pkg, 'pubspec.yaml'), 'utf8'));
            } catch { /* not every SDK package ships a pubspec */ }
        }
        let lock: string | null = null;
        try { lock = fs.readFileSync(path.join(workspaceRoot, 'pubspec.lock'), 'utf8'); }
        catch { /* no lock yet */ }
        if (specs.length === 0) { return null; }
        return mergePins(specs, lock);
    } catch {
        return null;
    }
}
