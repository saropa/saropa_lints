import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { analysisOptionsEnrolsSaropa } from '../pluginLiveness';
import { saropaLintsDataPath } from '../reportsPaths';

/**
 * Plugin-side memory pressure state, written to `memory_state.json`
 * by the Dart analyzer plugin on shed-level transitions.
 */
export interface MemoryPressureState {
  /** Cost-aware shed level: 0=normal, 1=expensive (type-resolving+high-cost), 2=+INFO, 3=+WARNING. */
  shedLevel: number;
  /** Current resident-set size in MB when the transition occurred. */
  rssMb: number;
  /** Soft memory limit in MB (70% of hard limit). */
  softLimitMb: number;
  /** Hard memory limit in MB (env SAROPA_LINTS_MAX_RSS_MB or 4096). */
  hardLimitMb: number;
  /** Whether the soft RSS threshold has been crossed. */
  softLimitTripped: boolean;
  /** Whether the hard RSS limit has been exceeded (all rules paused). */
  hardLimitTripped: boolean;
  /** Number of rules currently shed. */
  shedRuleCount: number;
  /** Whether the user has opted in via `shed_rules: true`. */
  shedEnabled: boolean;
  /** ISO 8601 timestamp of the transition. */
  timestamp: string;
  /** Breakdown of shed rules by category — written when shedLevel > 0. */
  shedDetails?: {
    typeResolving: number;
    highCost: number;
    infoSeverity: number;
    warningSeverity: number;
    typeResolvingRules?: string[];
    highCostRules?: string[];
    infoSeverityRules?: string[];
    warningSeverityRules?: string[];
  };
}

/**
 * When this extension host PROCESS started, in epoch milliseconds.
 *
 * Deliberately derived from `process.uptime()` rather than from the clock at
 * module load. Module load happens at *activation* (`onLanguage:dart`), which
 * is triggered by the user opening a Dart file — potentially seconds or
 * minutes after the analyzer plugin has already written a pressure
 * transition. Anchoring on activation time would classify that genuinely live
 * state as stale and hide it. The host process, by contrast, is spawned as
 * part of window startup, before the Dart extension launches the analysis
 * server that hosts the plugin, so nothing a live plugin can write in this
 * window predates it. That makes it the correct — and conservative in the
 * right direction — session boundary.
 *
 * Computed by a function rather than a one-time module-level constant
 * (T4 fix): a `const` here is evaluated exactly once, the first time this
 * module is `import`ed into the extension host process. That is correct
 * when the process itself is fresh, but "Developer: Restart Extension
 * Host" and a plain disable/enable toggle can both re-run `activate()`
 * inside the SAME already-running process (Node's module cache means the
 * file is not re-evaluated), so a cached constant would keep reporting
 * the ORIGINAL process's start time — often hours stale — and the
 * liveness gate would then reject genuinely live state written after the
 * restart, until the next shed-level transition finally moves the
 * session boundary forward. Recomputing on every call sidesteps the
 * caching question entirely: fresh process or reused process, this always
 * reflects the current `process.uptime()`.
 */
function computeHostStartMs(): number {
  return Date.now() - process.uptime() * 1000;
}

/** Inputs to the staleness/liveness decision. Grouped so the check stays pure. */
export interface MemoryStateLivenessInput {
  /** `mtimeMs` of `memory_state.json`, or null when it could not be stat'd. */
  writtenAtMs: number | null;
  /** Epoch ms marking the start of the current extension host session. */
  sessionStartMs: number;
  /** Whether `analysis_options.yaml` currently enrols the analyzer plugin. */
  pluginEnrolled: boolean;
}

