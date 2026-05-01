/**
 * Opens a full-screen "About Saropa Lints" webview panel in the editor area.
 * Shows extension version and company/product info from about-saropa.md.
 */

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

/** Re-uses an existing panel if already open; otherwise creates a new one. */
let currentPanel: vscode.WebviewPanel | undefined;

export function showAboutPanel(extensionUri: vscode.Uri, version: string): void {
  // If already open, bring it to front instead of creating a duplicate.
  if (currentPanel) {
    currentPanel.reveal(vscode.ViewColumn.One);
    return;
  }

  currentPanel = vscode.window.createWebviewPanel(
    'saropaLints.about',
    'About Saropa Lints',
    vscode.ViewColumn.One,
    { enableScripts: false },
  );

  currentPanel.webview.html = buildHtml(extensionUri, version);

  // Clear reference when the user closes the tab.
  currentPanel.onDidDispose(() => { currentPanel = undefined; });
}

function buildHtml(extensionUri: vscode.Uri, version: string): string {
  const bodyHtml = markdownToHtml(readMarkdown(extensionUri));
  const nonce = getNonce();
  // About panel uses a stripped hero (title + version stamp, no status pills, no gauge,
  // no full-width toggle since this panel runs with enableScripts:false). The Saropa
  // prefix is satisfied by the explicit "Saropa Lints" h1 — guideline §8.1.
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy"
    content="default-src 'none'; style-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Saropa Lints — About</title>
  <style nonce="${nonce}">
    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      max-width: 760px;
      margin: 0 auto;
      padding: 20px 24px 28px;
      line-height: 1.6;
    }
    a { color: var(--vscode-textLink-foreground); text-decoration: none; }
    a:hover { color: var(--vscode-textLink-activeForeground); text-decoration: underline; }
    table { border-collapse: collapse; width: 100%; margin: 12px 0; }
    th, td {
      padding: 6px 10px; text-align: left;
      border: 1px solid var(--vscode-panel-border);
    }
    th { background: var(--vscode-editor-inactiveSelectionBackground); }
    hr { border: none; border-top: 1px solid var(--vscode-panel-border); margin: 20px 0; }
    /* Stripped hero — title row with a muted version stamp anchored inline. */
    .dash-hero {
      display: flex; align-items: baseline;
      gap: 12px;
      padding: 16px 20px;
      margin-bottom: 16px;
      border: 1px solid var(--vscode-widget-border);
      border-radius: 12px;
      background: var(--vscode-editorWidget-background);
    }
    .dash-hero h1 {
      margin: 0;
      font-size: 1.55em;
      font-weight: 600;
      letter-spacing: 0.2px;
    }
    .dash-hero .stamp {
      font-size: 0.55em;
      font-weight: 400;
      opacity: 0.55;
      letter-spacing: 0.4px;
    }
    h1 { font-size: 1.5em; margin: 0 0 4px; }
    h2 { font-size: 1.25em; margin: 20px 0 8px; }
    h3 { font-size: 1.1em; margin: 16px 0 6px; }
    ul { margin: 6px 0; padding-left: 22px; }
  </style>
</head>
<body>
  <header class="dash-hero">
    <h1>Saropa Lints<span class="stamp">v${escapeHtml(version)}</span></h1>
  </header>
  ${bodyHtml}
