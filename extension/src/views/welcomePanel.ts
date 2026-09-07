import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { buildWelcomePanelHtml } from './welcomePanel-html';
import { fetchRuleCounts } from './ruleCountCliRunner';
import { getProjectRoot } from '../projectRoot';

/**
 * globalState key persisting whether the panel should keep auto-showing on activation.
 * Defaults to true (absent key == true) so a fresh install or an upgrade always sees it,
 * and it keeps reappearing on every subsequent activation until the user explicitly
 * unchecks "Show this next time" — which the webview only allows after they have
 * scrolled through the panel once. This is intentionally stickier than a one-time
 * "seen it" flag: the engine-swap card describes a default-behavior change to the
 * diagnostic backend, and a single dismissible toast is not enough weight for that.
 */
export const SHOW_ON_ACTIVATION_KEY = 'saropaLints.welcomeShowOnNextActivation';

/** Message shapes the welcome webview can post back to the extension host. */
type WelcomeMessage =
  | { type: 'openHealthPanel' }
  | { type: 'revertToAnalyzer' }
  | { type: 'openMachineDashboard' }
  | { type: 'openThresholdSettings' }
  | { type: 'openCommandCatalog' }
  | { type: 'openWalkthrough' }
  | { type: 'openFindingsDashboard' }
  | { type: 'openPackageDashboard' }
  | { type: 'openRulesDashboard' }
  | { type: 'setShowNextTime'; value: boolean };

/**
 * "What's New" welcome panel — auto-shown on activation while SHOW_ON_ACTIVATION_KEY
 * is true (wired in extension.ts's activate()), and reopenable from the Command
 * Palette / Help Hub regardless of that flag. Singleton panel following the same
 * createOrShow pattern as HealthPanel/About.
 */
export class WelcomePanel implements vscode.Disposable {
  private static instance: WelcomePanel | undefined;

  private readonly panel: vscode.WebviewPanel;
  private readonly disposables: vscode.Disposable[] = [];
  private readonly context: vscode.ExtensionContext;
  private readonly version: string;
  // Guards the async rule-count patch-in (see constructor) landing after the user
  // already closed the tab — without this a late webview.html write would throw.
  private disposed = false;

  static createOrShow(context: vscode.ExtensionContext): void {
    if (WelcomePanel.instance) {
      WelcomePanel.instance.panel.reveal();
      return;
    }
    WelcomePanel.instance = new WelcomePanel(context);
  }

  private constructor(context: vscode.ExtensionContext) {
    this.context = context;
    this.version = (context.extension.packageJSON as { version: string }).version;

    this.panel = vscode.window.createWebviewPanel(
      'saropaWelcome',
      l10n('welcome.panel.title'),
      vscode.ViewColumn.One,
      { enableScripts: true, retainContextWhenHidden: false },
    );
    // Fast-path render with the static "2,300+" fallback immediately, then swap in
    // the live count once the CLI resolves — same rationale as showAboutPanel: a
    // cold `dart run` can take a second or two, and the panel should never block on
    // a supplementary figure. See welcomePanelStats.ts.
    this.panel.webview.html = buildWelcomePanelHtml(this.version, null);
    const projectRoot = getProjectRoot();
    if (projectRoot) {
      void fetchRuleCounts(projectRoot).then((counts) => {
        if (counts && !this.disposed) {
          this.panel.webview.html = buildWelcomePanelHtml(this.version, counts);
        }
      });
    }

    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
    this.panel.webview.onDidReceiveMessage(
      (msg: WelcomeMessage) => this.handleMessage(msg),
      null,
      this.disposables,
    );

    context.subscriptions.push(this);
  }

  private handleMessage(msg: WelcomeMessage): void {
    switch (msg.type) {
      case 'openHealthPanel':
        void vscode.commands.executeCommand('saropaLints.showProcessHealth');
        break;
      case 'revertToAnalyzer':
        void this.revertToAnalyzer();
        break;
      case 'openMachineDashboard':
        void vscode.commands.executeCommand('saropaLints.showMachineDashboard');
        break;
      case 'openThresholdSettings':
        void vscode.commands.executeCommand('workbench.action.openSettings', 'saropaLints.systemHealth');
        break;
      case 'openCommandCatalog':
        void vscode.commands.executeCommand('saropaLints.showCommandCatalog');
        break;
      case 'openWalkthrough':
        void vscode.commands.executeCommand('saropaLints.openWalkthrough');
        break;
      case 'openFindingsDashboard':
        void vscode.commands.executeCommand('saropaLints.openViolationsWideReport');
        break;
      case 'openPackageDashboard':
        void vscode.commands.executeCommand('saropaLints.openProjectVibrancyReport');
        break;
      case 'openRulesDashboard':
        void vscode.commands.executeCommand('saropaLints.openConfigDashboard');
        break;
      case 'setShowNextTime':
        // Persisted immediately on toggle, not only on close — a webview tab can be
        // closed (Ctrl+W, tab X) without a dedicated "user confirmed" event to hook.
        void this.context.globalState.update(SHOW_ON_ACTIVATION_KEY, msg.value);
        break;
    }
  }

  /**
   * Turns the LSP server off (which re-enables the analyzer plugin — see the
   * pairing logic in extension.ts). Offers an Undo toast rather than a
   * confirmation dialog: reverting a beta engine choice is cheap and
   * reversible, so a blocking modal would be friction for no safety benefit.
   */
  private async revertToAnalyzer(): Promise<void> {
    const config = vscode.workspace.getConfiguration('saropaLints.lspServer');
    await config.update('enabled', false, vscode.ConfigurationTarget.Workspace);
    const openHealthLabel = l10n('welcome.card.engine.actionHealth');
    const choice = await vscode.window.showInformationMessage(
      l10n('welcome.card.engine.revertConfirm'),
      openHealthLabel,
    );
    if (choice === openHealthLabel) {
      void vscode.commands.executeCommand('saropaLints.showProcessHealth');
    }
  }

  dispose(): void {
    this.disposed = true;
    WelcomePanel.instance = undefined;
    for (const d of this.disposables) d.dispose();
    this.disposables.length = 0;
  }
}
