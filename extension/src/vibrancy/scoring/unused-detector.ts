const SDK_PACKAGES = new Set([
    'flutter', 'flutter_test', 'flutter_localizations',
    'flutter_web_plugins', 'flutter_driver',
]);

const PLATFORM_SUFFIXES = [
    '_android', '_ios', '_web', '_windows', '_macos', '_linux',
    '_platform_interface',
];

/**
 * Detect declared dependencies that have no matching package import.
 * Pure function — no I/O.
 */
export function detectUnused(
    declared: readonly string[],
    imported: ReadonlySet<string>,
): string[] {
    return declared.filter(name =>
        !imported.has(name)
        && !SDK_PACKAGES.has(name)
        && !isPlatformPlugin(name, imported),
    );
}

/**
 * Returns true if the package is treated as a platform/federated plugin and
 * should not be reported as unused. Uses known suffixes and a parent-package heuristic.
 */
function isPlatformPlugin(name: string, imported: ReadonlySet<string>): boolean {
    // 1) Existing suffix check for known platform implementation packages.
    if (PLATFORM_SUFFIXES.some(suffix => name.endsWith(suffix))) {
        return true;
    }

    // 2) Parent-package heuristic:
    // Federated plugins may use arbitrary names (not only `${parent}_${platform}`).
    // If the declared dependency starts with an imported parent plugin + '_',
    // it's likely a platform implementation of that parent.
    for (const imp of imported) {
        if (SDK_PACKAGES.has(imp)) continue;
        if (name.startsWith(imp + '_') && name.length > imp.length + 1) {
            return true;
        }
    }

    return false;
}