</body>
</html>`;
}

function readMarkdown(extensionUri: vscode.Uri): string {
  try {
    const mdPath = path.join(extensionUri.fsPath, 'media', 'about-saropa.md');
    return fs.readFileSync(mdPath, 'utf-8');
  } catch {
    return '## About Saropa\n\nContent unavailable.';
  }
}

/** Escape HTML special characters to prevent injection. */
function escapeHtml(text: string): string {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

/**
 * Allow-list of URL schemes / forms permitted in markdown links. Anything else
 * (notably `javascript:`, `data:`, `vbscript:`, `file:`) is downgraded to plain
 * text so a malicious link in `about-saropa.md` cannot execute script in the
 * webview context. `escapeHtml` does NOT defend against this — `javascript:alert(1)`
 * has no characters that need escaping.
 */
const SAFE_LINK_SCHEME = /^(https?:\/\/|mailto:|#|\.{0,2}\/)/i;

/** Convert inline markdown (bold, italic, links, inline code) to HTML. */
function inlineToHtml(text: string): string {
  return escapeHtml(text)
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/(?<!\w)_([^_]+)_(?!\w)/g, '<em>$1</em>')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, lab: string, href: string) => {
      // Reject unsafe schemes by emitting the label as plain text rather than an anchor;
      // preserves human-readable content and removes the click target entirely.
      if (!SAFE_LINK_SCHEME.test(href)) { return lab; }
      const ext = /^https?:\/\//i.test(href);
      const extra = ext ? ' target="_blank" rel="noopener noreferrer"' : '';
      return `<a href="${href}"${extra}>${lab}</a>`;
    });
}

/**
 * Convert the controlled markdown from about-saropa.md to HTML.
 * Handles: headers, bold, italic, links, tables, unordered lists (with
 * indent-based nesting), horizontal rules. Not a general-purpose converter —
 * scoped to the constructs in the file. Exported for unit testing of the
 * nested-list rendering path.
 */
export function markdownToHtml(md: string): string {
  const lines = md.split('\n');
  const out: string[] = [];
  let inTable = false;
  // Stack of indent widths (in spaces) for currently-open <ul> levels. Each
  // entry represents one nested <ul> whose <li> at the top of the stack is
  // still open and not yet terminated with </li>. We close the trailing <li>
  // lazily — either when the next sibling/dedent appears, or in closeLists().
  const listIndents: number[] = [];

  const closeLists = () => {
    while (listIndents.length > 0) {
      out.push('</li></ul>');
      listIndents.pop();
    }
  };

  const closeBlocks = () => {
    closeLists();
    if (inTable) { out.push('</tbody></table>'); inTable = false; }
  };

  for (const line of lines) {
    const trimmed = line.trim();

    // Horizontal rule
    if (/^---+$/.test(trimmed)) {
      closeBlocks();
      out.push('<hr>');
      continue;
    }

    // Headers (h1/h2/h3)
    const hMatch = trimmed.match(/^(#{1,3}) (.+)/);
    if (hMatch) {
      closeBlocks();
      const level = hMatch[1].length;
      out.push(`<h${level}>${inlineToHtml(hMatch[2])}</h${level}>`);
      continue;
    }

    // Table rows: | col | col |
    if (trimmed.startsWith('|')) {
      closeLists();
      // Skip separator rows (|---|---|)
      if (/^\|[\s\-:|]+\|$/.test(trimmed)) continue;
      if (!inTable) { out.push('<table><tbody>'); inTable = true; }
      const cells = trimmed.split('|').slice(1, -1).map((c) => inlineToHtml(c.trim()));
      out.push(`<tr>${cells.map((c) => `<td>${c}</td>`).join('')}</tr>`);
      continue;
    }
    if (inTable) { out.push('</tbody></table>'); inTable = false; }

    // List items — support nesting via leading-space indent. The about-saropa.md
    // file uses 2-space indents for sub-bullets (e.g. "Smart Features" children,
    // "VS Code Extensions" descriptions). The previous flat handling rendered
    // every "- " line as a sibling, which made the parent/child relationship
    // disappear in the webview.
    const listMatch = line.match(/^(\s*)- (.+)$/);
    if (listMatch) {
      const indent = listMatch[1].length;
      const content = inlineToHtml(listMatch[2]);

      if (listIndents.length === 0) {
        // First bullet: open the outermost <ul>.
        out.push('<ul>');
        listIndents.push(indent);
      } else if (indent > listIndents[listIndents.length - 1]) {
        // Deeper indent: nest a new <ul> *inside* the still-open parent <li>.
        // The parent <li> intentionally has no </li> emitted yet for this reason.
        out.push('<ul>');
        listIndents.push(indent);
      } else {
        // Same or shallower indent: close the previous sibling's <li>, then
        // unwind back to the matching level by closing each deeper <ul></li>.
        out.push('</li>');
        while (listIndents.length > 1 && indent < listIndents[listIndents.length - 1]) {
          out.push('</ul></li>');
          listIndents.pop();
        }
      }

      // Open the new <li> without closing it — a following nested bullet may
      // need to embed a <ul> here. closeLists()/sibling handling closes it.
      out.push(`<li>${content}`);
      continue;
    }
    closeLists();

    // Blank line
    if (trimmed === '') continue;

    // Paragraph
    out.push(`<p>${inlineToHtml(trimmed)}</p>`);
  }

  closeBlocks();
  return out.join('\n');
}

function getNonce(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return Array.from({ length: 32 }, () =>
    chars[Math.floor(Math.random() * chars.length)],
  ).join('');
}