/**
 * Whether `memory_state.json` can be trusted to describe a plugin that is
 * actually running right now.
 *
 * Both conditions must hold, and each catches a failure the other misses:
 *
 *  - **Enrolment.** The reported incident: the user commented the `plugins:`
 *    block out of `analysis_options.yaml`, so no plugin was loaded at all,
 *    yet the status bar kept showing "Rules paused (8425 MB)" from a file
 *    written days earlier. mtime alone would not catch a variant where
 *    something else touches the file; enrolment answers "could a plugin even
 *    be running?" directly from the configuration that decides it.
 *  - **Freshness against the session.** Enrolment alone is not enough either:
 *    a plugin can be enrolled and still be dead (crashed isolate, analysis
 *    server never started, stale cache). The state file outlives the process
 *    that wrote it, so an orphaned file from a previous run would still
 *    render.
 *
 * Why the session boundary and not a fixed age window (say "younger than five
 * minutes"): the plugin writes this file only on shed-level *transitions*, so
 * a genuinely paused plugin may legitimately not rewrite it for hours. Any
 * fixed max-age would eventually hide state that is still true. The session
 * boundary is the honest one — a plugin lives inside the analysis server,
 * which restarts with the window, so state written before this session was by
 * definition written by a process that no longer exists.
 *
 * Why not a plugin-written heartbeat file (option B in the bug report): it is
 * the strongest signal, but it requires a Dart-side change to write and
 * delete it, and a heartbeat that is never deleted on a hard crash degrades
 * back to exactly the staleness problem being fixed here. This gate needs no
 * plugin cooperation and cannot be defeated by an unclean shutdown.
 *
 * Errs toward hiding: if a live plugin's state is wrongly suppressed the user
 * sees a silent status bar, which is merely uninformative. The failure this
 * replaces sent a user investigating a memory problem that did not exist.
 */
export function isMemoryStateLive(input: MemoryStateLivenessInput): boolean {
  // No plugin enrolled means nothing can be writing this file — whatever it
  // contains describes a configuration the user has since turned off.
  if (!input.pluginEnrolled) return false;
  // Could not stat the file: treat as unknown, and unknown is not live.
  if (input.writtenAtMs === null) return false;
  return input.writtenAtMs >= input.sessionStartMs;
}

/**
 * Directory names skipped while scanning for a nested package's
 * `analysis_options.yaml` (monorepo case). None of these ever contain a
 * Dart/Flutter package of interest, and skipping them keeps the scan cheap
 * — it runs on every debounced state-file event, not just at startup.
 */
const MONOREPO_SCAN_EXCLUDES = new Set([
  '.git',
  '.dart_tool',
  '.idea',
  '.vscode',
  'build',
  'node_modules',
  'ios',
  'android',
]);

/** Whether [dir]'s own `analysis_options.yaml` enrols the plugin. */
function pluginEnrolledAt(dir: string): boolean {
  try {
    const optionsPath = path.join(dir, 'analysis_options.yaml');
    return analysisOptionsEnrolsSaropa(fs.readFileSync(optionsPath, 'utf8'));
  } catch {
    // Missing or unreadable analysis_options.yaml — the plugin cannot be
    // enrolled through a file that is not there.
    return false;
  }
}

/**
 * Whether the project at [root] currently enrols the analyzer plugin.
 *
 * Read fresh on every state-file event rather than cached at startup, so a
 * user who re-enables the plugin mid-session gets their status bar back
 * without reloading the window. The read is cheap and only happens on a
 * debounced file-change event, never on a timer.
 *
 * Also checks first-level subdirectories (monorepo fix). A pub workspace
 * commonly enrols the plugin in a nested package's `analysis_options.yaml`
 * rather than at the workspace root — the root itself may have no
 * `analysis_options.yaml` at all. Without this fallback, such a project
 * reads as "not enrolled" forever, and the status bar goes silently dead
 * with no diagnostic pointing at why. Only one level deep is walked: going
 * deeper without a real pubspec `workspace:` list resolver risks scanning
 * arbitrary unrelated directories on every event.
 */
function pluginEnrolledInAnalysisOptions(root: string): boolean {
  if (pluginEnrolledAt(root)) return true;

  let entries: fs.Dirent[];
  try {
    entries = fs.readdirSync(root, { withFileTypes: true });
  } catch {
    // Root itself unreadable — nothing more to check.
    return false;
  }
  for (const entry of entries) {
    if (!entry.isDirectory() || MONOREPO_SCAN_EXCLUDES.has(entry.name)) continue;
    if (pluginEnrolledAt(path.join(root, entry.name))) return true;
  }
  return false;
}

