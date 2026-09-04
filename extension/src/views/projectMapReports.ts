/**
 * "Reports" tab for the Saropa Project Map dashboard: one card per
 * `bin/*_report.dart` CLI (+ `quality_gate` and `doctor`) that today have no UI
 * surface at all — a user can only discover them by reading `bin/*.dart` source
 * or the CONTRIBUTING docs. Each card runs its CLI via a "Run" button and
 * streams the process's raw stdout/stderr, line by line, into a `.dash-table`
 * so the panel updates live instead of freezing until the process exits.
 *
 * Scope note (documented rather than silently narrowed): every one of these
 * CLIs is a `print()`-based text tool with its own ad hoc output shape (see
 * `bin/severity_report.dart`, `bin/doctor.dart`, etc.) — none emit a
 * machine-readable table contract except `--format json` on two of them. Fully
 * parsing each tool's free-text output into bespoke typed columns is a much
 * larger effort than "give every CLI a UI surface" requires, and risks silently
 * breaking if a tool's wording changes. This module instead renders a generic,
 * honest two-column `.dash-table` (line number + raw text) fed by the SAME
 * streaming mechanism a bespoke parser would use — the live-update contract
 * (principle 6, "Live or gone") is met without inventing a fragile parser per
 * tool. `quality_gate` additionally gets a real inline YAML editor because its
 * config schema is small, fixed, and already defined in Dart
 * (`QualityGateEvaluator.parseConfigFile`).
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as cp from 'node:child_process';
import * as vscode from 'vscode';
import { escapeHtml } from '../vibrancy/views/html-utils';
import { killProcessTree, resolveCliCwd } from './devCliRoot';
import { l10n } from '../i18n/runtime';
import { saropaLintsDataPath } from '../reportsPaths';

/** One report card's static description — id, CLI binary name, and how to build its argv. */
export interface ReportCardSpec {
  /** Stable id used in postMessage routing and DOM element ids (`report-<id>`). */
  readonly id: string;
  /** Package executable name after `saropa_lints:` (see `pubspec.yaml` `executables:`). */
  readonly binary: string;
  readonly titleKey: string;
  readonly descKey: string;
  /** Builds argv (excluding `run saropa_lints:<binary>`) from the scanned project root. */
  readonly buildArgs: (root: string) => string[];
  /** Only `quality_gate` gets the inline YAML threshold editor. */
  readonly hasGateEditor?: boolean;
}

/**
 * The 7 CLIs from the Phase 6 plan, in the order they should appear. Each
 * `buildArgs` passes the real project root as an explicit path argument where
 * the tool supports one — `resolveCliCwd` may point at the saropa_lints dev
 * repo under F5 (see `devCliRoot.ts`), so a bare relative default would
 * silently scan the wrong project for the four tools that accept a path.
 * `stub_test_report` and `accuracy_report` have no path argument at all (they
 * walk a fixed relative dir from `cwd`), so cwd alone decides their target —
 * correct in production (cwd === root) and a deliberate self-test in dev mode.
 */
export function reportCardSpecs(): ReportCardSpec[] {
  return [
    {
      id: 'severity',
      binary: 'severity_report',
      titleKey: 'projectMap.reports.severity.title',
      descKey: 'projectMap.reports.severity.desc',
      buildArgs: (root) => [root],
    },
    {
      id: 'impact',
      binary: 'impact_report',
      titleKey: 'projectMap.reports.impact.title',
      descKey: 'projectMap.reports.impact.desc',
      buildArgs: (root) => [root],
    },
    {
      id: 'qualityGate',
      binary: 'quality_gate',
      titleKey: 'projectMap.reports.qualityGate.title',
      descKey: 'projectMap.reports.qualityGate.desc',
      // Report/config paths default relative to cwd in the Dart tool; passing
      // --project-root pins both to the scanned project regardless of which
      // saropa_lints CLI actually executes (see resolveCliCwd).
      buildArgs: (root) => ['--project-root', root],
      hasGateEditor: true,
    },
    {
      id: 'stubTest',
      binary: 'stub_test_report',
      titleKey: 'projectMap.reports.stubTest.title',
      descKey: 'projectMap.reports.stubTest.desc',
      buildArgs: () => [],
    },
    {
      id: 'accuracy',
      binary: 'accuracy_report',
      titleKey: 'projectMap.reports.accuracy.title',
      descKey: 'projectMap.reports.accuracy.desc',
      buildArgs: () => [],
    },
    {
      id: 'memory',
      binary: 'memory_report',
      titleKey: 'projectMap.reports.memory.title',
      descKey: 'projectMap.reports.memory.desc',
      buildArgs: (root) => [root],
    },
    {
      id: 'doctor',
      binary: 'doctor',
      titleKey: 'projectMap.reports.doctor.title',
      descKey: 'projectMap.reports.doctor.desc',
      buildArgs: (root) => [root],
    },
  ];
}

