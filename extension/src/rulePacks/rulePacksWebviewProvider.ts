/**
 * VS Code **Rule Packs** sidebar (`saropaLints.rulePacks`).
 *
 * Renders a table: pack label, pubspec detection, enable toggle, rule count,
 * and a Quick Pick of rule codes. For Flutter apps, shows embedder platform
 * rows (android/, ios/, …) from {@link readPubspec}.
 *
 * Writes `plugins.saropa_lints.rule_packs.enabled` (see `rulePackYaml.ts`).
 * Refreshes when the user saves `analysis_options.yaml` or when global refresh runs.
 *
 * **Concurrency:** toggle handler is async; YAML is written synchronously then
 * analysis may run — no recursive refresh loop (refresh after write is intentional).
 */

import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { getProjectRoot } from '../projectRoot';
import { readPubspec, FLUTTER_EMBEDDER_PLATFORMS } from '../pubspecReader';
import { RULE_PACK_DEFINITIONS, isPackDetected } from './rulePackDefinitions';
import { readRulePacksEnabled, writeRulePacksEnabled } from './rulePackYaml';

const VIEW_ID = 'saropaLints.rulePacks';

export class RulePacksWebviewProvider implements vscode.WebviewViewProvider {
  private _view?: vscode.WebviewView;

  constructor(private readonly _extensionUri: vscode.Uri) {}

  resolveWebviewView(
    webviewView: vscode.WebviewView,
    _context: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken,
  ): void {
    this._view = webviewView;
    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [this._extensionUri],
    };

    webviewView.webview.onDidReceiveMessage((msg: { type: string; packId?: string; enabled?: boolean }) => {
      if (msg.type === 'toggle' && msg.packId !== undefined && msg.enabled !== undefined) {
        void this._handleToggle(msg.packId, msg.enabled);
      }
      if (msg.type === 'showRules' && msg.packId !== undefined) {
        void this._showRulesList(msg.packId);
      }
      if (msg.type === 'refresh') {
        this.refresh();
      }
    });

