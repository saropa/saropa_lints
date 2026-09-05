/**
 * Unit tests for the Project Map "Reports" tab (`projectMapReports.ts`). Zero
 * coverage before this pass (deferred from Phase 6 — see
 * docs/handover/20260905_0011_keyboard_overlay_and_dead_code.md). Covers the
 * report-card catalogue, the HTML the tab renders from it, and the
 * quality-gate config read/write round-trip the inline YAML editor depends on.
 *
 * `projectMapReports.ts` transitively imports 'vscode' for real at runtime
 * (via `reportsPaths.ts`'s `vscode.Uri.joinPath` calls and `devCliRoot.ts`'s
 * `vscode.extensions.getExtension`), so the vscode mock must be registered
 * before importing it — same requirement as `aboutView.test.ts`.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import type * as vscode from 'vscode';
import {
  reportCardSpecs,
  buildReportsTabHtml,
  readQualityGateConfig,
  writeQualityGateConfig,
  handleReportsPanelMessage,
  type ReportRunControl,
} from '../../views/projectMapReports';

describe('projectMapReports reportCardSpecs', () => {
  it('lists all 7 CLI report cards in the documented order', () => {
    const specs = reportCardSpecs();
    assert.deepStrictEqual(
      specs.map((s) => s.id),
      ['severity', 'impact', 'qualityGate', 'stubTest', 'accuracy', 'memory', 'doctor'],
    );
  });

  it('only the qualityGate card declares the inline YAML editor', () => {
    const flags = reportCardSpecs().map((s) => [s.id, Boolean(s.hasGateEditor)] as const);
    for (const [id, hasEditor] of flags) {
      assert.strictEqual(hasEditor, id === 'qualityGate', `unexpected hasGateEditor for ${id}`);
    }
  });

  it('passes the project root as a bare path arg for tools that accept one', () => {
    const severity = reportCardSpecs().find((s) => s.id === 'severity')!;
    assert.deepStrictEqual(severity.buildArgs('/proj'), ['/proj']);
  });

  it('passes --project-root for quality_gate (its report/config paths default off cwd)', () => {
    const qualityGate = reportCardSpecs().find((s) => s.id === 'qualityGate')!;
    assert.deepStrictEqual(qualityGate.buildArgs('/proj'), ['--project-root', '/proj']);
  });

  it('passes no args for the two path-less tools (stubTest, accuracy)', () => {
    const stubTest = reportCardSpecs().find((s) => s.id === 'stubTest')!;
    const accuracy = reportCardSpecs().find((s) => s.id === 'accuracy')!;
    assert.deepStrictEqual(stubTest.buildArgs('/proj'), []);
    assert.deepStrictEqual(accuracy.buildArgs('/proj'), []);
  });
});

describe('projectMapReports buildReportsTabHtml', () => {
  it('renders one report-card section per catalogue entry, each with a Run button and status span', () => {
    const html = buildReportsTabHtml();
    for (const spec of reportCardSpecs()) {
      assert.ok(html.includes(`id="report-${spec.id}"`), `missing card for ${spec.id}`);
      assert.ok(
        html.includes(`data-report-id="${spec.id}"`),
        `missing data-report-id for ${spec.id}`,
      );
    }
    // 7 cards means 7 Run buttons and 7 status spans (one idle-state entry each).
    const runButtonCount = (html.match(/class="btn tier-1 report-run-btn"/g) ?? []).length;
    assert.strictEqual(runButtonCount, reportCardSpecs().length);
  });

  it('renders the idle "not run yet" status before any run', () => {
    const html = buildReportsTabHtml();
    assert.ok(html.includes('Not run yet'));
  });

  it('renders the inline gate-editor textarea only inside the qualityGate card', () => {
    const html = buildReportsTabHtml();
    const qgIdx = html.indexOf('id="report-qualityGate"');
    const nextCardIdx = html.indexOf('id="report-stubTest"');
    const gateEditorIdx = html.indexOf('id="gateYamlEditor"');
    assert.ok(qgIdx >= 0 && nextCardIdx > qgIdx, 'expected qualityGate before stubTest in output order');
    assert.ok(
      gateEditorIdx > qgIdx && gateEditorIdx < nextCardIdx,
      'gate editor textarea must live inside the qualityGate card only',
    );
    // No other card duplicates the single gate editor.
    assert.strictEqual((html.match(/id="gateYamlEditor"/g) ?? []).length, 1);
  });

  it('starts every report-output table hidden until a run streams a line', () => {
    const html = buildReportsTabHtml();
    for (const spec of reportCardSpecs()) {
      assert.ok(
        html.includes(`id="report-output-wrap-${spec.id}" hidden`),
        `expected report-output-wrap-${spec.id} to start hidden`,
      );
    }
  });
});

describe('projectMapReports quality-gate config read/write', () => {
  let tmpRoot: string;

  beforeEach(() => {
    tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-lints-pm-reports-'));
  });

  afterEach(() => {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  });

  it('returns the documented scaffold when no config file exists yet', () => {
    const text = readQualityGateConfig(tmpRoot);
    assert.match(text, /quality_gate:/);
    assert.match(text, /new_critical_issues/);
  });

  it('round-trips a written config back through the reader', () => {
    const custom = 'quality_gate:\n  conditions:\n    - metric: new_errors\n      op: eq\n      value: 0\n';
    writeQualityGateConfig(tmpRoot, custom);
    assert.strictEqual(readQualityGateConfig(tmpRoot), custom);
    // Confirms the file actually landed at the documented path, not just an
    // in-memory round-trip — a future path refactor that silently changes
    // where this writes would fail this assertion.
    assert.ok(fs.existsSync(path.join(tmpRoot, 'saropa_quality_gate.yaml')));
  });
});

describe('projectMapReports handleReportsPanelMessage', () => {
  /** Captures every postMessage call so assertions can inspect what the host sent back. */
  function fakePanel(): { panel: vscode.WebviewPanel; sent: unknown[] } {
    const sent: unknown[] = [];
    const panel = {
      webview: {
        postMessage: (msg: unknown) => {
          sent.push(msg);
          return Promise.resolve(true);
        },
      },
    } as unknown as vscode.WebviewPanel;
    return { panel, sent };
  }

  let tmpRoot: string;
  let controls: Map<string, ReportRunControl>;

  beforeEach(() => {
    tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-lints-pm-reports-msg-'));
    controls = new Map();
  });

  afterEach(() => {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  });

  it('loadGateConfig posts the current gate YAML back to the webview', async () => {
    const { panel, sent } = fakePanel();
    const consumed = await handleReportsPanelMessage({ type: 'loadGateConfig' }, tmpRoot, panel, controls);
    assert.strictEqual(consumed, true);
    assert.strictEqual(sent.length, 1);
    assert.deepStrictEqual((sent[0] as { type: string }).type, 'gateConfig');
  });

  it('saveGateConfig writes the file and reports success', async () => {
    const { panel, sent } = fakePanel();
    const consumed = await handleReportsPanelMessage(
      { type: 'saveGateConfig', text: 'quality_gate:\n  conditions: []\n' },
      tmpRoot,
      panel,
      controls,
    );
    assert.strictEqual(consumed, true);
    assert.deepStrictEqual(sent[0], { type: 'gateConfigSaved', ok: true });
    assert.strictEqual(
      fs.readFileSync(path.join(tmpRoot, 'saropa_quality_gate.yaml'), 'utf8'),
      'quality_gate:\n  conditions: []\n',
    );
  });

  it('an unrecognized message type is not consumed', async () => {
    const { panel } = fakePanel();
    const consumed = await handleReportsPanelMessage({ type: 'somethingElse' }, tmpRoot, panel, controls);
    assert.strictEqual(consumed, false);
  });
});
