/**
 * Mock implementation of the vscode API for unit testing outside VS Code.
 * Trimmed subset from saropa_drift_viewer, covering the APIs this extension uses.
 *
 * Quick-pick tests drive `window.showQuickPick` via `setQuickPickNextResult`. The
 * exported `quickPickNextResult` is a const `{ value }` object so we avoid
 * `export let` while still resetting state in `resetMocks()`.
 *
 * Information notifications: push button labels (or `undefined` for dismiss) onto
 * `informationMessageMockQueue`; each `showInformationMessage` call `shift`s one
 * return value. `showInputBox` uses `inputBoxMockQueue` the same way.
 */

export {
    CodeAction,
    CodeLens,
    Diagnostic,
    DiagnosticSeverity,
    EventEmitter,
    Hover,
    MarkdownString,
    MockDiagnosticCollection,
    MockMemento,
    MockOutputChannel,
    MockSecretStorage,
    MockWebviewPanel,
    Position,
    Range,
    Selection,
    ThemeColor,
    ThemeIcon,
    TreeItem,
    TreeItemCollapsibleState,
    WorkspaceEdit,
} from './vscode-mock-classes';

import {
    MockDiagnosticCollection,
    MockOutputChannel,
    MockWebviewPanel,
} from './vscode-mock-classes';

export const CodeActionKind = {
    QuickFix: 'quickfix' as const,
};

// --- Tracking arrays for test assertions ---

export const createdPanels: MockWebviewPanel[] = [];
export const createdTreeViews: any[] = [];
export const createdDiagnosticCollections: MockDiagnosticCollection[] = [];
export const messageMock = {
    infos: [] as string[],
    errors: [] as string[],
    warnings: [] as string[],
    reset() {
        this.infos.length = 0;
        this.errors.length = 0;
        this.warnings.length = 0;
    },
};

// --- Namespace mocks ---

const registeredCommands: Record<string, (...args: any[]) => any> = {};

/** Test hook: next `window.showQuickPick` resolution (undefined = user dismissed). */
export const quickPickNextResult: { value: unknown } = { value: undefined };

export function setQuickPickNextResult(value: unknown): void {
    quickPickNextResult.value = value;
}

/** Return values for successive `window.showInformationMessage` calls (FIFO). */
export const informationMessageMockQueue: Array<string | undefined> = [];

/** Return values for successive `window.showInputBox` calls (FIFO). */
export const inputBoxMockQueue: Array<string | undefined> = [];

/** Workspace folders for `getWorkspaceRoot` / `getProjectRoot` tests (empty/undefined = none). */
export const mockWorkspaceFolders: { value: Array<{ uri: { fsPath: string } }> | undefined } = {
    value: undefined,
};

export const window = {
    createWebviewPanel: (
        _viewType: string,
        _title: string,
        _column: any,
        _options?: any,
    ): MockWebviewPanel => {
        const panel = new MockWebviewPanel();
        createdPanels.push(panel);
        return panel;
    },
    createTreeView: (_viewId: string, _options: any) => {
        const tv = { dispose: () => { /* no-op */ } };
        createdTreeViews.push(tv);
        return tv;
    },
    createOutputChannel: (name: string) => new MockOutputChannel(name),
    createStatusBarItem: (_id?: any, _alignment?: any, _priority?: number) => ({
        text: '',
        name: '',
        command: '',
        tooltip: '',
        show: () => { /* no-op */ },
        hide: () => { /* no-op */ },
        dispose: () => { /* no-op */ },
    }),
    // A never-cancelled token is passed as the second argument because the real
    // API always supplies one for `cancellable: true` flows; without it, code
    // under test that reads `token.isCancellationRequested` throws only in tests.
    withProgress: async (_options: any, task: (progress: any, token: any) => Promise<any>) =>
        task(
            { report: () => { /* no-op */ } },
            { isCancellationRequested: false, onCancellationRequested: () => ({ dispose: () => { /* no-op */ } }) },
        ),
    showInformationMessage: async (msg: string, ..._rest: unknown[]) => {
        messageMock.infos.push(msg);
        if (informationMessageMockQueue.length > 0) {
            return informationMessageMockQueue.shift() as string | undefined;
        }
        return undefined;
    },
    showInputBox: async (_options?: unknown) => {
        if (inputBoxMockQueue.length > 0) {
            return inputBoxMockQueue.shift() as string | undefined;
        }
        return undefined;
    },
    showWarningMessage: async (msg: string) => {
        messageMock.warnings.push(msg);
    },
    showErrorMessage: async (msg: string) => {
        messageMock.errors.push(msg);
    },
    showTextDocument: async (_doc: any, _options?: any) => ({}),
    showQuickPick: async <T extends { label: string }>(_items: readonly T[]) =>
        quickPickNextResult.value as T | undefined,
    onDidChangeWindowState: (_listener: (state: { focused: boolean }) => void) => ({
        dispose: () => { /* no-op */ },
    }),
};

export const commands = {
    registerCommand: (id: string, handler: (...args: any[]) => any) => {
        registeredCommands[id] = handler;
        return { dispose: () => { delete registeredCommands[id]; } };
    },
    executeCommand: async (id: string, ...args: any[]) => {
        return registeredCommands[id]?.(...args);
    },
};

const testConfigValues: Record<string, any> = {};

export function setTestConfig(section: string, key: string, value: any): void {
    testConfigValues[`${section}.${key}`] = value;
}

export function clearTestConfig(): void {
    for (const key of Object.keys(testConfigValues)) {
        delete testConfigValues[key];
    }
}

