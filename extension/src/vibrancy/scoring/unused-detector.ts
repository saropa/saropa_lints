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
        && !isPlatformPlugin(name),
    );
}

function isPlatformPlugin(name: string): boolean {
    return PLATFORM_SUFFIXES.some(suffix => name.endsWith(suffix));
}
