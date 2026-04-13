/**
 * Pubspec validation diagnostics.
 *
 * Checks pubspec.yaml for common issues:
 * - `avoid_any_version`: dependencies using `any` version constraint
 * - `dependencies_ordering`: dependencies not sorted alphabetically
 * - `prefer_caret_version_syntax`: version constraints without `^` prefix
 * - `avoid_dependency_overrides`: dependency_overrides entries without comment
 * - `prefer_publish_to_none`: missing `publish_to: none` for private packages
 * - `prefer_pinned_version_syntax`: caret constraints where exact pins preferred
 * - `pubspec_ordering`: top-level fields not in recommended order
 * - `newline_before_pubspec_entry`: missing blank line before top-level sections
 * - `prefer_commenting_pubspec_ignores`: ignored_advisories without comments
 * - `add_resolution_workspace`: workspace root missing resolution field
 * - `prefer_l10n_yaml_config`: inline l10n config instead of l10n.yaml
 *
 * Follows the same pattern as SdkDiagnostics / VibrancyDiagnostics:
 * construct with a DiagnosticCollection, call update() with file URI
 * and content, diagnostics appear inline on pubspec.yaml.
 */

import * as vscode from 'vscode';

const SOURCE = 'Saropa Lints';

// ── Types ──────────────────────────────────────────────────────

interface DepEntry {
    /** Package name as written in pubspec. */
    readonly name: string;
    /** Raw version constraint string, or empty if SDK/path/git dep. */
    readonly constraint: string;
    /** 0-based line number in the file. */
    readonly line: number;
    /** Column where the package name starts. */
    readonly startChar: number;
    /** Column where the package name ends. */
    readonly endChar: number;
}

interface DepSection {
    /** Section header name (e.g. "dependencies", "dev_dependencies"). */
    readonly header: string;
    /** Entries in source order. */
    readonly entries: DepEntry[];
}

// ── Parsing ────────────────────────────────────────────────────

/**
 * Find all dependency sections and their entries.
 *
 * Handles these forms:
 *   cupertino_icons: ^1.0.2
 *   flutter:
 *     sdk: flutter
 *   path_provider:          (no constraint — hosted latest)
 *   bloc: '>=8.0.0 <9.0.0'
 *   http: any
 *
 * Skips SDK/path/git deps (they have sub-keys, not version strings).
 */
function parseDependencySections(content: string): DepSection[] {
    const lines = content.split('\n');
    const sections: DepSection[] = [];
    let current: DepSection | null = null;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];

        // Top-level section header (no leading whitespace)
        const headerMatch = line.match(
            /^(dependencies|dev_dependencies|dependency_overrides)\s*:/,
        );
        if (headerMatch) {
            current = { header: headerMatch[1], entries: [] };
            sections.push(current);
            continue;
        }

        // Any other top-level key ends the current section
        if (current && /^\S/.test(line)) {
            current = null;
            continue;
        }

        if (!current) { continue; }

        // Dependency entry: 2-space indent, word characters, colon
        const depMatch = line.match(/^( {2})(\w[\w_]*)(\s*:\s*)(.*)/);
        if (!depMatch) { continue; }

        const name = depMatch[2];
        const rawValue = depMatch[4].trim();

        // Skip SDK/path/git deps (value is empty and next line is indented
        // further, or value is empty meaning "hosted latest")
        const nextLine = i + 1 < lines.length ? lines[i + 1] : '';
        const hasSubKey = /^ {4}\S/.test(nextLine);

        // Extract constraint: quoted or unquoted value on same line
        let constraint = '';
        if (rawValue && !hasSubKey) {
            // Strip surrounding quotes: '^1.0.0' or "^1.0.0"
            constraint = rawValue.replace(/^['"]|['"]$/g, '');
        }

        current.entries.push({
            name,
            constraint,
            line: i,
            startChar: depMatch[1].length,
            endChar: depMatch[1].length + name.length,
        });
    }

    return sections;
}

// ── Diagnostic helpers ─────────────────────────────────────────