/**
 * Watches `reports/.saropa_lints/memory_state.json` for shed-level transitions
 * written by the analyzer plugin and notifies listeners on significant changes.
 *
 * Uses `fs.watch` on the reports directory — no polling. Only fires when
 * shedLevel or hardLimitTripped changes to avoid noisy re-renders.
 *
 * The file is only ever surfaced when {@link isMemoryStateLive} confirms it
 * describes a plugin that is running now; a stale or orphaned file publishes
 * `null`, which renders as a silent status bar.
 */
export class MemoryPressureWatcher implements vscode.Disposable {
  private _watcher: fs.FSWatcher | null = null;
  private _state: MemoryPressureState | null = null;
  private _onStateChange:
    | ((state: MemoryPressureState | null) => void)
    | null = null;
  /** Workspace root being watched — needed to locate analysis_options.yaml. */
  private _root: string | null = null;
  /** Session boundary every read is measured against. */
  private readonly _sessionStartMs: number;
  /**
   * Pending debounce timer from the `fs.watch` callback in `start()` (fix
   * for the debounce-timer leak on dispose). This used to be a `let` local
   * to `start()`'s closure, so `dispose()` had no handle on it and could
   * only close the `fs.FSWatcher`. A timer already in flight when
   * `dispose()` ran would still fire ~80ms later and call `_tryRead` against
   * the OLD root's state file — while `_isLive` reads `_root`/`_sessionStartMs`
   * which `start()` may have already reassigned to a NEW root by then,
   * producing a read that mixes state from two different projects. Storing
   * the id as an instance field lets `dispose()` cancel it before it fires.
   */
  private _debounceTimer: ReturnType<typeof setTimeout> | null = null;

  /**
   * @param sessionStartMs overrides the session boundary; only tests pass it,
   *   so they can exercise both sides of the staleness gate without waiting
   *   on wall-clock time.
   */
  constructor(sessionStartMs: number = computeHostStartMs()) {
    this._sessionStartMs = sessionStartMs;
  }

  /** Register the callback invoked on significant state changes. */
  onStateChange(cb: (state: MemoryPressureState | null) => void): void {
    this._onStateChange = cb;
  }

  /** Begin watching the reports directory under [root]. */
  start(root: string): void {
    this.dispose();
    // Retained for the per-read enrolment check, which has to re-read
    // analysis_options.yaml from this same root.
    this._root = root;

    // Shared helper keeps this in sync with the other reports/.saropa_lints consumers.
    const reportsDir = saropaLintsDataPath(root);
    const stateFile = path.join(reportsDir, 'memory_state.json');

    // Try an initial read — the file may already exist from a prior session.
    this._tryRead(stateFile);

    // Watch the directory, filtering for memory_state.json changes.
    // fs.watch `filename` can be null on macOS FSEvents and some Linux
    // configurations — fall back to reading on any event when null.
    try {
      this._watcher = fs.watch(reportsDir, (_eventType, filename) => {
        if (filename !== null && filename !== 'memory_state.json') return;
        // Debounce — Windows commonly fires 2-3 events per write. Stored on
        // `this` (not a closure local) so `dispose()` can cancel a pending
        // fire — see the field doc comment for why that matters.
        if (this._debounceTimer) clearTimeout(this._debounceTimer);
        this._debounceTimer = setTimeout(() => {
          this._debounceTimer = null;
          this._tryRead(stateFile);
        }, 80);
      });
      // Swallow watcher errors (directory may vanish mid-session).
      this._watcher.on('error', () => {});
    } catch {
      // Directory may not exist yet — the plugin creates it on first write.
      // The watcher will be retried on the next start() call (e.g. after
      // workspace folder change triggers extension re-init).
    }
  }

