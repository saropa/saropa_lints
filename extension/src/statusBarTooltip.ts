/**
 * Pure builders for the main status bar's hover tooltip and click menu.
 *
 * One model ({@link StatusBarModel}) feeds two renderers so the hover and the
 * QuickPick can never disagree: {@link renderStatusBarTooltip} (markdown with
 * styled pills) and {@link buildStatusBarQuickPickItems} (plain rows). No
 * vscode import here, so everything is unit-testable under mocha.
 *
 * Pills: VS Code hovers render `<span style="color:..;background-color:..">`
 * only when the MarkdownString has `supportHtml` set (all other tags and style
 * properties are stripped), and a link's `"title"` becomes its hover text. A
 * pill is therefore a span wrapped in a command link carrying that title.
 */
import { l10n } from './i18n/runtime';
import { formatNumber } from './views/webview-format';
import {
  buildStatusBarMenuItems,
  type StatusBarMenuItem,
  type StatusBarSwitchKind,
} from './statusBarLabel';
import {
  classifyProcess,
  formatBytes,
  isAnalysisServerProcess,
  ProcessCategory,
  processLabel,
  renderSparkline,
  truncateLabel,
} from './systemHealth/processQuery';
import { HealthLevel } from './systemHealth/types';
import type { DartProcessInfo, DartProcessSnapshot, ExtensionHostMemory, HealthAssessment } from './systemHealth/types';

// ── Model ────────────────────────────────────────────────────────────────

export type PillKind = 'good' | 'warn' | 'bad' | 'info';

export interface TooltipLink {
  readonly label: string;
  readonly commandId: string;
  /** Hover text of the link. */
  readonly title?: string;
}

export interface ModelRow {
  readonly label: string;
  readonly value: string;
  /** Render the value as a pill. */
  readonly pill?: PillKind;
  /** Make the value a command link (hover title = `link.title`). */
  readonly link?: { readonly commandId: string; readonly title: string };
}

export interface ProblemItem {
  readonly text: string;
  readonly link?: TooltipLink;
}

export interface MemoryModel {
  /** Warning / critical / pressure lines, shown bold above the table. */
  readonly hints: readonly string[];
  readonly rows: readonly ModelRow[];
  readonly sparkline?: string;
}

export interface StatusBarModel {
  readonly kind: StatusBarSwitchKind;
  readonly headline: string;
  readonly cause: string;
  readonly fix?: TooltipLink;
  readonly project: readonly ModelRow[];
  readonly problems: readonly ProblemItem[];
  readonly memory?: MemoryModel;
  readonly actions: readonly StatusBarMenuItem[];
}

// ── Formatting helpers ───────────────────────────────────────────────────

/** Findings as "18,368 findings (all errors)" or "N errors · M warnings". */
export function formatFindings(total: number, errors: number): string {
  if (errors <= 0) return l10n('statusBar.tooltip.findings.noErrors', { total: formatNumber(total) });
  if (errors >= total) {
    return l10n(total === 1 ? 'statusBar.tooltip.findings.allErrorsOne' : 'statusBar.tooltip.findings.allErrors', {
      count: formatNumber(total),
    });
  }
  return l10n('statusBar.tooltip.findings.mixed', {
    errors: formatNumber(errors),
    warnings: formatNumber(total - errors),
  });
}

/** Escape text for a markdown table cell / link label inside an html-enabled hover:
 *  newlines collapse to a space, `$` is escaped so text cannot render codicons. */
export function escapeMd(text: string): string {
  return text
    .replace(/\s*[\r\n]+\s*/g, ' ')
    .replace(/[\\`*_[\]|$]/g, (c) => `\\${c}`)
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

const PILL_COLORS: Readonly<Record<PillKind, string>> = {
  good: '#2e7d32',
  warn: '#b26a00',
  bad: '#c62828',
  info: '#455a64',
};

/** A colored label (span with color + background-color only — the sole styles hovers allow). */
export function pillHtml(text: string, kind: PillKind): string {
  return `<span style="color:#ffffff;background-color:${PILL_COLORS[kind]};">&nbsp;${escapeMd(text)}&nbsp;</span>`;
}

function linkMd(labelMarkdown: string, commandId: string, title?: string): string {
  const t = title ? ` "${title.replace(/"/g, "'")}"` : '';
  return `[${labelMarkdown}](command:${commandId}${t})`;
}

