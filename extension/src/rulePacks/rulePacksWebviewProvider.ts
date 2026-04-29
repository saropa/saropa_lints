// Implements the Rule Packs view: load pubspec, toggles, and `rule_packs` config.
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
const TIERS = ['essential', 'recommended', 'professional', 'comprehensive', 'pedantic'] as const;

type TierName = (typeof TIERS)[number];

interface PackDashboardStats {
  totalPacks: number;
  enabledPacks: number;
  detectedPacks: number;
  enabledRules: number;
  detectedRules: number;
}

interface PackChartRow {
  id: string;
  label: string;
  rules: number;
  enabled: boolean;
  detected: boolean;
}

export function isSdkPackId(id: string): boolean {
  return id.startsWith('dart_sdk_') || id.startsWith('flutter_sdk_');
}

export function sdkPackRiskKind(def: { id: string; ruleCodes: readonly string[] }): 'breaking' | 'deprecation' | 'none' {
  if (!isSdkPackId(def.id)) return 'none';
  return def.ruleCodes.some((code) => code.startsWith('avoid_removed_')) ? 'breaking' : 'deprecation';
}

export function compareSdkPackRowsByRisk(
  a: { label: string; risk: 'breaking' | 'deprecation' | 'none' },
  b: { label: string; risk: 'breaking' | 'deprecation' | 'none' },
): number {
  const rank = (risk: 'breaking' | 'deprecation' | 'none'): number => {
    if (risk === 'breaking') return 0;
    if (risk === 'deprecation') return 1;
    return 2;
  };
  const byRisk = rank(a.risk) - rank(b.risk);
  if (byRisk !== 0) return byRisk;
  return a.label.localeCompare(b.label);
}

type SdkRiskSelection = 'all' | 'breaking' | 'deprecation';

export function sdkPackMatchesSelection(
  def: { id: string; ruleCodes: readonly string[] },
  selection: SdkRiskSelection,
): boolean {
  if (!isSdkPackId(def.id)) return false;
  if (selection === 'all') return true;
  return sdkPackRiskKind(def) === selection;
}

function isBreakingSdkPack(def: { id: string; ruleCodes: readonly string[] }): boolean {
  return sdkPackRiskKind(def) === 'breaking';
}

export function computePackDashboardStats(rows: readonly PackChartRow[]): PackDashboardStats {
  let enabledPacks = 0;
  let detectedPacks = 0;
  let enabledRules = 0;
  let detectedRules = 0;
  for (const row of rows) {
    if (row.enabled) {
      enabledPacks++;
      enabledRules += row.rules;
    }
    if (row.detected) {
      detectedPacks++;
      detectedRules += row.rules;
    }
  }
  return {
    totalPacks: rows.length,
    enabledPacks,
    detectedPacks,
    enabledRules,
    detectedRules,
  };
}