function createDiag(
    entry: DepEntry,
    message: string,
    severity: vscode.DiagnosticSeverity,
    code: string,
): vscode.Diagnostic {
    const range = new vscode.Range(
        entry.line, entry.startChar,
        entry.line, entry.endChar,
    );
    const diag = new vscode.Diagnostic(range, message, severity);
    diag.source = SOURCE;
    diag.code = code;
    return diag;
}

/**
 * Create a diagnostic on an arbitrary line (not tied to a DepEntry).
 * Used by checks that inspect top-level YAML structure rather than
 * individual dependency entries.
 */
function createLineDiag(
    lineIndex: number,
    startChar: number,
    endChar: number,
    message: string,
    severity: vscode.DiagnosticSeverity,
    code: string,
): vscode.Diagnostic {
    const range = new vscode.Range(
        lineIndex, startChar,
        lineIndex, endChar,
    );
    const diag = new vscode.Diagnostic(range, message, severity);
    diag.source = SOURCE;
    diag.code = code;
    return diag;
}

// ── Rule checks ────────────────────────────────────────────────

/**
 * avoid_any_version: flag `any` version constraints.
 *
 * Using `any` allows every version including major breaking changes.
 * This makes builds non-reproducible and can pull in incompatible
 * transitive dependencies.
 */
function checkAnyVersion(
    sections: DepSection[],
    diagnostics: vscode.Diagnostic[],
): void {
    for (const section of sections) {
        for (const entry of section.entries) {
            if (entry.constraint === 'any') {
                diagnostics.push(createDiag(
                    entry,
                    `'${entry.name}' uses 'any' version constraint — `
                    + 'pin to a specific range (e.g. ^1.0.0) for reproducible builds',
                    vscode.DiagnosticSeverity.Warning,
                    'avoid_any_version',
                ));
            }
        }
    }
}

/**
 * dependencies_ordering: flag unsorted dependency lists.
 *
 * Alphabetically sorted dependencies are easier to scan, reduce
 * merge conflicts, and match `dart pub add` default behavior.
 */
function checkDependencyOrdering(
    sections: DepSection[],
    diagnostics: vscode.Diagnostic[],
): void {
    for (const section of sections) {
        const names = section.entries.map(e => e.name);
        const sorted = [...names].sort((a, b) =>
            a.toLowerCase().localeCompare(b.toLowerCase()),
        );

        for (let i = 0; i < names.length; i++) {
            if (names[i] !== sorted[i]) {
                // Report on the first out-of-order entry only, to avoid
                // flooding the user with N diagnostics for one unsorted block
                const entry = section.entries[i];
                diagnostics.push(createDiag(
                    entry,
                    `'${section.header}' are not sorted alphabetically — `
                    + `'${entry.name}' should come after '${sorted[i]}'`,
                    vscode.DiagnosticSeverity.Information,
                    'dependencies_ordering',
                ));
                break;
            }
        }
    }
}

/**
 * prefer_caret_version_syntax: flag hosted deps without `^` prefix.
 *
 * Caret syntax (`^1.2.3`) is the Dart convention for "compatible with"
 * and is what `dart pub add` generates. Bare versions (`1.2.3`) pin
 * to an exact version, which is rarely intended. Range syntax
 * (`>=1.0.0 <2.0.0`) is valid but verbose.
 *
 * Skips: empty constraints (hosted latest), `any`, and constraints
 * that already use `^` or are complex range expressions.
 */
function checkCaretSyntax(
    sections: DepSection[],
    diagnostics: vscode.Diagnostic[],
): void {
    for (const section of sections) {
        // Skip dependency_overrides — overrides often use exact versions
        // or path/git refs intentionally
        if (section.header === 'dependency_overrides') { continue; }

        for (const entry of section.entries) {
            const c = entry.constraint;
            // Skip: no constraint (hosted latest), already caret, any, or
            // complex range (contains >= or < or spaces)
            if (!c || c === 'any' || c.startsWith('^')) { continue; }
            if (c.includes('>=') || c.includes('<') || c.includes(' ')) {
                continue;
            }

            // What remains: bare version like "1.2.3" or "1.0.0"
            if (/^\d+\.\d+\.\d+/.test(c)) {
                diagnostics.push(createDiag(
                    entry,
                    `'${entry.name}: ${c}' pins to an exact version — `
                    + `use '^${c}' for compatible updates`,
                    vscode.DiagnosticSeverity.Information,
                    'prefer_caret_version_syntax',
                ));
            }
        }
    }
}