// ── Memory section ───────────────────────────────────────────────────────

export interface MemoryInput {
  /** Absent before the first process snapshot; only machine RAM is shown then. */
  readonly snap?: DartProcessSnapshot;
  readonly assessment: HealthAssessment;
  /** Arrow suffix (" ↑", " ↓", " →" or "") for the Saropa RSS trend. */
  readonly saropaTrendArrow: string;
  readonly saropaRising: boolean;
  readonly rssHistory: readonly number[];
  readonly extHost?: ExtensionHostMemory;
  readonly extHostTrendArrow: string;
  /** Machine-wide RAM, when known. */
  readonly systemRam?: { readonly freeBytes: number; readonly totalBytes: number };
}

function appendProcessRows(
  snap: DartProcessSnapshot,
  input: MemoryInput,
  rows: ModelRow[],
  hints: string[],
): void {
  const { assessment } = input;
  const K = 'statusBar.tooltip.memory.';
  const saropa: DartProcessInfo[] = [];
  const other: DartProcessInfo[] = [];
  for (const p of snap.processes) {
    const cat = classifyProcess(p).category;
    if (cat === ProcessCategory.Saropa) saropa.push(p);
    else if (cat !== ProcessCategory.Daemon) other.push(p); // AnalysisServer and Other
  }
  const byRss = (a: DartProcessInfo, b: DartProcessInfo): number => b.workingSetSize - a.workingSetSize;
  const sum = (ps: DartProcessInfo[]): number => ps.reduce((s, p) => s + p.workingSetSize, 0);

  // A rising arrow already is the warning; a check beside it would contradict it.
  const healthy = assessment.level === HealthLevel.Healthy && !input.saropaRising;
  rows.push({
    label: l10n(K + 'saropa'),
    value: saropa.length === 0
      ? l10n(K + 'none')
      : l10n(K + 'processes', { count: formatNumber(saropa.length), size: formatBytes(sum(saropa)) })
        + input.saropaTrendArrow + (healthy ? ' ✓' : ''),
  });
  for (const p of [...saropa].sort(byRss).slice(0, 3)) {
    rows.push({ label: `↳ ${truncateLabel(processLabel(p))}`, value: formatBytes(p.workingSetSize) });
  }

  const orphaned = snap.orphanedDaemonPids.length;
  rows.push({
    label: l10n(K + 'daemons'),
    value: l10n(K + 'daemonsValue', {
      total: formatNumber(snap.legitimateDaemonCount + orphaned),
      orphaned: formatNumber(orphaned),
    }),
  });
  if (snap.orphanedScanDaemonPids.length > 0) {
    rows.push({
      label: l10n(K + 'scanDaemons'),
      value: l10n(K + 'scanDaemonsValue', { count: formatNumber(snap.orphanedScanDaemonPids.length) }),
    });
  }

  if (other.length > 0) {
    rows.push({
      label: l10n(K + 'other'),
      value: l10n(K + 'processes', { count: formatNumber(other.length), size: formatBytes(sum(other)) }),
    });
    for (const p of [...other].sort(byRss).slice(0, 3)) {
      rows.push({ label: `↳ ${truncateLabel(processLabel(p))}`, value: formatBytes(p.workingSetSize) });
    }
    const servers = other.filter(isAnalysisServerProcess).length;
    if (servers >= 2) hints.push(l10n('systemHealth.tooltip.otherHint', { count: formatNumber(servers) }));
  }
}

