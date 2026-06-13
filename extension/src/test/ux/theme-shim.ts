/**
 * Theme shim for the Playwright UX harness.
 *
 * VS Code webviews render against `--vscode-*` CSS variables that only exist
 * inside the host. To render the same HTML in a plain Chromium page we inject a
 * representative value for each token. The three sets below approximate the
 * stock Dark Modern, Light Modern, and Dark High Contrast themes — close enough
 * that a contrast/overflow audit is meaningful, not pixel-exact reproductions.
 *
 * The values are deliberately the real default-theme colors (not invented), so
 * an axe-core contrast failure here reflects a failure a real user would see.
 */

export type ThemeName = 'dark' | 'light' | 'hc';

/** Tokens shared by every theme (font + a couple of structural defaults). */
const COMMON: Record<string, string> = {
  'font-family':
    "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Segoe WPC', system-ui, sans-serif",
  'font-size': '13px',
  'font-weight': '400',
  'editor-font-family': "'Cascadia Code', Consolas, 'Courier New', monospace",
};

const DARK: Record<string, string> = {
  foreground: '#cccccc',
  'editor-foreground': '#d4d4d4',
  'editor-background': '#1e1e1e',
  descriptionForeground: '#9d9d9d',
  focusBorder: '#007fd4',
  'widget-border': '#303031',
  'editorWidget-background': '#252526',
  'editorWidget-border': '#454545',
  'editor-inactiveSelectionBackground': '#3a3d41',
  'list-activeSelectionBackground': '#094771',
  'list-activeSelectionForeground': '#ffffff',
  'list-hoverBackground': '#2a2d2e',
  'list-warningForeground': '#cca700',
  'input-background': '#3c3c3c',
  'input-foreground': '#cccccc',
  'input-border': '#3c3c3c',
  'badge-background': '#4d4d4d',
  'badge-foreground': '#ffffff',
  'button-background': '#0e639c',
  'button-foreground': '#ffffff',
  'button-hoverBackground': '#1177bb',
  'button-border': 'transparent',
  'button-secondaryBackground': '#3a3d41',
  'button-secondaryForeground': '#ffffff',
  'button-secondaryHoverBackground': '#45494e',
  'textLink-foreground': '#3794ff',
  'textLink-activeForeground': '#4daafc',
  'panel-background': '#1e1e1e',
  'panel-border': '#2b2b2b',
  'sideBar-background': '#181818',
  'sideBarSectionHeader-background': '#181818',
  'testing-iconPassed': '#73c991',
  'editorInfo-foreground': '#3794ff',
  'editorWarning-foreground': '#cca700',
  'editorError-foreground': '#f14c4c',
  'progressBar-background': '#0e70c0',
};

const LIGHT: Record<string, string> = {
  foreground: '#3b3b3b',
  'editor-foreground': '#000000',
  'editor-background': '#ffffff',
  descriptionForeground: '#717171',
  focusBorder: '#005fb8',
  'widget-border': '#d4d4d4',
  'editorWidget-background': '#f8f8f8',
  'editorWidget-border': '#c8c8c8',
  'editor-inactiveSelectionBackground': '#e5ebf1',
  'list-activeSelectionBackground': '#005fb8',
  'list-activeSelectionForeground': '#ffffff',
  'list-hoverBackground': '#f0f0f0',
  'list-warningForeground': '#bf8803',
  'input-background': '#ffffff',
  'input-foreground': '#3b3b3b',
  'input-border': '#cecece',
  'badge-background': '#cccccc',
  'badge-foreground': '#3b3b3b',
  'button-background': '#005fb8',
  'button-foreground': '#ffffff',
  'button-hoverBackground': '#0258a8',
  'button-border': 'transparent',
  'button-secondaryBackground': '#e5e5e5',
  'button-secondaryForeground': '#3b3b3b',
  'button-secondaryHoverBackground': '#cccccc',
  'textLink-foreground': '#005fb8',
  'textLink-activeForeground': '#005fb8',
  'panel-background': '#ffffff',
  'panel-border': '#e5e5e5',
  'sideBar-background': '#f8f8f8',
  'sideBarSectionHeader-background': '#f8f8f8',
  'testing-iconPassed': '#388a34',
  'editorInfo-foreground': '#1a85ff',
  'editorWarning-foreground': '#bf8803',
  'editorError-foreground': '#e51400',
  'progressBar-background': '#0e70c0',
};