/** Absolute path to the quality-gate threshold config at the project root. */
function qualityGateConfigPath(root: string): string {
  return path.join(root, 'saropa_quality_gate.yaml');
}

/** Scaffold written into the editor when no config file exists yet, matching `quality_gate.dart --help`. */
function qualityGateScaffold(): string {
  return `quality_gate:
  conditions:
    - metric: new_critical_issues
      op: eq
      value: 0
      on_fail: fail
`;
}

/** Reads the quality-gate YAML for the editor, or the scaffold template if the file doesn't exist yet. */
export function readQualityGateConfig(root: string): string {
  const configPath = qualityGateConfigPath(root);
  try {
    if (fs.existsSync(configPath)) {
      return fs.readFileSync(configPath, 'utf8');
    }
  } catch {
    // Fall through to the scaffold — a read error is not fatal, just means
    // the editor starts from the documented template instead of disk content.
  }
  return qualityGateScaffold();
}

/** Writes the quality-gate YAML back to disk; throws on failure so the caller can toast it. */
export function writeQualityGateConfig(root: string, contents: string): void {
  fs.writeFileSync(qualityGateConfigPath(root), contents, 'utf8');
}

/** One report run's live handlers — mirrors the vibrancy scan runner's shape for consistency. */
export interface ReportRunHandlers {
  onLine: (text: string, stream: 'stdout' | 'stderr') => void;
  onDone: (exitCode: number | null) => void;
}

/** A running report process's cancel handle. */
export interface ReportRunControl {
  cancel: () => void;
}

const SPAWN_USE_SHELL = process.platform === 'win32';

/**
 * Spawns `dart run saropa_lints:<binary> <args>` and streams stdout/stderr to
 * [handlers.onLine] line by line as it arrives — the live-update mechanism
 * every report card's Run button uses. Buffers an incomplete trailing line
 * between chunks so a report's output is never split mid-word.
 */
export function runReportCli(
  root: string,
  spec: ReportCardSpec,
  handlers: ReportRunHandlers,
): ReportRunControl {
  const args = ['run', `saropa_lints:${spec.binary}`, ...spec.buildArgs(root)];
  const child = cp.spawn('dart', args, { cwd: resolveCliCwd(root), shell: SPAWN_USE_SHELL });
  let stdoutBuf = '';
  let stderrBuf = '';

  const flushLines = (
    buf: string,
    chunk: string,
    stream: 'stdout' | 'stderr',
  ): string => {
    const combined = buf + chunk;
    const lines = combined.split('\n');
    const remainder = lines.pop() ?? '';
    for (const line of lines) {
      // Drop the bare carriage return Windows leaves behind before the split.
      handlers.onLine(line.replace(/\r$/, ''), stream);
    }
    return remainder;
  };

  child.stdout.on('data', (chunk: Buffer | string) => {
    stdoutBuf = flushLines(stdoutBuf, chunk.toString(), 'stdout');
  });
  child.stderr.on('data', (chunk: Buffer | string) => {
    stderrBuf = flushLines(stderrBuf, chunk.toString(), 'stderr');
  });
  child.on('error', (err: Error) => {
    handlers.onLine(err.message, 'stderr');
    handlers.onDone(null);
  });
  child.on('close', (code: number | null) => {
    // Flush whatever partial line never saw a trailing '\n'.
    if (stdoutBuf.length > 0) handlers.onLine(stdoutBuf, 'stdout');
    if (stderrBuf.length > 0) handlers.onLine(stderrBuf, 'stderr');
    handlers.onDone(code);
  });
  return {
    cancel: () => killProcessTree(child),
  };
}

/** Report-run output persisted alongside the health scan output, so a run leaves a real artifact. */
export function reportsOutputDir(root: string): string {
  return path.join(saropaLintsDataPath(root), 'reports-tab');
}

/**
 * Best-effort persistence of one report run's combined output — mirrors the
 * Code Health dashboard's "Saved to" pattern (writeReportFile in
 * projectVibrancyReportView.ts) so a run leaves a file a user can diff or
 * paste, not just a scrollback the user has to copy manually.
 */
export function persistReportOutput(root: string, reportId: string, text: string): string | undefined {
  try {
    const dir = reportsOutputDir(root);
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, `${reportId}.log`);
    fs.writeFileSync(file, text, 'utf8');
    return file;
  } catch {
    return undefined;
  }
}

/** Renders the whole Reports tab body: intro line + one card per [reportCardSpecs]. */
export function buildReportsTabHtml(): string {
  const cards = reportCardSpecs().map(buildReportCard).join('');
  return `<section class="reports-intro">
  <p>${escapeHtml(l10n('projectMap.reports.intro'))}</p>
</section>
<div class="report-cards">${cards}</div>`;
}