/**
 * Memory/process detail as table rows. Everything the old flat lines showed is
 * kept: Saropa processes (top 3 named), Flutter daemons and orphans, other Dart
 * processes (top 3 named plus the multiple-servers hint), extension host,
 * machine RAM, and the RSS trend sparkline.
 */
export function buildMemoryModel(input: MemoryInput): MemoryModel {
  const { snap, assessment } = input;
  const rows: ModelRow[] = [];
  const hints: string[] = [];
  const K = 'statusBar.tooltip.memory.';
  if (snap) appendProcessRows(snap, input, rows, hints);

  if (input.extHost) {
    rows.push({
      label: l10n(K + 'extHost'),
      value: l10n(K + 'extHostValue', {
        rss: formatBytes(input.extHost.rssBytes),
        heap: formatBytes(input.extHost.heapUsedBytes),
        heapTotal: formatBytes(input.extHost.heapTotalBytes),
      }) + input.extHostTrendArrow,
    });
  }
  if (input.systemRam) {
    rows.push({
      label: l10n(K + 'ram'),
      value: l10n(K + 'ramValue', {
        free: formatBytes(input.systemRam.freeBytes),
        total: formatBytes(input.systemRam.totalBytes),
      }),
    });
  }

  if (assessment.level === HealthLevel.Warning) hints.push(l10n('systemHealth.tooltip.warningHint'));
  else if (assessment.level === HealthLevel.Critical) hints.push(l10n('systemHealth.tooltip.criticalHint'));

  const sparkline = renderSparkline(input.rssHistory);
  return { hints, rows, sparkline: sparkline || undefined };
}

// ── Model assembly ───────────────────────────────────────────────────────

export interface RouteInfo {
  /** Route state name from start-up detection; `neither` = not set up. */
  readonly state: string;
  readonly text: string;
  /** Plain-words explanation (no "click" sentence). */
  readonly tip: string;
}

export interface StatusBarInput {
  readonly kind: StatusBarSwitchKind;
  /** Which half is off when `kind` is `partial`. */
  readonly partialOff?: 'setting' | 'plugin';
  /** Short switch label, e.g. "Saropa Lints: Partly off". */
  readonly label: string;
  readonly extVersion: string;
  /** Absent when the switch is Off (no analysis to report). */
  readonly details?: {
    readonly tier: string;
    readonly scorePercent?: number;
    readonly scorePending: boolean;
    readonly vibrancy?: {
      readonly label: string;
      readonly packageCount: number;
      readonly suppressedCount: number;
      readonly updateCount: number;
      readonly actionCount: number;
    };
    readonly findings?: { readonly total: number; readonly errors: number };
  };
  readonly route?: RouteInfo;
  /** One line per workspace readiness issue, naming the issue. */
  readonly readinessIssues: readonly string[];
  /** Memory-pressure and system-health summary lines (not the readiness count). */
  readonly memoryHints: readonly string[];
  readonly memory?: MemoryModel;
}

const REPORT_CMD = 'saropaLints.openViolationsWideReport';
const VIBRANCY_CMD = 'saropaLints.openProjectVibrancyReport';
const TOGGLE_CMD = 'saropaLints.toggleLints';
const COMPAT_CMD = 'saropaLints.configureCompatibility';

/** One diagnosis per state — the "not set up" case is the same message whichever source noticed it. */
function causeFor(input: StatusBarInput, notSetUp: boolean): string {
  const K = 'statusBar.tooltip.cause.';
  if (input.kind === 'on') return l10n(K + 'on');
  if (notSetUp) return l10n(K + 'notSetUp');
  if (input.kind === 'off') return l10n(K + 'off');
  return l10n(input.partialOff === 'setting' ? K + 'partialSetting' : K + 'partialPlugin');
}