const HC: Record<string, string> = {
  foreground: '#ffffff',
  'editor-foreground': '#ffffff',
  'editor-background': '#000000',
  descriptionForeground: '#ffffff',
  focusBorder: '#f38518',
  'widget-border': '#6fc3df',
  'editorWidget-background': '#0c141f',
  'editorWidget-border': '#6fc3df',
  'editor-inactiveSelectionBackground': '#ffffff26',
  'list-activeSelectionBackground': '#000000',
  'list-activeSelectionForeground': '#ffffff',
  'list-hoverBackground': '#ffffff1a',
  'list-warningForeground': '#ffd700',
  'input-background': '#000000',
  'input-foreground': '#ffffff',
  'input-border': '#6fc3df',
  'badge-background': '#000000',
  'badge-foreground': '#ffffff',
  'button-background': '#000000',
  'button-foreground': '#ffffff',
  'button-hoverBackground': '#000000',
  'button-border': '#6fc3df',
  'button-secondaryBackground': '#000000',
  'button-secondaryForeground': '#ffffff',
  'button-secondaryHoverBackground': '#000000',
  'textLink-foreground': '#3794ff',
  'textLink-activeForeground': '#4daafc',
  'panel-background': '#000000',
  'panel-border': '#6fc3df',
  'sideBar-background': '#000000',
  'sideBarSectionHeader-background': '#000000',
  'testing-iconPassed': '#89d185',
  'editorInfo-foreground': '#3794ff',
  'editorWarning-foreground': '#ffd700',
  'editorError-foreground': '#f48771',
  'progressBar-background': '#0e70c0',
};

const SETS: Record<ThemeName, Record<string, string>> = {
  dark: DARK,
  light: LIGHT,
  hc: HC,
};

/** Serialize a theme to a `:root { --vscode-*: …; }` block plus a body base. */
export function themeCss(theme: ThemeName): string {
  const merged = { ...COMMON, ...SETS[theme] };
  const vars = Object.entries(merged)
    .map(([k, v]) => `  --vscode-${k}: ${v};`)
    .join('\n');
  return `:root {\n${vars}\n}
html, body {
  background: var(--vscode-editor-background);
  color: var(--vscode-foreground);
  font-family: var(--vscode-font-family);
  font-size: var(--vscode-font-size);
  margin: 0;
}`;
}

/**
 * Minimal stand-in for the host bridge so page scripts that call
 * acquireVsCodeApi() (postMessage / get/setState) do not throw on load.
 */
const VSCODE_API_STUB = `
window.acquireVsCodeApi = function () {
  var state = {};
  return {
    postMessage: function () {},
    getState: function () { return state; },
    setState: function (v) { state = v; return v; },
  };
};
`;

export const THEMES: ThemeName[] = ['dark', 'light', 'hc'];

/**
 * Turn a builder's full HTML document into a standalone page Chromium can load:
 * strip the CSP meta (so the injected harness style/script run without a nonce),
 * then inject the theme variables and the API stub as the first head children
 * so they are in place before the page's own inline scripts execute.
 */
export function wrapForHarness(html: string, theme: ThemeName): string {
  const withoutCsp = html.replace(
    /<meta[^>]*http-equiv=["']Content-Security-Policy["'][^>]*>/i,
    '',
  );
  const inject =
    `<style data-harness-theme="${theme}">${themeCss(theme)}</style>` +
    `<script>${VSCODE_API_STUB}</script>`;
  return withoutCsp.replace(/<head[^>]*>/i, (head) => head + inject);
}
