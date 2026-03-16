"use strict";
/**
 * Opens a full-screen "About Saropa Lints" webview panel in the editor area.
 * Shows extension version and company/product info from about-saropa.md.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.showAboutPanel = showAboutPanel;
const vscode = __importStar(require("vscode"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
/** Re-uses an existing panel if already open; otherwise creates a new one. */
let currentPanel;
function showAboutPanel(extensionUri, version) {
    // If already open, bring it to front instead of creating a duplicate.
    if (currentPanel) {
        currentPanel.reveal(vscode.ViewColumn.One);
        return;
    }
    currentPanel = vscode.window.createWebviewPanel('saropaLints.about', 'About Saropa Lints', vscode.ViewColumn.One, { enableScripts: false });
    currentPanel.webview.html = buildHtml(extensionUri, version);
    // Clear reference when the user closes the tab.
    currentPanel.onDidDispose(() => { currentPanel = undefined; });
}
function buildHtml(extensionUri, version) {
    const bodyHtml = markdownToHtml(readMarkdown(extensionUri));
    const nonce = getNonce();
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy"
    content="default-src 'none'; style-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>About Saropa Lints</title>
  <style nonce="${nonce}">
    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      max-width: 720px;
      margin: 0 auto;
      padding: 20px 24px;
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
    h1 { font-size: 1.5em; margin: 0 0 4px; }
    h2 { font-size: 1.25em; margin: 20px 0 8px; }
    h3 { font-size: 1.1em; margin: 16px 0 6px; }
    ul { margin: 6px 0; padding-left: 22px; }
    .version {
      font-size: 0.9em;
      color: var(--vscode-descriptionForeground);
      margin-bottom: 16px;
    }
  </style>
</head>
<body>
  <div class="version">Saropa Lints v${escapeHtml(version)}</div>
  ${bodyHtml}
</body>
</html>`;
}
function readMarkdown(extensionUri) {
    try {
        const mdPath = path.join(extensionUri.fsPath, 'media', 'about-saropa.md');
        return fs.readFileSync(mdPath, 'utf-8');
    }
    catch {
        return '## About Saropa\n\nContent unavailable.';
    }
}
/** Escape HTML special characters to prevent injection. */
function escapeHtml(text) {
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
/** Convert inline markdown (bold, italic, links, inline code) to HTML. */
function inlineToHtml(text) {
    return escapeHtml(text)
        .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
        .replace(/(?<!\w)_([^_]+)_(?!\w)/g, '<em>$1</em>')
        .replace(/`([^`]+)`/g, '<code>$1</code>')
        .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
}
/**
 * Convert the controlled markdown from about-saropa.md to HTML.
 * Handles: headers, bold, italic, links, tables, unordered lists, horizontal rules.
 * Not a general-purpose converter — scoped to the constructs in the file.
 */
function markdownToHtml(md) {
    const lines = md.split('\n');
    const out = [];
    let inTable = false;
    let inList = false;
    const closeBlocks = () => {
        if (inList) {
            out.push('</ul>');
            inList = false;
        }
        if (inTable) {
            out.push('</tbody></table>');
            inTable = false;
        }
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
            if (inList) {
                out.push('</ul>');
                inList = false;
            }
            // Skip separator rows (|---|---|)
            if (/^\|[\s\-:|]+\|$/.test(trimmed))
                continue;
            if (!inTable) {
                out.push('<table><tbody>');
                inTable = true;
            }
            const cells = trimmed.split('|').slice(1, -1).map((c) => inlineToHtml(c.trim()));
            out.push(`<tr>${cells.map((c) => `<td>${c}</td>`).join('')}</tr>`);
            continue;
        }
        if (inTable) {
            out.push('</tbody></table>');
            inTable = false;
        }
        // List items (top-level and nested)
        if (/^\s*- /.test(line)) {
            if (!inList) {
                out.push('<ul>');
                inList = true;
            }
            out.push(`<li>${inlineToHtml(trimmed.replace(/^- /, ''))}</li>`);
            continue;
        }
        if (inList) {
            out.push('</ul>');
            inList = false;
        }
        // Blank line
        if (trimmed === '')
            continue;
        // Paragraph
        out.push(`<p>${inlineToHtml(trimmed)}</p>`);
    }
    closeBlocks();
    return out.join('\n');
}
function getNonce() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return Array.from({ length: 32 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
}
//# sourceMappingURL=aboutView.js.map