export function buildStatusBarModel(input: StatusBarInput): StatusBarModel {
  const notSetUp = input.kind !== 'on' && input.route?.state === 'neither';
  const T = 'statusBar.tooltip.';
  const fix: TooltipLink | undefined = input.kind === 'on'
    ? undefined
    : {
        label: l10n(notSetUp ? T + 'fix.setUp' : T + 'fix.turnOn'),
        commandId: TOGGLE_CMD,
        title: l10n(T + 'fix.title'),
      };

  const project: ModelRow[] = [{ label: l10n(T + 'project.version'), value: `v${input.extVersion}` }];
  const d = input.details;
  if (d) {
    project.push({ label: l10n(T + 'project.tier'), value: d.tier });
    if (d.vibrancy) {
      project.push({
        label: l10n(T + 'project.vibrancy'),
        value: d.vibrancy.label,
        pill: 'info',
        link: { commandId: VIBRANCY_CMD, title: l10n(T + 'pill.vibrancy') },
      });
      project.push({
        label: l10n(T + 'project.packages'),
        value: d.vibrancy.suppressedCount > 0
          ? l10n(T + 'project.packagesSuppressed', {
              count: formatNumber(d.vibrancy.packageCount),
              suppressed: formatNumber(d.vibrancy.suppressedCount),
            })
          : formatNumber(d.vibrancy.packageCount),
      });
    }
    if (d.scorePercent !== undefined) {
      project.push({ label: l10n(T + 'project.score'), value: `${d.scorePercent}%` });
    } else if (d.scorePending) {
      project.push({ label: l10n(T + 'project.score'), value: l10n(T + 'project.scorePending') });
    }
    if (d.findings) {
      project.push({
        label: l10n(T + 'project.findings'),
        value: formatFindings(d.findings.total, d.findings.errors),
        pill: d.findings.errors > 0 ? 'bad' : 'warn',
        link: { commandId: REPORT_CMD, title: l10n(T + 'pill.findings') },
      });
    }
    if (d.vibrancy && d.vibrancy.updateCount > 0) {
      project.push({ label: l10n(T + 'project.updates'), value: formatNumber(d.vibrancy.updateCount) });
    }
    if (d.vibrancy && d.vibrancy.actionCount > 0) {
      project.push({ label: l10n(T + 'project.actionItems'), value: formatNumber(d.vibrancy.actionCount) });
    }
  }
  // Route row. The "not set up" state is the status cause above, not repeated here.
  if (input.route && !notSetUp) {
    project.push({
      label: l10n(T + 'project.route'),
      value: input.route.text,
      link: { commandId: COMPAT_CMD, title: input.route.tip },
    });
  }

  const problems: ProblemItem[] = [];
  if (input.route && (input.route.state === 'bothDisagree' || input.route.state === 'dartTooOld')) {
    problems.push({
      text: input.route.tip,
      link: { label: l10n(T + 'problem.openCompat'), commandId: COMPAT_CMD },
    });
  }
  for (const issue of input.readinessIssues) {
    problems.push({
      text: issue,
      link: { label: l10n(T + 'problem.reviewReadiness'), commandId: 'saropaLints.showWorkspaceReadiness' },
    });
  }

  const memory = input.memory || input.memoryHints.length > 0
    ? {
        hints: [...input.memoryHints, ...(input.memory?.hints ?? [])],
        rows: input.memory?.rows ?? [],
        sparkline: input.memory?.sparkline,
      }
    : undefined;

  return {
    kind: input.kind,
    headline: input.label,
    cause: causeFor(input, notSetUp),
    fix,
    project,
    problems,
    memory,
    actions: buildStatusBarMenuItems(input.kind),
  };
}

// ── Markdown renderer ────────────────────────────────────────────────────

function headlinePillKind(kind: StatusBarSwitchKind): PillKind {
  return kind === 'on' ? 'good' : kind === 'partial' ? 'warn' : 'bad';
}

function renderValue(row: ModelRow): string {
  const text = row.pill ? pillHtml(row.value, row.pill) : escapeMd(row.value);
  return row.link ? linkMd(text, row.link.commandId, row.link.title) : text;
}