/**
 * avoid_dependency_overrides: flag override entries without a comment.
 *
 * `dependency_overrides` bypass normal version resolution, which can
 * mask breaking changes and cause subtle bugs in production. Each
 * override should have a comment (same line or line above) explaining
 * why the override exists.
 */
function checkDependencyOverrides(
    sections: DepSection[],
    lines: string[],
    diagnostics: vscode.Diagnostic[],
): void {
    for (const section of sections) {
        if (section.header !== 'dependency_overrides') { continue; }

        for (const entry of section.entries) {
            // Check for inline comment on the entry line
            const entryLine = lines[entry.line] ?? '';
            if (entryLine.includes('#')) { continue; }

            // Check for comment on the line above the entry
            if (entry.line > 0) {
                const prevLine = (lines[entry.line - 1] ?? '').trim();
                if (prevLine.startsWith('#')) { continue; }
            }

            diagnostics.push(createDiag(
                entry,
                `'${entry.name}' in dependency_overrides has no comment — `
                + 'add a comment explaining why this override is needed',
                vscode.DiagnosticSeverity.Warning,
                'avoid_dependency_overrides',
            ));
        }
    }
}

/**
 * prefer_publish_to_none: flag pubspec files missing `publish_to: none`.
 *
 * Most internal/private packages should not be published to pub.dev.
 * If `publish_to` is absent, the package can be accidentally published
 * with `dart pub publish`. Adding `publish_to: none` prevents this.
 *
 * Skips: packages that already have any `publish_to` field (whether
 * `none` or a custom registry URL).
 */
function checkPublishToNone(
    lines: string[],
    diagnostics: vscode.Diagnostic[],
): void {
    // Look for existing publish_to field at the top level
    const hasPublishTo = lines.some(
        line => /^publish_to\s*:/.test(line),
    );
    if (hasPublishTo) { return; }

    // Find the `name:` line to attach the diagnostic to
    const nameLineIndex = lines.findIndex(
        line => /^name\s*:/.test(line),
    );
    if (nameLineIndex < 0) { return; }

    // Extract the package name for the message
    const nameMatch = lines[nameLineIndex].match(/^name\s*:\s*(\S+)/);
    const pkgName = nameMatch ? nameMatch[1] : 'this package';

    const range = new vscode.Range(
        nameLineIndex, 0,
        nameLineIndex, lines[nameLineIndex].length,
    );
    const diag = new vscode.Diagnostic(
        range,
        `'${pkgName}' has no 'publish_to' field — `
        + "add 'publish_to: none' to prevent accidental publishing",
        vscode.DiagnosticSeverity.Information,
    );
    diag.source = SOURCE;
    diag.code = 'prefer_publish_to_none';
    diagnostics.push(diag);
}

/**
 * prefer_pinned_version_syntax: flag caret constraints, prefer exact pins.
 *
 * Stylistic opposite of `prefer_caret_version_syntax`. Some workflows
 * (CI reproducibility, monorepos) prefer exact version pins (`1.2.3`)
 * over caret ranges (`^1.2.3`). Users enable one or the other via
 * the init wizard — both should never be active simultaneously.
 *
 * Skips: empty constraints (hosted latest), `any`, range expressions,
 * and `dependency_overrides` (overrides intentionally use exact pins).
 */
