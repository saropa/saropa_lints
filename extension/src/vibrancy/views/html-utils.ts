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
    return JSON.stringify(value)
        .replace(/</g, '\\u003c')
        .replace(/&/g, '\\u0026')
        .replace(SCRIPT_BLOCK_LINE_SEP, '\\u2028')
        .replace(SCRIPT_BLOCK_PARA_SEP, '\\u2029');
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