  /**
   * Read the state file and publish it — but only when it can be confirmed
   * live. This is the fix for the stale-state defect: the file used to be
   * parsed and published unconditionally, so a `memory_state.json` written
   * days earlier by a plugin that had since been commented out of
   * `analysis_options.yaml` still drove the status bar.
   *
   * A file that fails the gate publishes `null` rather than being ignored,
   * because ignoring it would leave any previously published state on screen.
   */
  private _tryRead(filePath: string): void {
    if (!this._isLive(filePath)) {
      // Deliberately does NOT delete the stale file. It is the only record of
      // what the plugin last did and is useful when diagnosing the run that
      // wrote it; suppressing it from the UI is enough to stop it misleading.
      this._publish(null);
      return;
    }
    let parsed: MemoryPressureState;
    try {
      parsed = JSON.parse(fs.readFileSync(filePath, 'utf8')) as MemoryPressureState;
    } catch {
      // Partial write or a read race. Keep whatever was last published rather
      // than blanking the badge — the debounced watcher will re-read shortly.
      return;
    }
    this._publish(parsed);
  }

  /** Whether the file at [filePath] reflects a plugin running in this session. */
  private _isLive(filePath: string): boolean {
    const root = this._root;
    if (root === null) return false;
    let writtenAtMs: number | null = null;
    try {
      writtenAtMs = fs.statSync(filePath).mtimeMs;
    } catch {
      // File absent (plugin has never written one) — nothing to trust.
      writtenAtMs = null;
    }
    return isMemoryStateLive({
      writtenAtMs,
      sessionStartMs: this._sessionStartMs,
      pluginEnrolled: pluginEnrolledInAnalysisOptions(root),
    });
  }

  /**
   * Store [next] and notify listeners only on a significant transition.
   *
   * Now has to handle null on both sides, because the liveness gate can move
   * state to and from "nothing to report". A null-to-null read must stay
   * quiet or every unrelated write into the reports directory would re-render
   * the status bar.
   */
  private _publish(next: MemoryPressureState | null): void {
    const previous = this._state;
    this._state = next;
    if (previous === null || next === null) {
      // Appearing or disappearing is always significant; both-null is not.
      if (previous !== next) this._onStateChange?.(next);
      return;
    }
    // Notify on shed level, hard-limit, or soft-limit trip state changes.
    // softLimitTripped is needed so the "enable shedding" prompt fires
    // when shedding is off (shedLevel stays 0 in that path).
    const changed =
      previous.shedLevel !== next.shedLevel ||
      previous.hardLimitTripped !== next.hardLimitTripped ||
      previous.softLimitTripped !== next.softLimitTripped;
    if (changed) this._onStateChange?.(next);
  }

  dispose(): void {
    this._watcher?.close();
    this._watcher = null;
    // Cancel any in-flight debounce timer (fix for the debounce-timer
    // leak): without this, a timer scheduled just before dispose() still
    // fires ~80ms later and reads whatever `stateFile`/`_root` are current
    // at that point — which, if `start()` has since been called again for
    // a different folder, is the NEW root, read using the OLD closure's
    // `stateFile` path. Clearing here guarantees a disposed watcher never
    // produces a read.
    if (this._debounceTimer) {
      clearTimeout(this._debounceTimer);
      this._debounceTimer = null;
    }
    // Reset root/state so a subsequent start() on a different workspace
    // folder never carries the previous project's state forward. Before
    // this fix, restarting on a new root left `_state` holding the old
    // root's last-published pressure snapshot, so `_publish`'s
    // change-detection could compare the new root's first read against
    // stale data and suppress a legitimate first notification; `_root`
    // stayed pointed at a folder the watcher module no longer serves.
    this._state = null;
    this._root = null;
  }
}

/**
 * Produces the status-bar suffix for the current memory-pressure state,
 * or undefined when no pressure suffix is warranted.
 *
 * Priority over the process-level `systemHealthSuffix` — plugin-level
 * memory pressure is more actionable than aggregate process RSS.
 */
/**
 * l10n key map for each pressure band. Single source of truth — both the
 * status-bar suffix and the tooltip line read from this table so they
 * never disagree about which state won.
 */
interface PressureBandKeys {
  statusBar: string;
  tooltip: string;
}

/**
 * How loudly a pressure band should be presented.
 *
 * Every band used to paint the status bar error-red simply because it
 * produced a suffix, so an informational level-1 shed (a handful of
 * expensive rules stood down, analysis fully functional) looked identical
 * to "all rules paused". Red is reserved for bands the user must act on:
 * anything less alarming gets warning yellow or the default background, so
 * a red memory badge keeps meaning something.
 */