function checkPinnedVersionSyntax(
    sections: DepSection[],
    diagnostics: vscode.Diagnostic[],
): void {
    for (const section of sections) {
        // Skip dependency_overrides — exact pins are expected there
        if (section.header === 'dependency_overrides') { continue; }

        for (const entry of section.entries) {
            const c = entry.constraint;
            // Only flag caret versions like ^1.2.3
            if (!c || !c.startsWith('^')) { continue; }

            const bare = c.substring(1);
            if (/^\d+\.\d+\.\d+/.test(bare)) {
                diagnostics.push(createDiag(
                    entry,
                    `'${entry.name}: ${c}' uses a caret range — `
                    + `use '${bare}' to pin the exact version`,
                    vscode.DiagnosticSeverity.Information,
                    'prefer_pinned_version_syntax',
                ));
            }
        }
    }
}

/**
 * Recommended top-level field order for pubspec.yaml, based on the
 * Dart pub.dev conventions. Fields not in this list are allowed
 * anywhere without triggering a diagnostic.
 */
const PUBSPEC_FIELD_ORDER = [
    'name',
    'description',
    'version',
    'publish_to',
    'homepage',
    'repository',
    'issue_tracker',
    'documentation',
    'environment',
    'dependencies',
    'dev_dependencies',
    'dependency_overrides',
    'flutter',
];

/**
 * pubspec_ordering: flag top-level fields not in recommended order.
 *
 * The Dart/pub.dev convention places `name` first, then metadata,
 * then environment, then dependencies, then flutter config. Following
 * this order makes pubspec files predictable and easier to scan.
 *
 * Only checks fields that appear in PUBSPEC_FIELD_ORDER; unknown
 * fields (e.g. custom keys, `resolution`, `workspace`) are ignored.
 * Reports only the first out-of-order field to avoid flooding.
 */
function checkPubspecOrdering(
    lines: string[],
    diagnostics: vscode.Diagnostic[],
): void {
    // Collect top-level fields and their line numbers, in source order
    const found: { key: string; line: number; length: number }[] = [];
    for (let i = 0; i < lines.length; i++) {
        const match = lines[i].match(/^(\w[\w_]*)\s*:/);
        if (!match) { continue; }
        const key = match[1];
        // Only track known fields — custom keys are allowed anywhere
        if (PUBSPEC_FIELD_ORDER.includes(key)) {
            found.push({ key, line: i, length: lines[i].length });
        }
    }

    if (found.length < 2) { return; }

    // Check that found fields appear in the same relative order as
    // PUBSPEC_FIELD_ORDER. Compare adjacent pairs.
    for (let i = 1; i < found.length; i++) {
        const prevIdx = PUBSPEC_FIELD_ORDER.indexOf(found[i - 1].key);
        const currIdx = PUBSPEC_FIELD_ORDER.indexOf(found[i].key);

        if (currIdx < prevIdx) {
            // Current field should come before the previous one
            const curr = found[i];
            diagnostics.push(createLineDiag(
                curr.line, 0, curr.length,
                `'${curr.key}' should appear before '${found[i - 1].key}' — `
                + 'follow the recommended pubspec field order',
                vscode.DiagnosticSeverity.Information,
                'pubspec_ordering',
            ));
            // Report only the first violation to keep diagnostics actionable
            return;
        }
    }
}

/**
 * newline_before_pubspec_entry: flag top-level sections without a
 * preceding blank line.
 *
 * Blank lines between major sections improve readability. This check
 * flags any top-level key that is not the first line and is not
 * preceded by at least one blank line (or comment-only line).
 */
function checkNewlineBeforeEntry(
    lines: string[],
    diagnostics: vscode.Diagnostic[],
): void {
    for (let i = 1; i < lines.length; i++) {
        const match = lines[i].match(/^(\w[\w_]*)\s*:/);
        if (!match) { continue; }

        // Check line above — should be blank or a comment
        const prev = lines[i - 1].trim();
        if (prev === '' || prev.startsWith('#')) { continue; }

        // The previous line is non-blank content, so this section has
        // no visual separator
        diagnostics.push(createLineDiag(
            i, 0, lines[i].length,
            `add a blank line before '${match[1]}:' for readability`,
            vscode.DiagnosticSeverity.Information,
            'newline_before_pubspec_entry',
        ));
    }
}