/** One report card: title, description, optional YAML editor, Run button, and its live output table. */
function buildReportCard(spec: ReportCardSpec): string {
  const editor = spec.hasGateEditor ? buildGateEditor() : '';
  return `<section class="chart-card report-card" id="report-${spec.id}" data-report-id="${spec.id}">
  <h3>${escapeHtml(l10n(spec.titleKey))}</h3>
  <p class="report-desc">${escapeHtml(l10n(spec.descKey))}</p>
  ${editor}
  <div class="toolbar-row">
    <button type="button" class="btn tier-1 report-run-btn" data-report-id="${spec.id}">
      ${escapeHtml(l10n('projectMap.reports.runButton'))}
    </button>
    <span class="report-status" id="report-status-${spec.id}"></span>
  </div>
  <div class="dash-table-wrap report-output-wrap" id="report-output-wrap-${spec.id}" hidden>
    <table class="dash-table">
      <thead><tr>
        <th class="col-line">${escapeHtml(l10n('projectMap.reports.colLine'))}</th>
        <th>${escapeHtml(l10n('projectMap.reports.colText'))}</th>
      </tr></thead>
      <tbody id="report-output-${spec.id}"></tbody>
    </table>
  </div>
</section>`;
}

/**
 * Inline threshold editor for `saropa_quality_gate.yaml`. Plain `<textarea>`
 * rather than a structured form: the schema is a short, well-documented YAML
 * list (`quality_gate.conditions[]`) and round-tripping through a form would
 * add UI weight without buying safety — the file is re-parsed by the same
 * `QualityGateEvaluator.parseConfigFile` the CLI uses either way.
 */
function buildGateEditor(): string {
  return `<div class="gate-editor">
  <label class="gate-editor-label" for="gateYamlEditor">${escapeHtml(l10n('projectMap.reports.gate.editorLabel'))}</label>
  <textarea id="gateYamlEditor" class="gate-yaml" rows="8" spellcheck="false"
    placeholder="${escapeHtml(l10n('projectMap.reports.gate.placeholder'))}"></textarea>
  <div class="toolbar-row">
    <button type="button" class="btn" id="gateSaveBtn">${escapeHtml(l10n('projectMap.reports.gate.save'))}</button>
    <span class="report-status" id="gateSaveStatus"></span>
  </div>
</div>`;
}

/** Handles a Project Map panel message about the Reports tab; returns true if it consumed [msg]. */
export async function handleReportsPanelMessage(
  msg: { type?: string; reportId?: string; text?: string },
  root: string,
  panel: vscode.WebviewPanel,
  controls: Map<string, ReportRunControl>,
): Promise<boolean> {
  if (msg.type === 'loadGateConfig') {
    void panel.webview.postMessage({ type: 'gateConfig', text: readQualityGateConfig(root) });
    return true;
  }
  if (msg.type === 'saveGateConfig' && typeof msg.text === 'string') {
    try {
      writeQualityGateConfig(root, msg.text);
      void panel.webview.postMessage({ type: 'gateConfigSaved', ok: true });
    } catch (e) {
      void panel.webview.postMessage({
        type: 'gateConfigSaved',
        ok: false,
        error: String((e as Error).message ?? e),
      });
    }
    return true;
  }
  if (msg.type === 'runReport' && typeof msg.reportId === 'string') {
    await startReportRun(msg.reportId, root, panel, controls);
    return true;
  }
  if (msg.type === 'cancelReport' && typeof msg.reportId === 'string') {
    controls.get(msg.reportId)?.cancel();
    return true;
  }
  return false;
}

/**
 * Runs one report card's CLI and streams its output to the webview via
 * `reportLine` / `reportDone` messages. [controls] tracks the in-flight
 * process per report id so a Cancel click (or a second Run click) can kill it
 * — mirrors the single-flight guard used for the main Project Map scan,
 * scoped per-card since these CLIs are cheap enough to allow one card running
 * per report id (still serialized against the heavy Map scan by the caller).
 */
async function startReportRun(
  reportId: string,
  root: string,
  panel: vscode.WebviewPanel,
  controls: Map<string, ReportRunControl>,
): Promise<void> {
  const spec = reportCardSpecs().find((s) => s.id === reportId);
  if (!spec) return;
  // A second click while running is treated as cancel-and-restart rather than
  // stacking a duplicate process.
  controls.get(reportId)?.cancel();
  let combined = '';
  const control = runReportCli(root, spec, {
    onLine: (text, stream) => {
      combined += `${text}\n`;
      void panel.webview.postMessage({ type: 'reportLine', reportId, text, stream });
    },
    onDone: (exitCode) => {
      controls.delete(reportId);
      const savedPath = persistReportOutput(root, reportId, combined);
      void panel.webview.postMessage({ type: 'reportDone', reportId, exitCode, savedPath });
    },
  });
  controls.set(reportId, control);
}
