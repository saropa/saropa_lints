/**
 * Content-Security-Policy `content` string for a webview.
 *
 * Splits `style-src-elem`/`style-src-attr` rather than a single combined
 * `style-src 'nonce-X' 'unsafe-inline'` directive: per the CSP3 spec, once a directive
 * contains a nonce-source, `'unsafe-inline'` is ignored for the WHOLE directive — `<style>`
 * blocks AND inline `style="..."` attributes AND CSSOM `.style.x = ` writes alike (attributes
 * and CSSOM writes cannot carry a nonce, so they'd otherwise be silently dropped, e.g. a
 * gauge or bar-fill rendering at zero width/empty). `style-src-elem` carries the nonce (for
 * `<style>` blocks); `style-src-attr` carries `'unsafe-inline'` alone (no nonce) so
 * attribute/CSSOM writes are actually honored. Pass `scripts: false` for a webview with no
 * `<script>` tag to omit `script-src` entirely.
 *
 * Also emits a legacy `style-src 'nonce-X' 'unsafe-inline'` fallback (Chrome < 75 /
 * pre-2019 Electron): defense-in-depth only — `style-src-elem`/`style-src-attr` shipped in
 * Chrome 75, and our minimum VS Code `^1.74.0` bundles Electron 19 (Chrome 102), so the
 * split directives work on every supported install. The fallback exists for hypothetical
 * downlevel embedders; on any actual VS Code version, CSP directive-precedence rules mean
 * the browser consults only the more specific pair and ignores this line entirely.
 */
export function buildWebviewCsp(nonce: string, options: { scripts?: boolean } = {}): string {
    return [
        "default-src 'none'",
        `style-src 'nonce-${nonce}' 'unsafe-inline'`,
        `style-src-elem 'nonce-${nonce}'`,
        "style-src-attr 'unsafe-inline'",
        options.scripts === false ? '' : `script-src 'nonce-${nonce}'`,
    ]
        .filter(Boolean)
        .join('; ');
}

/** Random nonce for Content-Security-Policy `script-src` / `style-src` on webview `<script>` / `<style>`. */
export function createWebviewCspNonce(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let text = '';
    for (let i = 0; i < 32; i++) {
        text += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return text;
}

/** Escape text for safe inclusion in HTML content and attributes. */
export function escapeHtml(text: string): string {
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

// Pre-built RegExp constructors instead of regex literals so the U+2028 / U+2029
// pattern characters are spelled with explicit unicode escapes in source — keeps
// the file readable in any editor and immune to invisible-char normalization.
const SCRIPT_BLOCK_LINE_SEP = new RegExp('\\u2028', 'g');
const SCRIPT_BLOCK_PARA_SEP = new RegExp('\\u2029', 'g');

/**
 * Apply HTML-safe escaping to an already-serialized JSON string so it can
 * be embedded inside a `<script>` element without breaking out of the
 * script context. Use when the caller already holds a JSON string (e.g.
 * from a prior JSON.stringify call) and only the escaping step is needed.
 *
 * See jsonForScriptBlock for the full rationale on each replacement.
 */
export function escapeJsonStringForScriptBlock(jsonString: string): string {
    return jsonString
        .replace(/</g, '\\u003c')
        .replace(/&/g, '\\u0026')
        .replace(SCRIPT_BLOCK_LINE_SEP, '\\u2028')
        .replace(SCRIPT_BLOCK_PARA_SEP, '\\u2029');
}

/**
 * Serialize a value to JSON for embedding inside a `<script>` element.
 *
 * `JSON.stringify` alone is NOT safe inside a script block: a string containing
 * the substring `</script>` (or `<!--`) terminates the script context and the
 * remainder is parsed as HTML. Escaping `<` to `<` blocks that breakout;
 * `&` and the U+2028 / U+2029 separators (legal whitespace in JSON, but illegal
 * inside a JS string literal in pre-ES2019 parsers) are escaped for parser
 * strictness. Use anywhere a registry / violation / rule name — i.e. any value
 * not under our control — is interpolated into an inline `<script>`.
 */
export function jsonForScriptBlock(value: unknown): string {
    return escapeJsonStringForScriptBlock(JSON.stringify(value));
}

/**
 * Resolve the canonical repository URL from a VibrancyResult's GitHub or pub.dev data.
 * Returns empty string when no repository URL is available.
 * Strips trailing slashes for consistent URL construction (e.g. appending `/issues`).
 */
export function resolveRepoUrl(
    githubRepoUrl: string | undefined | null,
    pubDevRepoUrl: string | undefined | null,
): string {
    return (githubRepoUrl ?? pubDevRepoUrl ?? '').replace(/\/+$/, '');
}
