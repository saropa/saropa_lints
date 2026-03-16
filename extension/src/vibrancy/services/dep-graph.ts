import { DepEdge } from '../types';
import { runDartPubDeps } from './flutter-cli';

/** A package node from `dart pub deps --json`. */
export interface DepGraphPackage {
    readonly name: string;
    readonly version: string;
    readonly kind: string;
    readonly dependencies: readonly string[];
}

/** Result of parsing `dart pub deps --json`. */
export interface DepGraphResult {
    readonly root: string;
    readonly packages: readonly DepGraphPackage[];
    readonly success: boolean;
}

/** Run `dart pub deps --json` and parse the output. */
export async function fetchDepGraph(
    cwd: string,
): Promise<DepGraphResult> {
    const result = await runDartPubDeps(cwd);
    if (!result.success) {
        return { root: '', packages: [], success: false };
    }
    return { ...parseDepGraphJson(result.output), success: true };
}

/** Parse the JSON output of `dart pub deps --json`. */
export function parseDepGraphJson(
    jsonOutput: string,
): { root: string; packages: DepGraphPackage[] } {
    const jsonStart = jsonOutput.indexOf('{');
    if (jsonStart < 0) { return { root: '', packages: [] }; }

    let parsed: Record<string, unknown>;
    try {
        parsed = JSON.parse(jsonOutput.substring(jsonStart));
    } catch {
        return { root: '', packages: [] };
    }

    const root = typeof parsed.root === 'string' ? parsed.root : '';
    const rawPackages = parsed.packages;
    if (!Array.isArray(rawPackages)) { return { root, packages: [] }; }

    const packages: DepGraphPackage[] = [];
    for (const pkg of rawPackages) {
        if (!pkg || typeof pkg.name !== 'string') { continue; }
        packages.push({
            name: pkg.name,
            version: typeof pkg.version === 'string' ? pkg.version : '',
            kind: typeof pkg.kind === 'string' ? pkg.kind : '',
            dependencies: Array.isArray(pkg.dependencies)
                ? pkg.dependencies.filter(
                    (d: unknown) => typeof d === 'string',
                )
                : [],
        });
    }
    return { root, packages };
}

/**
 * Build a reverse-dependency map: for each package, who depends on it?
 * Key = dependency name, Value = list of packages that depend on it.
 */
export function buildReverseDeps(
    packages: readonly DepGraphPackage[],
): Map<string, DepEdge[]> {
    const reverse = new Map<string, DepEdge[]>();
    for (const pkg of packages) {
        for (const dep of pkg.dependencies) {
            let edges = reverse.get(dep);
            if (!edges) {
                edges = [];
                reverse.set(dep, edges);
            }
            edges.push({ dependentPackage: pkg.name });
        }
    }
    return reverse;
}