/**
 * prefer_commenting_pubspec_ignores: flag ignored_advisories entries
 * without an explanatory comment.
 *
 * The `ignored_advisories` field in pubspec.yaml lists security
 * advisory IDs that `dart pub` should skip. Each suppressed advisory
 * should have a comment explaining why it is safe to ignore —
 * otherwise reviewers cannot assess the risk.
 *
 * Expected format:
 *   ignored_advisories:
 *     # Not exploitable in our usage — we never parse untrusted XML
 *     - GHSA-xxxx-yyyy-zzzz
 */
function checkCommentingPubspecIgnores(
    lines: string[],
    diagnostics: vscode.Diagnostic[],
): void {
    let inIgnoredAdvisories = false;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];

        // Detect the ignored_advisories section header
        if (/^ignored_advisories\s*:/.test(line)) {
            inIgnoredAdvisories = true;
            continue;
        }

        // Any other top-level key ends the section
        if (inIgnoredAdvisories && /^\S/.test(line) && line.trim() !== '') {
            inIgnoredAdvisories = false;
            continue;
        }

        if (!inIgnoredAdvisories) { continue; }

        // List entry: "  - GHSA-xxxx-yyyy-zzzz"
        const entryMatch = line.match(/^( +- +)(\S+)/);
        if (!entryMatch) { continue; }

        // Check for inline comment on the entry line
        if (line.includes('#')) { continue; }

        // Check for comment on the line above
        if (i > 0) {
            const prevLine = lines[i - 1].trim();
            if (prevLine.startsWith('#')) { continue; }
        }

        const advisory = entryMatch[2];
        const startChar = entryMatch[1].length;
        diagnostics.push(createLineDiag(
            i, startChar, startChar + advisory.length,
            `ignored advisory '${advisory}' has no comment — `
            + 'add a comment explaining why this advisory is safe to ignore',
            vscode.DiagnosticSeverity.Information,
            'prefer_commenting_pubspec_ignores',
        ));
    }
}

/**
 * add_resolution_workspace: flag workspace roots missing `resolution`.
 *
 * Dart 3.x monorepos use `workspace:` in the root pubspec to list
 * sub-packages. The root should also declare `resolution: workspace`
 * to enable shared dependency resolution. If `workspace:` is present
 * but `resolution:` is absent, sub-packages may resolve dependencies
 * independently, defeating the purpose of a workspace.
 */
function checkResolutionWorkspace(
    lines: string[],
    diagnostics: vscode.Diagnostic[],
): void {
    let workspaceLine = -1;
    let hasResolution = false;

    for (let i = 0; i < lines.length; i++) {
        if (/^workspace\s*:/.test(lines[i])) {
            workspaceLine = i;
        }
        if (/^resolution\s*:/.test(lines[i])) {
            hasResolution = true;
        }
    }

    // Only flag if this is a workspace root (has workspace:) but
    // missing resolution field
    if (workspaceLine < 0 || hasResolution) { return; }

    diagnostics.push(createLineDiag(
        workspaceLine, 0, lines[workspaceLine].length,
        "workspace root is missing 'resolution: workspace' — "
        + 'add it for shared dependency resolution across sub-packages',
        vscode.DiagnosticSeverity.Information,
        'add_resolution_workspace',
    ));
}

/**
 * prefer_l10n_yaml_config: flag inline l10n configuration.
 *
 * Flutter's `generate: true` under the `flutter:` section enables
 * code generation for localization. The l10n configuration (template
 * ARB file, output class, etc.) can live inline in pubspec.yaml or
 * in a dedicated `l10n.yaml` file. A separate file is preferred
 * because it keeps pubspec focused on dependencies and metadata,
 * and is the approach recommended by Flutter documentation.
 *
 * This check flags `generate: true` under the `flutter:` section.
 */