export function buildTierChips(currentTier: string): string {
  return TIERS.map((tier) => {
    const active = tier === currentTier;
    return `<span class="tier-chip ${active ? 'active' : ''}">${escapeHtml(tier)}${active ? ' (current)' : ''}</span>`;
  }).join('');
}

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

    webviewView.webview.onDidReceiveMessage((msg: { type: string; packId?: string; enabled?: boolean; id?: string }) => {
      if (msg.type === 'toggle' && msg.packId !== undefined && msg.enabled !== undefined) {
        void this._handleToggle(msg.packId, msg.enabled);
      }
      if (msg.type === 'showRules' && msg.packId !== undefined) {
        void this._showRulesList(msg.packId);
      }
      if (msg.type === 'command' && typeof msg.id === 'string') {
        void this._runDashboardCommand(msg.id);
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
    const currentTier = vscode.workspace.getConfiguration('saropaLints').get<string>('tier', 'recommended') ?? 'recommended';

    const packRows = RULE_PACK_DEFINITIONS.map((def) => {
      const detected = isPackDetected(def, pubspecContent);
      const enabled = enabledIds.has(def.id);
      const count = def.ruleCodes.length;
      return {
        id: def.id,
        label: def.label,
        detected,
        enabled,
        rules: count,
      };
    });
    const detectedSdkPacks = RULE_PACK_DEFINITIONS.filter(
      (def) => isSdkPackId(def.id) && isPackDetected(def, pubspecContent),
    );
    const detectedBreakingSdkPacks = detectedSdkPacks.filter((def) => isBreakingSdkPack(def));
    const detectedSdkLabels = detectedSdkPacks.map((def) => def.label).sort((a, b) => a.localeCompare(b));
    const detectedBreakingSdkLabels = detectedBreakingSdkPacks
      .map((def) => def.label)
      .sort((a, b) => a.localeCompare(b));
    const stats = computePackDashboardStats(packRows);
    const maxRules = Math.max(1, ...packRows.map((row) => row.rules));

    const renderRows = (rowsToRender: typeof packRows) => rowsToRender.map((row) => {
      const def = RULE_PACK_DEFINITIONS.find((d) => d.id === row.id)!;
      const detLabel = row.detected ? 'Yes' : 'No';
      const detClass = row.detected ? 'ok' : 'muted';
      const riskKind = sdkPackRiskKind(def);
      const riskBadge = riskKind === 'none'
        ? ''
        : `<span class="risk-badge ${riskKind}">${riskKind === 'breaking' ? 'breaking' : 'deprecation'}</span>`;
      const sdkBadge = isSdkPackId(def.id) ? '<span class="risk-badge sdk">sdk</span>' : '';
      const gateLine = def.dependencyGate
        ? `<div class="gate">${escapeHtml(def.dependencyGate.package)} ${escapeHtml(def.dependencyGate.constraint)} in pubspec.lock</div>`
        : def.sdkGate
          ? `<div class="gate">${escapeHtml(def.sdkGate.sdkKey)} ${escapeHtml(def.sdkGate.constraint)} (pubspec environment) ${sdkBadge}${riskBadge}</div>`
        : '';
      return `<tr data-pack="${escapeHtml(row.id)}">
  <td class="pack-name">${escapeHtml(def.label)}${gateLine}</td>
  <td class="${detClass}">${detLabel}</td>
  <td><label class="switch"><input type="checkbox" data-pack="${escapeHtml(row.id)}" ${row.enabled ? 'checked' : ''} /><span class="slider"></span></label></td>
  <td class="num">${row.rules}</td>
  <td><a href="#" class="rules-link" data-pack="${escapeHtml(row.id)}">Rules</a></td>
</tr>`;
    }).join('\n');
    const sdkRowsSorted = [...packRows]
      .filter((row) => isSdkPackId(row.id))
      .sort((a, b) => {
        const defA = RULE_PACK_DEFINITIONS.find((d) => d.id === a.id);
        const defB = RULE_PACK_DEFINITIONS.find((d) => d.id === b.id);
        const riskA = defA ? sdkPackRiskKind(defA) : 'none';
        const riskB = defB ? sdkPackRiskKind(defB) : 'none';
        return compareSdkPackRowsByRisk(
          { label: a.label, risk: riskA },
          { label: b.label, risk: riskB },
        );
      });
    const sdkRows = renderRows(sdkRowsSorted);
    const packageRows = renderRows(packRows.filter((row) => !isSdkPackId(row.id)));

    const chartRows = [...packRows]
      .sort((a, b) => b.rules - a.rules || a.label.localeCompare(b.label))
      .slice(0, 8)
      .map((row) => {
        const width = Math.round((row.rules / maxRules) * 100);
        return `<div class="bar-row">
  <div class="bar-head"><span>${escapeHtml(row.label)}</span><span>${row.rules}</span></div>
  <div class="bar-track"><div class="bar-fill ${row.enabled ? 'enabled' : ''} ${row.detected ? 'detected' : ''}" style="width:${width}%"></div></div>
</div>`;
      })
      .join('\n');

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
<h1>Config Dashboard</h1>
<p class="hint">Pack-owned rules are off unless that pack is enabled. Tiers control broad baselines; packs control package/SDK migration domains.</p>

<div class="actions">
  <button class="action-btn" data-command="setTier">Set tier</button>
  <button class="action-btn" data-command="openConfig">Open config YAML</button>
  <button class="action-btn" data-command="runAnalysis">Run analysis</button>
  <button class="action-btn" data-command="enableDetectedSdkPacks">Enable applicable SDK packs</button>
  <button class="action-btn" data-command="enableDetectedBreakingSdkPacks">Enable applicable breaking SDK packs</button>
  <button class="action-btn" data-command="enableDetectedDeprecationSdkPacks">Enable applicable deprecation SDK packs</button>
  <button class="action-btn" data-command="openVibrancy">Open Package Vibrancy</button>
</div>
<p class="hint">Rollout preview (all SDK): ${escapeHtml(detectedSdkLabels.join(', ') || 'none detected')}</p>
<p class="hint">Rollout preview (breaking SDK): ${escapeHtml(detectedBreakingSdkLabels.join(', ') || 'none detected')}</p>
<p class="hint">Rollout preview (deprecation SDK): ${escapeHtml(
  detectedSdkPacks
    .filter((def) => sdkPackRiskKind(def) === 'deprecation')
    .map((def) => def.label)
    .sort((a, b) => a.localeCompare(b))
    .join(', ') || 'none detected',
)}</p>

<div class="kpis">
  <div class="kpi-card"><div class="kpi-label">Tier</div><div class="kpi-value">${escapeHtml(currentTier)}</div></div>
  <div class="kpi-card"><div class="kpi-label">Enabled packs</div><div class="kpi-value">${stats.enabledPacks}/${stats.totalPacks}</div></div>
  <div class="kpi-card"><div class="kpi-label">Detected packs</div><div class="kpi-value">${stats.detectedPacks}/${stats.totalPacks}</div></div>
  <div class="kpi-card"><div class="kpi-label">Enabled rules (pack-owned)</div><div class="kpi-value">${stats.enabledRules}</div></div>
  <div class="kpi-card"><div class="kpi-label">Applicable SDK packs</div><div class="kpi-value">${detectedSdkPacks.length}</div></div>
  <div class="kpi-card"><div class="kpi-label">Applicable breaking SDK packs</div><div class="kpi-value">${detectedBreakingSdkPacks.length}</div></div>
</div>

<h2>Tiers</h2>
<div class="tier-row">${buildTierChips(currentTier)}</div>
<p class="hint">Tier sets broad defaults. Pack-owned migration rules require pack enablement.</p>

<h2>Pack coverage chart</h2>
<div class="chart">${chartRows}</div>

<h2>SDK migration packs</h2>
<table class="packs">
<thead><tr><th>Pack</th><th>In pubspec</th><th>Enabled</th><th>Rules</th><th></th></tr></thead>
<tbody>${sdkRows}</tbody>
</table>
<p class="hint">SDK pack labels include <span class="risk-badge sdk">sdk</span> and risk kind tags for quick rollout decisions.</p>

<h2>Package rule packs</h2>
<table class="packs">
<thead><tr><th>Pack</th><th>In pubspec</th><th>Enabled</th><th>Rules</th><th></th></tr></thead>
<tbody>${packageRows}</tbody>
</table>
<p class="hint">Detected rules in pubspec domains: ${stats.detectedRules}. Enabled rules via packs: ${stats.enabledRules}.</p>

<h2>Docs</h2>
<ul class="docs">
  <li><a href="https://pub.dev/packages/saropa_lints">Package docs</a></li>
  <li><a href="https://github.com/saropa/saropa_lints/blob/main/doc/guides/rule_packs.md">Rule pack guide</a></li>
  <li><a href="https://github.com/saropa/saropa_lints#rule-configuration-cheatsheet">Tier + pack cheatsheet</a></li>
</ul>
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
  document.querySelectorAll('button.action-btn[data-command]').forEach(function(el) {
    el.addEventListener('click', function() {
      vscode.postMessage({ type: 'command', id: el.getAttribute('data-command') });
    });
  });
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
.risk-badge { display: inline-block; margin-left: 6px; border: 1px solid var(--vscode-widget-border); border-radius: 999px; padding: 0 6px; font-size: 10px; line-height: 16px; opacity: 0.95; }
.risk-badge.sdk { border-color: var(--vscode-textLink-foreground); color: var(--vscode-textLink-foreground); }
.risk-badge.breaking { border-color: var(--vscode-testing-iconFailed); color: var(--vscode-testing-iconFailed); }
.risk-badge.deprecation { border-color: var(--vscode-testing-iconQueued); color: var(--vscode-testing-iconQueued); }
.actions { display: flex; gap: 6px; margin: 8px 0 12px 0; flex-wrap: wrap; }
.action-btn { border: 1px solid var(--vscode-button-border, var(--vscode-widget-border)); background: var(--vscode-button-secondaryBackground, var(--vscode-editorWidget-background)); color: var(--vscode-button-secondaryForeground, var(--vscode-foreground)); border-radius: 6px; padding: 4px 8px; cursor: pointer; }
.action-btn:hover { background: var(--vscode-button-secondaryHoverBackground, var(--vscode-list-hoverBackground)); }
.kpis { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; margin: 8px 0 14px 0; }
.kpi-card { border: 1px solid var(--vscode-widget-border); border-radius: 8px; padding: 8px; background: var(--vscode-editorWidget-background); }
.kpi-label { font-size: 10px; opacity: 0.75; margin-bottom: 4px; }
.kpi-value { font-size: 15px; font-weight: 700; }
.tier-row { display: flex; gap: 6px; flex-wrap: wrap; }
.tier-chip { border: 1px solid var(--vscode-widget-border); border-radius: 999px; padding: 2px 8px; font-size: 11px; opacity: 0.85; }
.tier-chip.active { border-color: var(--vscode-focusBorder); color: var(--vscode-textLink-foreground); font-weight: 600; }
.chart { border: 1px solid var(--vscode-widget-border); border-radius: 8px; padding: 8px; }
.bar-row { margin-bottom: 8px; }
.bar-row:last-child { margin-bottom: 0; }
.bar-head { display: flex; justify-content: space-between; font-size: 11px; margin-bottom: 2px; }
.bar-track { height: 8px; border-radius: 999px; background: var(--vscode-input-background); border: 1px solid var(--vscode-widget-border); overflow: hidden; }
.bar-fill { height: 100%; background: var(--vscode-progressBar-background); opacity: 0.5; }
.bar-fill.enabled { opacity: 0.95; }
.bar-fill.detected { box-shadow: inset 0 0 0 1px var(--vscode-testing-iconPassed); }
.docs { padding-left: 16px; margin: 6px 0 8px 0; }
.docs li { margin-bottom: 4px; }
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

  private async _runDashboardCommand(id: string): Promise<void> {
    if (id === 'setTier') {
      await vscode.commands.executeCommand('saropaLints.setTier');
      return;
    }
    if (id === 'openConfig') {
      await vscode.commands.executeCommand('saropaLints.openConfig');
      return;
    }
    if (id === 'runAnalysis') {
      await vscode.commands.executeCommand('saropaLints.runAnalysis');
      return;
    }
    if (id === 'openVibrancy') {
      await vscode.commands.executeCommand('saropaLints.openPackageVibrancy');
      return;
    }
    if (id === 'enableDetectedSdkPacks') {
      await this._enableDetectedSdkPacks({ selection: 'all' });
      return;
    }
    if (id === 'enableDetectedBreakingSdkPacks') {
      await this._enableDetectedSdkPacks({ selection: 'breaking' });
      return;
    }
    if (id === 'enableDetectedDeprecationSdkPacks') {
      await this._enableDetectedSdkPacks({ selection: 'deprecation' });
      return;
    }
  }

  private async _enableDetectedSdkPacks(options: { selection: SdkRiskSelection }): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const pubspecPath = path.join(root, 'pubspec.yaml');
    let pubspecContent = '';
    try {
      pubspecContent = fs.readFileSync(pubspecPath, 'utf-8');
    } catch {
      void vscode.window.showErrorMessage('Saropa Lints: could not read pubspec.yaml.');
      return;
    }

    const currentEnabled = new Set(readRulePacksEnabled(root));
    const detectedSdkDefs = RULE_PACK_DEFINITIONS.filter((def) => {
      if (!sdkPackMatchesSelection(def, options.selection)) return false;
      if (!isPackDetected(def, pubspecContent)) return false;
      return true;
    });
    const toEnable = detectedSdkDefs.filter((def) => !currentEnabled.has(def.id));
    if (toEnable.length === 0) {
      void vscode.window.showInformationMessage('Saropa Lints: no additional applicable SDK packs to enable.');
      return;
    }
    const confirmed = await this._confirmSdkBulkEnable(options.selection, toEnable.map((def) => def.label));
    if (!confirmed) return;

    let added = 0;
    for (const def of detectedSdkDefs) {
      if (!currentEnabled.has(def.id)) {
        currentEnabled.add(def.id);
        added += 1;
      }
    }
    const ok = writeRulePacksEnabled(root, [...currentEnabled].sort((a, b) => a.localeCompare(b)));
    if (!ok) {
      void vscode.window.showErrorMessage('Saropa Lints: could not write analysis_options.yaml (rule_packs).');
      return;
    }

    const run = vscode.workspace.getConfiguration('saropaLints').get<boolean>('runAnalysisAfterConfigChange');
    if (run !== false) {
      await vscode.commands.executeCommand('saropaLints.runAnalysis');
    }
    const modeLabel =
      options.selection === 'breaking'
        ? 'breaking SDK'
        : options.selection === 'deprecation'
          ? 'deprecation SDK'
          : 'SDK';
    void vscode.window.showInformationMessage(
      `Saropa Lints: enabled ${added} applicable ${modeLabel} pack(s).`,
    );
    this.refresh();
  }

  private async _confirmSdkBulkEnable(
    selection: SdkRiskSelection,
    packLabels: readonly string[],
  ): Promise<boolean> {
    const modeLabel =
      selection === 'breaking'
        ? 'breaking SDK'
        : selection === 'deprecation'
          ? 'deprecation SDK'
          : 'SDK';
    const preview = packLabels.slice(0, 5).join(', ');
    const suffix = packLabels.length > 5 ? `, +${packLabels.length - 5} more` : '';
    const choice = await vscode.window.showWarningMessage(
      `Enable ${packLabels.length} ${modeLabel} pack(s)?`,
      {
        modal: true,
        detail: `This updates rule_packs.enabled in analysis_options.yaml. ${preview}${suffix}`,
      },
      'Enable',
    );
    return choice === 'Enable';
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
