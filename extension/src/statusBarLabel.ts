/**
 * Text of the single status bar item (pure, unit-testable): switch label plus
 * whichever score parts exist, e.g. `Saropa Lints: On · 90% ▲2 · V9/10`;
 * just the label when none.
 */
export function buildUnifiedStatusText(switchLabel: string, scoreParts: Array<string | undefined>): string {
  return [switchLabel, ...scoreParts.filter((p): p is string => !!p)].join(' · ');
}

/** One row of the main status bar's action-menu tooltip. */
export interface StatusBarMenuItem {
  /** Codicon reference, e.g. `$(check)`. */
  readonly icon: string;
  /** l10n key for the row's label — resolve with `l10n()` before rendering. */
  readonly labelKey: string;
  /** Command id the row's markdown link executes. Must appear in {@link STATUS_BAR_TRUSTED_COMMANDS}. */
  readonly commandId: string;
}

/**
 * Command ids the main status bar's MarkdownString tooltip is allowed to
 * link to. VS Code refuses to execute a `command:` link unless the id is
 * explicitly allow-listed via `isTrusted.enabledCommands`.
 *
 * Single source of truth shared with {@link buildStatusBarMenuItems} — pulled
 * out into its own module-level export (rather than duplicated inline in
 * extension.ts) so a unit test can assert every menu item's commandId is
 * covered, catching drift if a row is added/renamed without updating this
 * list (or vice versa).
 */
export const STATUS_BAR_TRUSTED_COMMANDS: readonly string[] = [
  'saropaLints.enable',
  'saropaLints.disable',
  'saropaLints.openViolationsWideReport',
  'saropaLints.openProjectVibrancyReport',
  'saropaLints.showProcessHealth',
  'saropaLints.showCommandCatalog',
  'saropaLints.showAbout',
];

/**
 * Rows for the status bar tooltip's action menu, in render order. The first
 * row is a checkbox-style toggle: filled check when analysis is on (links to
 * `disable`), empty circle when off (links to `enable`) — there is no single
 * toggle command to link to instead.
 */
export function buildStatusBarMenuItems(enabled: boolean): readonly StatusBarMenuItem[] {
  return [
    enabled
      ? { icon: '$(check)', labelKey: 'statusBar.menu.enableOn', commandId: 'saropaLints.disable' }
      : { icon: '$(circle-outline)', labelKey: 'statusBar.menu.enableOff', commandId: 'saropaLints.enable' },
    { icon: '$(checklist)', labelKey: 'statusBar.menu.openViolations', commandId: 'saropaLints.openViolationsWideReport' },
    { icon: '$(package)', labelKey: 'statusBar.menu.openPackageDashboard', commandId: 'saropaLints.openProjectVibrancyReport' },
    { icon: '$(pulse)', labelKey: 'statusBar.menu.openProcessHealth', commandId: 'saropaLints.showProcessHealth' },
    { icon: '$(list-unordered)', labelKey: 'statusBar.menu.commandCatalog', commandId: 'saropaLints.showCommandCatalog' },
    { icon: '$(info)', labelKey: 'statusBar.menu.about', commandId: 'saropaLints.showAbout' },
  ];
}