function checkL10nYamlConfig(
    lines: string[],
    diagnostics: vscode.Diagnostic[],
): void {
    let inFlutterSection = false;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];

        // Detect flutter: section header
        if (/^flutter\s*:/.test(line)) {
            inFlutterSection = true;
            continue;
        }

        // Any other top-level key ends the flutter section
        if (inFlutterSection && /^\S/.test(line) && line.trim() !== '') {
            inFlutterSection = false;
            continue;
        }

        if (!inFlutterSection) { continue; }

        // Check for generate: true under flutter:
        const genMatch = line.match(/^( +)(generate)\s*:\s*true/);
        if (!genMatch) { continue; }

        const startChar = genMatch[1].length;
        const endChar = startChar + genMatch[2].length;
        diagnostics.push(createLineDiag(
            i, startChar, endChar,
            "inline 'generate: true' under flutter — "
            + "prefer a dedicated 'l10n.yaml' file for localization config",
            vscode.DiagnosticSeverity.Information,
            'prefer_l10n_yaml_config',
        ));
        return;
    }
}

// ── Public API ─────────────────────────────────────────────────

export class PubspecValidation {
    /**
     * When true, run `prefer_pinned_version_syntax` instead of
     * `prefer_caret_version_syntax`. These are mutually exclusive
     * stylistic rules — the user chooses one via configuration.
     * Default: false (prefer caret syntax, matching `dart pub add`).
     */
    preferPinnedVersions = false;

    constructor(
        private readonly _collection: vscode.DiagnosticCollection,
    ) {}

    /** Run all pubspec checks and update inline diagnostics. */
    update(uri: vscode.Uri, content: string): void {
        const diagnostics: vscode.Diagnostic[] = [];
        const sections = parseDependencySections(content);
        const lines = content.split('\n');

        checkAnyVersion(sections, diagnostics);
        checkDependencyOrdering(sections, diagnostics);
        // Stylistic pair: run one or the other, never both
        if (this.preferPinnedVersions) {
            checkPinnedVersionSyntax(sections, diagnostics);
        } else {
            checkCaretSyntax(sections, diagnostics);
        }
        checkDependencyOverrides(sections, lines, diagnostics);
        checkPublishToNone(lines, diagnostics);
        checkPubspecOrdering(lines, diagnostics);
        checkNewlineBeforeEntry(lines, diagnostics);
        checkCommentingPubspecIgnores(lines, diagnostics);
        checkResolutionWorkspace(lines, diagnostics);
        checkL10nYamlConfig(lines, diagnostics);

        this._collection.set(uri, diagnostics);
    }

    clear(): void {
        this._collection.clear();
    }
}

/**
 * Register pubspec.yaml listeners that run validation checks when
 * the file is opened or edited. Call from extension activate().
 */
export function registerPubspecValidation(
    context: vscode.ExtensionContext,
): PubspecValidation {
    const collection = vscode.languages.createDiagnosticCollection(
        'saropa-pubspec',
    );
    const validator = new PubspecValidation(collection);

    context.subscriptions.push(collection);

    const isPubspec = (doc: vscode.TextDocument) =>
        doc.fileName.endsWith('pubspec.yaml');

    const refresh = (doc: vscode.TextDocument) => {
        if (!isPubspec(doc)) { return; }
        validator.update(doc.uri, doc.getText());
    };

    // Debounce edits (300ms) to avoid re-checking on every keystroke
    let debounceTimer: ReturnType<typeof setTimeout> | null = null;
    const debouncedRefresh = (doc: vscode.TextDocument) => {
        if (debounceTimer) { clearTimeout(debounceTimer); }
        debounceTimer = setTimeout(() => { refresh(doc); }, 300);
    };

    // Fire immediately on open
    context.subscriptions.push(
        vscode.workspace.onDidOpenTextDocument(doc => { refresh(doc); }),
    );
    // Fire with debounce on edit
    context.subscriptions.push(
        vscode.workspace.onDidChangeTextDocument(e => {
            debouncedRefresh(e.document);
        }),
    );
    // Fire for already-open pubspec.yaml editors
    for (const editor of vscode.window.visibleTextEditors) {
        if (isPubspec(editor.document)) {
            refresh(editor.document);
        }
    }

    return validator;
}