function renderTable(rows: readonly ModelRow[]): string {
  const lines = ['| | |', '|---|---|'];
  for (const r of rows) lines.push(`| ${escapeMd(r.label)} | ${renderValue(r)} |`);
  return lines.join('\n');
}

/** Hover markdown (render with `supportHtml` and `supportThemeIcons`). */
export function renderStatusBarTooltip(model: StatusBarModel): string {
  const T = 'statusBar.tooltip.';
  const out: string[] = [];

  const pillTarget = model.fix
    ? { commandId: model.fix.commandId, title: model.fix.title ?? '' }
    : { commandId: REPORT_CMD, title: l10n(T + 'pill.statusOn') };
  out.push(`#### ${l10n(T + 'section.status')}`);
  out.push(linkMd(pillHtml(model.headline, headlinePillKind(model.kind)), pillTarget.commandId, pillTarget.title));
  out.push(escapeMd(model.cause));
  if (model.fix) out.push(linkMd(`$(wrench) ${escapeMd(model.fix.label)}`, model.fix.commandId, model.fix.title));

  out.push(`#### ${l10n(T + 'section.project')}`, renderTable(model.project));

  if (model.problems.length > 0) {
    out.push(`#### ${l10n(T + 'section.problems')}`);
    out.push(model.problems
      .map((p) => `- ${escapeMd(p.text)}${p.link ? ` → ${linkMd(escapeMd(p.link.label), p.link.commandId, p.link.title)}` : ''}`)
      .join('\n'));
  }

  if (model.memory) {
    out.push(`#### ${l10n(T + 'section.memory')}`);
    for (const h of model.memory.hints) out.push(`**${escapeMd(h)}**`);
    if (model.memory.rows.length > 0) out.push(renderTable(model.memory.rows));
    if (model.memory.sparkline) {
      out.push(`${escapeMd(l10n('statusBar.tooltip.memory.trend'))}: \`${model.memory.sparkline}\``);
    }
  }

  out.push(`#### ${l10n(T + 'section.actions')}`);
  for (const group of ['toggle', 'report', 'utility'] as const) {
    const links = model.actions
      .filter((a) => a.group === group)
      .map((a) => linkMd(`${a.icon} ${escapeMd(l10n(a.labelKey))}`, a.commandId));
    if (links.length > 0) out.push(links.join(' &nbsp;·&nbsp; '));
  }
  return out.join('\n\n');
}

// ── QuickPick renderer ───────────────────────────────────────────────────

export interface QuickPickRow {
  readonly label: string;
  readonly description?: string;
  readonly detail?: string;
  /** Command run when the row is picked; absent for headings and info rows. */
  readonly commandId?: string;
  /** A section heading rather than a pickable row. */
  readonly separator?: boolean;
}

/** Status, problems and action rows — the same content as the hover. */
export function buildStatusBarQuickPickItems(model: StatusBarModel): QuickPickRow[] {
  const T = 'statusBar.tooltip.';
  const icon = model.kind === 'on' ? '$(pass)' : '$(warning)';
  const rows: QuickPickRow[] = [
    { label: l10n(T + 'section.status'), separator: true },
    { label: `${icon} ${model.headline}`, detail: model.cause },
  ];
  if (model.fix) rows.push({ label: `$(wrench) ${model.fix.label}`, commandId: model.fix.commandId, detail: model.fix.title });
  if (model.problems.length > 0) {
    rows.push({ label: l10n(T + 'section.problems'), separator: true });
    for (const p of model.problems) {
      rows.push({ label: `$(warning) ${p.text}`, description: p.link?.label, commandId: p.link?.commandId });
    }
  }
  rows.push({ label: l10n(T + 'section.actions'), separator: true });
  for (const a of model.actions) {
    rows.push({ label: `${a.icon} ${l10n(a.labelKey)}`, commandId: a.commandId });
  }
  return rows;
}