export type PressureSeverity = 'error' | 'warning' | 'info';

/** Ordered priority: hardTripped > shedLevel 3 > 2 > 1 > softNoShed. */
const PRESSURE_BANDS: readonly {
  match: (s: MemoryPressureState) => boolean;
  keys: PressureBandKeys;
  /** l10n interpolation tokens for this band. */
  params: (s: MemoryPressureState) => Record<string, string>;
  /** Presentation weight for this band — drives the status-bar background. */
  severity: PressureSeverity;
}[] = [
  {
    match: (s) => s.hardLimitTripped,
    keys: {
      statusBar: 'memoryPressure.statusBar.hardTripped',
      tooltip: 'memoryPressure.tooltip.hardTripped',
    },
    params: (s) => ({ rssMb: String(s.rssMb) }),
    severity: 'error',
  },
  {
    match: (s) => s.shedLevel >= 3,
    keys: {
      statusBar: 'memoryPressure.statusBar.shedCritical',
      tooltip: 'memoryPressure.tooltip.shedLevel3',
    },
    params: (s) => ({ count: String(s.shedRuleCount) }),
    severity: 'error',
  },
  {
    match: (s) => s.shedLevel >= 2,
    keys: {
      statusBar: 'memoryPressure.statusBar.shedWarning',
      tooltip: 'memoryPressure.tooltip.shedLevel2',
    },
    params: (s) => ({ count: String(s.shedRuleCount) }),
    severity: 'warning',
  },
  {
    match: (s) => s.shedLevel >= 1,
    keys: {
      statusBar: 'memoryPressure.statusBar.shedInfo',
      tooltip: 'memoryPressure.tooltip.shedLevel1',
    },
    params: (s) => ({ count: String(s.shedRuleCount) }),
    severity: 'info',
  },
  {
    match: (s) => s.softLimitTripped && !s.shedEnabled,
    keys: {
      statusBar: 'memoryPressure.statusBar.pressureNoShed',
      tooltip: 'memoryPressure.tooltip.pressureNoShed',
    },
    params: (s) => ({ rssMb: String(s.rssMb) }),
    severity: 'warning',
  },
];

/** Pick the first matching pressure band for the given state. */
function matchPressureBand(state: MemoryPressureState | null) {
  if (!state) return undefined;
  for (const band of PRESSURE_BANDS) {
    if (band.match(state)) {
      return { keys: band.keys, params: band.params(state), severity: band.severity };
    }
  }
  return undefined;
}

/**
 * Severity of the winning pressure band, or undefined when no band matches
 * (no pressure suffix is shown at all). Read by the status bar to choose a
 * background color; sharing the band table with the suffix and tooltip keeps
 * the color and the words from disagreeing about how bad things are.
 */
export function memoryPressureSeverity(
  state: MemoryPressureState | null,
): PressureSeverity | undefined {
  return matchPressureBand(state)?.severity;
}

export function memoryPressureSuffix(
  state: MemoryPressureState | null,
): string | undefined {
  const band = matchPressureBand(state);
  return band ? l10n(band.keys.statusBar, band.params) : undefined;
}

/**
 * Theme color id for the status-bar background of the current pressure
 * state, or undefined for "no colored background".
 *
 * Kept next to the band table (and pure, so it is testable without a VS Code
 * host) because the words and the color must come from the same decision:
 * the previous code painted error red whenever any suffix existed, which
 * made an informational shed indistinguishable from a hard memory stop.
 * Only bands the user must act on get error red. These are theme color ids,
 * never raw hex, so both light and dark themes render correctly.
 */
export function pressureBackgroundColorId(
  state: MemoryPressureState | null,
): string | undefined {
  switch (memoryPressureSeverity(state)) {
    case 'error':
      return 'statusBarItem.errorBackground';
    case 'warning':
      return 'statusBarItem.warningBackground';
    default:
      // Informational band (or no band at all) — default background.
      return undefined;
  }
}