    this.refresh();
  }

  refresh(): void {
    if (!this._view) return;
    this._view.webview.html = this._buildHtml();
  }

  private _buildHtml(): string {
    const root = getProjectRoot();
    if (!root) {
      return this._wrapHtml('<p>Open a workspace folder.</p>', false);
    }

    const pubspecPath = path.join(root, 'pubspec.yaml');
    let pubspecContent = '';
    try {
      pubspecContent = fs.readFileSync(pubspecPath, 'utf-8');
    } catch {
      return this._wrapHtml('<p>No pubspec.yaml in workspace.</p>', false);
    }

    const info = readPubspec(root);
    const enabledIds = new Set(readRulePacksEnabled(root));

    const rows = RULE_PACK_DEFINITIONS.map((def) => {
      const detected = isPackDetected(def, pubspecContent);
      const enabled = enabledIds.has(def.id);
      const count = def.ruleCodes.length;
      const detLabel = detected ? 'Yes' : 'No';
      const detClass = detected ? 'ok' : 'muted';
      const gateLine = def.dependencyGate
        ? `<div class="gate">${escapeHtml(def.dependencyGate.package)} ${escapeHtml(def.dependencyGate.constraint)} in pubspec.lock</div>`
        : '';
      return `<tr data-pack="${escapeHtml(def.id)}">
  <td class="pack-name">${escapeHtml(def.label)}${gateLine}</td>
  <td class="${detClass}">${detLabel}</td>
  <td><label class="switch"><input type="checkbox" data-pack="${escapeHtml(def.id)}" ${enabled ? 'checked' : ''} /><span class="slider"></span></label></td>
  <td class="num">${count}</td>
  <td><a href="#" class="rules-link" data-pack="${escapeHtml(def.id)}">Rules</a></td>
</tr>`;
    }).join('\n');

    const platRows = FLUTTER_EMBEDDER_PLATFORMS.map((p) => {
      const present = info.platforms.includes(p);
      return `<tr><td>${escapeHtml(p)}</td><td class="${present ? 'ok' : 'muted'}">${present ? 'Yes' : 'No'}</td></tr>`;
    }).join('\n');

    const platSection = info.isFlutter
      ? `<h2>Target platforms</h2>
<table class="plat"><thead><tr><th>Platform</th><th>Present</th></tr></thead><tbody>${platRows}</tbody></table>
<p class="hint">Detected from embedder folders (android/, ios/, …).</p>`
      : `<p class="hint dart-only">Pure Dart package — no Flutter embedder targets.</p>`;

    const body = `
<h1>Rule packs</h1>
<p class="hint">Enable extra rules per stack. Merged with your tier; see <a href="https://pub.dev/packages/saropa_lints">docs</a>.</p>
<table class="packs">
<thead><tr><th>Pack</th><th>In pubspec</th><th>Enabled</th><th>Rules</th><th></th></tr></thead>
<tbody>${rows}</tbody>
</table>
${platSection}
`;

    return this._wrapHtml(body, true);
  }

  private _wrapHtml(body: string, scripts: boolean): string {
    const csp = [
      "default-src 'none'",
      "style-src 'unsafe-inline'",
      scripts ? "script-src 'unsafe-inline'" : '',
    ]
      .filter(Boolean)
      .join('; ');
    const script = scripts
      ? `<script>
(function() {
  const vscode = acquireVsCodeApi();
  document.querySelectorAll('input[type=checkbox][data-pack]').forEach(function(el) {
    el.addEventListener('change', function() {
      vscode.postMessage({ type: 'toggle', packId: el.getAttribute('data-pack'), enabled: el.checked });
    });
  });
  document.querySelectorAll('a.rules-link').forEach(function(a) {
    a.addEventListener('click', function(e) {
      e.preventDefault();
      const id = a.getAttribute('data-pack');
      vscode.postMessage({ type: 'showRules', packId: id });
    });
  });
})();
</script>`
      : '';
    return `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta http-equiv="Content-Security-Policy" content="${csp}">
<style>
body { font-family: var(--vscode-font-family); font-size: 12px; color: var(--vscode-foreground); padding: 8px; }
h1 { font-size: 13px; margin: 0 0 8px 0; }
h2 { font-size: 12px; margin: 16px 0 8px 0; }
table { width: 100%; border-collapse: collapse; }
th, td { text-align: left; padding: 4px 6px; border-bottom: 1px solid var(--vscode-widget-border); }
th { font-weight: 600; opacity: 0.9; }
.ok { color: var(--vscode-testing-iconPassed); }
.muted { opacity: 0.55; }
.num { text-align: right; }
.hint { font-size: 11px; opacity: 0.75; margin-top: 8px; }
.dart-only { margin-top: 12px; }
a { color: var(--vscode-textLink-foreground); cursor: pointer; }
.switch { position: relative; display: inline-block; width: 32px; height: 18px; vertical-align: middle; }
.switch input { opacity: 0; width: 0; height: 0; }
.slider { position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background: var(--vscode-input-background); border-radius: 10px; border: 1px solid var(--vscode-widget-border); }
.slider:before { position: absolute; content: ""; height: 12px; width: 12px; left: 2px; bottom: 2px; background: var(--vscode-foreground); border-radius: 50%; opacity: 0.5; transition: .15s; }
input:checked + .slider:before { transform: translateX(14px); opacity: 1; }
.plat th { width: 40%; }
.gate { font-size: 10px; opacity: 0.7; margin-top: 2px; font-weight: normal; }
</style></head><body>${body}${script}</body></html>`;
  }

  private async _handleToggle(packId: string, enabled: boolean): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const cur = readRulePacksEnabled(root);
    const next = new Set(cur);
    if (enabled) {
      next.add(packId);
    } else {
      next.delete(packId);
    }
    const ok = writeRulePacksEnabled(
      root,
      [...next].sort((a, b) => a.localeCompare(b)),
    );
    if (!ok) {
      void vscode.window.showErrorMessage('Saropa Lints: could not write analysis_options.yaml (rule_packs).');
      return;
    }
    const run = vscode.workspace.getConfiguration('saropaLints').get<boolean>('runAnalysisAfterConfigChange');
    if (run !== false) {
      await vscode.commands.executeCommand('saropaLints.runAnalysis');
    }
    this.refresh();
  }

  private async _showRulesList(packId: string): Promise<void> {
    const def = RULE_PACK_DEFINITIONS.find((d) => d.id === packId);
    if (!def) return;
    const items = def.ruleCodes.map((code) => ({ label: code, description: '' }));
    await vscode.window.showQuickPick(items, {
      title: `${def.label} — ${def.ruleCodes.length} rules`,
      placeHolder: 'Rule codes in this pack',
    });
  }
}

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

export const RULE_PACKS_VIEW_ID = VIEW_ID;
