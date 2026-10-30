/**
 * Text of the single status bar item (pure, unit-testable): switch label plus
 * whichever score parts exist, e.g. `Saropa Lints: On · 90% ▲2 · V9/10`;
 * just the label when none.
 */
export function buildUnifiedStatusText(switchLabel: string, scoreParts: Array<string | undefined>): string {
  return [switchLabel, ...scoreParts.filter((p): p is string => !!p)].join(' · ');
}

/** The three switch states the status bar distinguishes. */
export type StatusBarSwitchKind = 'on' | 'off' | 'partial';

/** One row of the main status bar's action menu (tooltip links and QuickPick rows). */
export interface StatusBarMenuItem {
  /** Codicon reference, e.g. `$(check)`. */
  readonly icon: string;
  /** l10n key for the row's label — resolve with `l10n()` before rendering. */
  readonly labelKey: string;
  /** Command id the row executes. Must appear in {@link STATUS_BAR_TRUSTED_COMMANDS}. */
  readonly commandId: string;
  /** Tooltip grouping: toggle first, then reports, then utility links. */
  readonly group: 'toggle' | 'report' | 'utility';
}

/**
 * Command ids the main status bar's MarkdownString tooltip is allowed to
 * link to. VS Code refuses to execute a `command:` link unless the id is
 * explicitly allow-listed via `isTrusted.enabledCommands`.
 *
 * Single source of truth shared with {@link buildStatusBarMenuItems} and the
 * tooltip problem links — a unit test asserts every `command:` id the tooltip
 * emits is covered, catching drift if a row is added/renamed without updating
 * this list (or vice versa).
 */
export const STATUS_BAR_TRUSTED_COMMANDS: readonly string[] = [
  'saropaLints.toggleLints',
  'saropaLints.openViolationsWideReport',
  'saropaLints.openProjectVibrancyReport',
  'saropaLints.showProcessHealth',
  'saropaLints.showCommandCatalog',
  'saropaLints.configureCompatibility',
  'saropaLints.showWorkspaceReadiness',
  'saropaLints.showAbout',
];

/**
 * Rows for the status bar action menu, in render order. The first row is the
 * switch toggle; its label follows the real state (never "enabled" while
 * partly off). `toggleLints` turns everything off from On and everything on
 * from Off or Partly off.
 */
export function buildStatusBarMenuItems(kind: StatusBarSwitchKind): readonly StatusBarMenuItem[] {
  const toggle: StatusBarMenuItem =
    kind === 'on'
      ? { icon: '$(circle-slash)', labelKey: 'statusBar.tooltip.action.turnOff', commandId: 'saropaLints.toggleLints', group: 'toggle' }
      : kind === 'off'
        ? { icon: '$(play)', labelKey: 'statusBar.tooltip.action.turnOn', commandId: 'saropaLints.toggleLints', group: 'toggle' }
        : { icon: '$(play)', labelKey: 'statusBar.tooltip.action.turnBothOn', commandId: 'saropaLints.toggleLints', group: 'toggle' };
  return [
    toggle,
    { icon: '$(checklist)', labelKey: 'statusBar.menu.openViolations', commandId: 'saropaLints.openViolationsWideReport', group: 'report' },
    { icon: '$(package)', labelKey: 'statusBar.menu.openPackageDashboard', commandId: 'saropaLints.openProjectVibrancyReport', group: 'report' },
    { icon: '$(pulse)', labelKey: 'statusBar.menu.openProcessHealth', commandId: 'saropaLints.showProcessHealth', group: 'report' },
    { icon: '$(list-unordered)', labelKey: 'statusBar.menu.commandCatalog', commandId: 'saropaLints.showCommandCatalog', group: 'utility' },
    { icon: '$(versions)', labelKey: 'statusBar.tooltip.action.versionCompat', commandId: 'saropaLints.configureCompatibility', group: 'utility' },
    { icon: '$(info)', labelKey: 'statusBar.menu.about', commandId: 'saropaLints.showAbout', group: 'utility' },
  ];
}