/**
 * Produces the tooltip line for the current memory-pressure state, or
 * undefined when no line is warranted. Uses the same priority table as
 * {@link memoryPressureSuffix} so the two never disagree.
 */
export function memoryPressureTooltipLine(
  state: MemoryPressureState | null,
): string | undefined {
  const band = matchPressureBand(state);
  if (!band) return undefined;
  const base = l10n(band.keys.tooltip, band.params);
  // Append shed breakdown when details are available.
  const details = state?.shedDetails;
  if (!details || !state || state.shedLevel <= 0) return base;
  const parts: string[] = [];
  if (details.typeResolving > 0) parts.push(`${details.typeResolving} type-resolving`);
  if (details.highCost > 0) parts.push(`${details.highCost} high-cost`);
  if (details.infoSeverity > 0) parts.push(`${details.infoSeverity} INFO`);
  if (details.warningSeverity > 0) parts.push(`${details.warningSeverity} WARNING`);
  return parts.length > 0 ? `${base} (${parts.join(', ')})` : base;
}

/**
 * Shows a VS Code warning notification when memory pressure is detected but
 * rule shedding is not enabled. Prompts the user to enable `shed_rules: true`
 * in their config. Keyed per workspace root so multi-root workspaces get
 * independent prompts, each firing at most once per extension host lifetime.
 */
const _shedPromptShownForRoot = new Set<string>();

export function promptEnableShedRulesIfNeeded(
  state: MemoryPressureState | null,
): void {
  if (!state) return;
  // Only prompt when soft limit is tripped but shedding is off.
  if (!state.softLimitTripped || state.shedEnabled) return;

  // Key by workspace root so multi-root workspaces get per-project prompts.
  const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? '';
  if (_shedPromptShownForRoot.has(root)) return;
  _shedPromptShownForRoot.add(root);

  const message = l10n('memoryPressure.notification.shedDisabled', {
    rssMb: String(state.rssMb),
    softLimitMb: String(state.softLimitMb),
  });
  const enableLabel = l10n('memoryPressure.notification.enableButton');
  const learnMoreLabel = l10n('memoryPressure.notification.learnMoreButton');

  void vscode.window
    .showWarningMessage(message, enableLabel, learnMoreLabel)
    .then((choice) => {
      if (choice === enableLabel) {
        void _enableShedRulesInConfig(root);
      } else if (choice === learnMoreLabel) {
        void vscode.env.openExternal(
          vscode.Uri.parse(
            'https://pub.dev/packages/saropa_lints#memory-pressure',
          ),
        );
      }
    });
}

/**
 * Writes `shed_rules: true` into `analysis_options_custom.yaml` at [root].
 * If the line already exists (commented or not), flips it to `true`.
 * If the file doesn't exist, guides the user to run `dart run saropa_lints:init`.
 */
async function _enableShedRulesInConfig(root: string): Promise<void> {
  if (!root) return;
  const configUri = vscode.Uri.joinPath(
    vscode.Uri.file(root),
    'analysis_options_custom.yaml',
  );

  let content: string;
  try {
    const bytes = await vscode.workspace.fs.readFile(configUri);
    content = Buffer.from(bytes).toString('utf8');
  } catch {
    // File doesn't exist — guide the user to generate it.
    void vscode.window.showInformationMessage(
      l10n('memoryPressure.notification.runInit'),
    );
    return;
  }

  // Replace commented or false shed_rules line, or append if missing.
  const shedLinePattern = /^[# ]*shed_rules\s*:.*$/m;
  let updated: string;
  if (shedLinePattern.test(content)) {
    // Flip existing line (commented or false) to true.
    updated = content.replace(shedLinePattern, 'shed_rules: true');
  } else {
    // Append at end with a blank line separator.
    const separator = content.endsWith('\n') ? '' : '\n';
    updated = `${content}${separator}\nshed_rules: true\n`;
  }

  await vscode.workspace.fs.writeFile(
    configUri,
    Buffer.from(updated, 'utf8'),
  );
  void vscode.window.showInformationMessage(
    l10n('memoryPressure.notification.enabledConfirmation'),
  );
}
