/**
 * Minimal pubspec dependency-spec reader used by the Vibrancy pub guard.
 *
 * Why a separate parser: `parsePubspecYaml` only reports scalar constraints for
 * `dependencies` / `dev_dependencies`. The guard must also see
 * `dependency_overrides` and the MAP forms (`sdk:`, `path:`, `git:`, `hosted:`)
 * so it can tell which entries it can verify against pubspec.lock and which it
 * cannot (and must therefore treat as "pub may re-resolve").
 */

/** How a dependency is declared. */
export type DepKind = 'hosted' | 'sdk' | 'path' | 'git' | 'other';

/** One declared dependency. */
export interface DepSpec {
    readonly name: string;
    readonly section: 'dependencies' | 'dev_dependencies' | 'dependency_overrides';
    readonly kind: DepKind;
    /** Version constraint text for hosted deps; undefined when none is declared. */
    readonly constraint?: string;
    /** `path:` value for path deps. */
    readonly path?: string;
    /** `sdk:` value (e.g. `flutter`) for sdk deps. */
    readonly sdk?: string;
}

const SECTIONS = ['dependencies', 'dev_dependencies', 'dependency_overrides'] as const;

/** Removes a trailing ` # comment` and surrounding quotes/whitespace from a YAML scalar. */
function scalar(raw: string): string {
    return raw.replace(/\s+#.*$/, '').trim().replace(/^["']|["']$/g, '');
}

/**
 * Parses dependency declarations from pubspec.yaml / pubspec_overrides.yaml
 * text. Inline-map values (`foo: {path: ..}`) and anything unrecognized are
 * reported as kind `other` so callers can refuse rather than guess.
 */
export function parseDepSpecs(yaml: string): DepSpec[] {
    const specs: DepSpec[] = [];
    let section: DepSpec['section'] | undefined;
    let current: { name: string; children: Map<string, string> } | undefined;

    // Turns the collected child keys of a map-form entry into a spec.
    const flush = (): void => {
        if (!current || !section) { current = undefined; return; }
        const c = current.children;
        let kind: DepKind = 'other';
        if (c.has('sdk')) { kind = 'sdk'; }
        else if (c.has('path')) { kind = 'path'; }
        else if (c.has('git')) { kind = 'git'; }
        // A hosted map with an explicit version is still verifiable against the lock.
        else if (c.has('hosted') && c.has('version')) { kind = 'hosted'; }
        specs.push({
            name: current.name, section, kind,
            constraint: kind === 'hosted' ? c.get('version') : undefined,
            path: c.get('path'), sdk: c.get('sdk'),
        });
        current = undefined;
    };

    for (const rawLine of yaml.split(/\r?\n/)) {
        const line = rawLine.trimEnd();
        if (line.trim() === '' || line.trimStart().startsWith('#')) { continue; }
        // Top-level key: closes any open entry and selects the section.
        if (/^\S/.test(line)) {
            flush();
            const key = /^([A-Za-z_]+)\s*:/.exec(line)?.[1];
            section = SECTIONS.find((s) => s === key);
            continue;
        }
        if (!section) { continue; }
        const entry = /^ {2}([\w.-]+)\s*:\s*(.*)$/.exec(line);
        if (entry) {
            flush();
            const value = scalar(entry[2]);
            if (value === '') {
                // Map form: children follow on deeper-indented lines.
                current = { name: entry[1], children: new Map() };
            } else if (entry[2].trim().startsWith('{')) {
                specs.push({ name: entry[1], section, kind: 'other' });
            } else {
                specs.push({ name: entry[1], section, kind: 'hosted', constraint: value });
            }
            continue;
        }
        const child = /^ {4}(\w+)\s*:\s*(.*)$/.exec(line);
        if (child && current) { current.children.set(child[1], scalar(child[2])); }
    }
    flush();
    return specs;
}

/** True when any dependency is `sdk: flutter` (selects `flutter pub get` over `dart pub get`). */
export function usesFlutterSdk(specs: readonly DepSpec[]): boolean {
    return specs.some((s) => s.kind === 'sdk' && s.sdk === 'flutter');
}