export const workspace: Record<string, any> = {
    get workspaceFolders() {
        const v = mockWorkspaceFolders.value;
        if (!v || v.length === 0) return undefined;
        return v;
    },
    getConfiguration: (section?: string) => ({
        get: <T>(key: string, defaultValue?: T): T | undefined => {
            const fullKey = section ? `${section}.${key}` : key;
            return fullKey in testConfigValues ? testConfigValues[fullKey] : defaultValue;
        },
        update: async (_key: string, _value: any, _target?: any): Promise<void> => {},
    }),
    findFiles: async (_include: any, _exclude?: any): Promise<any[]> => [],
    createFileSystemWatcher: (_glob: string) => ({
        onDidChange: () => ({ dispose: () => { /* no-op */ } }),
        onDidCreate: () => ({ dispose: () => { /* no-op */ } }),
        onDidDelete: () => ({ dispose: () => { /* no-op */ } }),
        dispose: () => { /* no-op */ },
    }),
    openTextDocument: async (_uri: any) => null,
    applyEdit: async () => true,
    fs: {
        readFile: async () => new Uint8Array(),
        writeFile: async () => { /* no-op */ },
        createDirectory: async () => { /* no-op */ },
    },
    onDidSaveTextDocument: (_listener: (doc: any) => void) => ({
        dispose: () => { /* no-op */ },
    }),
    onDidOpenTextDocument: (_listener: (doc: any) => void) => ({
        dispose: () => { /* no-op */ },
    }),
    textDocuments: [] as any[],
    getWorkspaceFolder: (_uri: any) => null,
};

export const languages = {
    createDiagnosticCollection: (name: string): MockDiagnosticCollection => {
        const col = new MockDiagnosticCollection(name);
        createdDiagnosticCollections.push(col);
        return col;
    },
    // Sidebar/dashboard code now reads live diagnostics via this call by default
    // (liveDiagnosticsModel.ts). Tests that don't care about diagnostic content
    // just need the no-arg overload to return an empty tuple array rather than
    // throwing "not a function".
    getDiagnostics: (_uri?: any): any => [],
    registerHoverProvider: (_selector: any, _provider: any) => {
        return { dispose: () => { /* no-op */ } };
    },
    registerCodeActionsProvider: (_selector: any, _provider: any, _metadata?: any) => {
        return { dispose: () => { /* no-op */ } };
    },
    registerCodeLensProvider: (_selector: any, _provider: any) => {
        return { dispose: () => { /* no-op */ } };
    },
};

export const clipboardMock = {
    text: '',
    reset() { this.text = ''; },
};

export const envMock = {
    openedUrls: [] as string[],
    reset() { this.openedUrls.length = 0; clipboardMock.text = ''; },
};

export const env = {
    clipboard: {
        writeText: async (text: string) => { clipboardMock.text = text; },
        readText: async () => clipboardMock.text,
    },
    openExternal: async (uri: any) => {
        envMock.openedUrls.push(uri.toString());
        return true;
    },
};

export const Uri = {
    parse: (v: string) => ({ toString: () => v, scheme: 'http', path: v, fsPath: v }),
    file: (p: string) => ({ toString: () => p, scheme: 'file', path: p, fsPath: p }),
    joinPath: (base: any, ...segments: string[]) => {
        const joined = [base.fsPath ?? base.path, ...segments].join('/');
        return { toString: () => joined, scheme: 'file', path: joined, fsPath: joined };
    },
};

export class RelativePattern {
    constructor(
        public readonly base: any,
        public readonly pattern: string,
    ) {}
}

export enum ViewColumn {
    Active = -1,
    Beside = -2,
    One = 1,
}

export enum TextEditorRevealType {
    Default = 0,
    InCenter = 1,
    InCenterIfOutsideViewport = 2,
    AtTop = 3,
}

export enum ProgressLocation {
    Notification = 15,
}

export enum ConfigurationTarget {
    Global = 1,
    Workspace = 2,
    WorkspaceFolder = 3,
}

export enum StatusBarAlignment {
    Left = 1,
    Right = 2,
}

/**
 * `vscode.extensions.getExtension` stub. `settingsCatalog.ts`'s schema-driven Automation/Extension
 * tab (Phase 4) reads THIS extension's own `contributes.configuration` off the real manifest at
 * render time — the mock had no `extensions` export at all before Phase 7's UX-harness work added
 * static rendering for the Rules & Tiers dashboard, so any caller of `buildSettingsCatalog()`
 * (previously untested outside a live VS Code host) threw `Cannot read properties of undefined`.
 * Reads the actual `extension/package.json` for the one real id this extension ever queries, so a
 * static render sees genuine settings instead of an empty catalog; any other id (a bug, or a future
 * caller checking a different extension) returns undefined like the real API would pre-activation.
 */
export const extensions = {
    getExtension: (id: string): { packageJSON: Record<string, unknown> } | undefined => {
        if (id !== 'saropa.saropa-lints') return undefined;
        try {
            // eslint-disable-next-line @typescript-eslint/no-var-requires -- runtime-relative load, not a static import cycle.
            const pkg = require('../../../package.json');
            return { packageJSON: pkg };
        } catch {
            return undefined;
        }
    },
};

/** Reset all shared mock state between tests. */
export function resetMocks(): void {
    createdPanels.length = 0;
    createdTreeViews.length = 0;
    createdDiagnosticCollections.length = 0;
    messageMock.reset();
    envMock.reset();
    quickPickNextResult.value = undefined;
    informationMessageMockQueue.length = 0;
    inputBoxMockQueue.length = 0;
    mockWorkspaceFolders.value = undefined;
    for (const key of Object.keys(registeredCommands)) {
        delete registeredCommands[key];
    }
}
