/** Build a Package URL (PURL) for a pub.dev package. */
export function buildPurl(name: string, version: string): string {
    return `pkg:pub/${encodeURIComponent(name)}@${encodeURIComponent(version)}`;
}
