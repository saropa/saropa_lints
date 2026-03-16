/**
 * Mock implementation of the vscode API for unit testing outside VS Code.
 * Trimmed subset from saropa_drift_viewer, covering the APIs this extension uses.
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
    withProgress: async (_options: any, task: (progress: any) => Promise<any>) =>
        task({ report: () => { /* no-op */ } }),
    showInformationMessage: async (msg: string) => {
        messageMock.infos.push(msg);
    },
    showWarningMessage: async (msg: string) => {
        messageMock.warnings.push(msg);
    },
    showErrorMessage: async (msg: string) => {
        messageMock.errors.push(msg);
    },
    showTextDocument: async (_doc: any, _options?: any) => ({}),
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

/** Reset all shared mock state between tests. */
export function resetMocks(): void {
    createdPanels.length = 0;
    createdTreeViews.length = 0;
    createdDiagnosticCollections.length = 0;
    messageMock.reset();
    envMock.reset();
    for (const key of Object.keys(registeredCommands)) {
        delete registeredCommands[key];
    }
}
