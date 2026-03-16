"use strict";
/**
 * Mock implementation of the vscode API for unit testing outside VS Code.
 * Trimmed subset from saropa_drift_viewer, covering the APIs this extension uses.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.StatusBarAlignment = exports.ConfigurationTarget = exports.ProgressLocation = exports.ViewColumn = exports.RelativePattern = exports.Uri = exports.env = exports.envMock = exports.clipboardMock = exports.languages = exports.workspace = exports.commands = exports.window = exports.messageMock = exports.createdDiagnosticCollections = exports.createdTreeViews = exports.createdPanels = exports.CodeActionKind = exports.WorkspaceEdit = exports.TreeItemCollapsibleState = exports.TreeItem = exports.ThemeIcon = exports.ThemeColor = exports.Selection = exports.Range = exports.Position = exports.MockWebviewPanel = exports.MockSecretStorage = exports.MockOutputChannel = exports.MockMemento = exports.MockDiagnosticCollection = exports.MarkdownString = exports.Hover = exports.EventEmitter = exports.DiagnosticSeverity = exports.Diagnostic = exports.CodeLens = exports.CodeAction = void 0;
exports.setTestConfig = setTestConfig;
exports.clearTestConfig = clearTestConfig;
exports.resetMocks = resetMocks;
var vscode_mock_classes_1 = require("./vscode-mock-classes");
Object.defineProperty(exports, "CodeAction", { enumerable: true, get: function () { return vscode_mock_classes_1.CodeAction; } });
Object.defineProperty(exports, "CodeLens", { enumerable: true, get: function () { return vscode_mock_classes_1.CodeLens; } });
Object.defineProperty(exports, "Diagnostic", { enumerable: true, get: function () { return vscode_mock_classes_1.Diagnostic; } });
Object.defineProperty(exports, "DiagnosticSeverity", { enumerable: true, get: function () { return vscode_mock_classes_1.DiagnosticSeverity; } });
Object.defineProperty(exports, "EventEmitter", { enumerable: true, get: function () { return vscode_mock_classes_1.EventEmitter; } });
Object.defineProperty(exports, "Hover", { enumerable: true, get: function () { return vscode_mock_classes_1.Hover; } });
Object.defineProperty(exports, "MarkdownString", { enumerable: true, get: function () { return vscode_mock_classes_1.MarkdownString; } });
Object.defineProperty(exports, "MockDiagnosticCollection", { enumerable: true, get: function () { return vscode_mock_classes_1.MockDiagnosticCollection; } });
Object.defineProperty(exports, "MockMemento", { enumerable: true, get: function () { return vscode_mock_classes_1.MockMemento; } });
Object.defineProperty(exports, "MockOutputChannel", { enumerable: true, get: function () { return vscode_mock_classes_1.MockOutputChannel; } });
Object.defineProperty(exports, "MockSecretStorage", { enumerable: true, get: function () { return vscode_mock_classes_1.MockSecretStorage; } });
Object.defineProperty(exports, "MockWebviewPanel", { enumerable: true, get: function () { return vscode_mock_classes_1.MockWebviewPanel; } });
Object.defineProperty(exports, "Position", { enumerable: true, get: function () { return vscode_mock_classes_1.Position; } });
Object.defineProperty(exports, "Range", { enumerable: true, get: function () { return vscode_mock_classes_1.Range; } });
Object.defineProperty(exports, "Selection", { enumerable: true, get: function () { return vscode_mock_classes_1.Selection; } });
Object.defineProperty(exports, "ThemeColor", { enumerable: true, get: function () { return vscode_mock_classes_1.ThemeColor; } });
Object.defineProperty(exports, "ThemeIcon", { enumerable: true, get: function () { return vscode_mock_classes_1.ThemeIcon; } });
Object.defineProperty(exports, "TreeItem", { enumerable: true, get: function () { return vscode_mock_classes_1.TreeItem; } });
Object.defineProperty(exports, "TreeItemCollapsibleState", { enumerable: true, get: function () { return vscode_mock_classes_1.TreeItemCollapsibleState; } });
Object.defineProperty(exports, "WorkspaceEdit", { enumerable: true, get: function () { return vscode_mock_classes_1.WorkspaceEdit; } });
const vscode_mock_classes_2 = require("./vscode-mock-classes");
exports.CodeActionKind = {
    QuickFix: 'quickfix',
};
// --- Tracking arrays for test assertions ---
exports.createdPanels = [];
exports.createdTreeViews = [];
exports.createdDiagnosticCollections = [];
exports.messageMock = {
    infos: [],
    errors: [],
    warnings: [],
    reset() {
        this.infos.length = 0;
        this.errors.length = 0;
        this.warnings.length = 0;
    },
};
// --- Namespace mocks ---
const registeredCommands = {};
exports.window = {
    createWebviewPanel: (_viewType, _title, _column, _options) => {
        const panel = new vscode_mock_classes_2.MockWebviewPanel();
        exports.createdPanels.push(panel);
        return panel;
    },
    createTreeView: (_viewId, _options) => {
        const tv = { dispose: () => { } };
        exports.createdTreeViews.push(tv);
        return tv;
    },
    createOutputChannel: (name) => new vscode_mock_classes_2.MockOutputChannel(name),
    createStatusBarItem: (_id, _alignment, _priority) => ({
        text: '',
        name: '',
        command: '',
        tooltip: '',
        show: () => { },
        hide: () => { },
        dispose: () => { },
    }),
    withProgress: async (_options, task) => task({ report: () => { } }),
    showInformationMessage: async (msg) => {
        exports.messageMock.infos.push(msg);
    },
    showWarningMessage: async (msg) => {
        exports.messageMock.warnings.push(msg);
    },
    showErrorMessage: async (msg) => {
        exports.messageMock.errors.push(msg);
    },
    showTextDocument: async (_doc, _options) => ({}),
    onDidChangeWindowState: (_listener) => ({
        dispose: () => { },
    }),
};
exports.commands = {
    registerCommand: (id, handler) => {
        registeredCommands[id] = handler;
        return { dispose: () => { delete registeredCommands[id]; } };
    },
    executeCommand: async (id, ...args) => {
        return registeredCommands[id]?.(...args);
    },
};
const testConfigValues = {};
function setTestConfig(section, key, value) {
    testConfigValues[`${section}.${key}`] = value;
}
function clearTestConfig() {
    for (const key of Object.keys(testConfigValues)) {
        delete testConfigValues[key];
    }
}
exports.workspace = {
    getConfiguration: (section) => ({
        get: (key, defaultValue) => {
            const fullKey = section ? `${section}.${key}` : key;
            return fullKey in testConfigValues ? testConfigValues[fullKey] : defaultValue;
        },
        update: async (_key, _value, _target) => { },
    }),
    findFiles: async (_include, _exclude) => [],
    createFileSystemWatcher: (_glob) => ({
        onDidChange: () => ({ dispose: () => { } }),
        onDidCreate: () => ({ dispose: () => { } }),
        onDidDelete: () => ({ dispose: () => { } }),
        dispose: () => { },
    }),
    openTextDocument: async (_uri) => null,
    applyEdit: async () => true,
    fs: {
        readFile: async () => new Uint8Array(),
        writeFile: async () => { },
    },
    onDidSaveTextDocument: (_listener) => ({
        dispose: () => { },
    }),
    onDidOpenTextDocument: (_listener) => ({
        dispose: () => { },
    }),
    textDocuments: [],
    getWorkspaceFolder: (_uri) => null,
};
exports.languages = {
    createDiagnosticCollection: (name) => {
        const col = new vscode_mock_classes_2.MockDiagnosticCollection(name);
        exports.createdDiagnosticCollections.push(col);
        return col;
    },
    registerHoverProvider: (_selector, _provider) => {
        return { dispose: () => { } };
    },
    registerCodeActionsProvider: (_selector, _provider, _metadata) => {
        return { dispose: () => { } };
    },
    registerCodeLensProvider: (_selector, _provider) => {
        return { dispose: () => { } };
    },
};
exports.clipboardMock = {
    text: '',
    reset() { this.text = ''; },
};
exports.envMock = {
    openedUrls: [],
    reset() { this.openedUrls.length = 0; exports.clipboardMock.text = ''; },
};
exports.env = {
    clipboard: {
        writeText: async (text) => { exports.clipboardMock.text = text; },
        readText: async () => exports.clipboardMock.text,
    },
    openExternal: async (uri) => {
        exports.envMock.openedUrls.push(uri.toString());
        return true;
    },
};
exports.Uri = {
    parse: (v) => ({ toString: () => v, scheme: 'http', path: v, fsPath: v }),
    file: (p) => ({ toString: () => p, scheme: 'file', path: p, fsPath: p }),
    joinPath: (base, ...segments) => {
        const joined = [base.fsPath ?? base.path, ...segments].join('/');
        return { toString: () => joined, scheme: 'file', path: joined, fsPath: joined };
    },
};
class RelativePattern {
    base;
    pattern;
    constructor(base, pattern) {
        this.base = base;
        this.pattern = pattern;
    }
}
exports.RelativePattern = RelativePattern;
var ViewColumn;
(function (ViewColumn) {
    ViewColumn[ViewColumn["Active"] = -1] = "Active";
    ViewColumn[ViewColumn["Beside"] = -2] = "Beside";
    ViewColumn[ViewColumn["One"] = 1] = "One";
})(ViewColumn || (exports.ViewColumn = ViewColumn = {}));
var ProgressLocation;
(function (ProgressLocation) {
    ProgressLocation[ProgressLocation["Notification"] = 15] = "Notification";
})(ProgressLocation || (exports.ProgressLocation = ProgressLocation = {}));
var ConfigurationTarget;
(function (ConfigurationTarget) {
    ConfigurationTarget[ConfigurationTarget["Global"] = 1] = "Global";
    ConfigurationTarget[ConfigurationTarget["Workspace"] = 2] = "Workspace";
    ConfigurationTarget[ConfigurationTarget["WorkspaceFolder"] = 3] = "WorkspaceFolder";
})(ConfigurationTarget || (exports.ConfigurationTarget = ConfigurationTarget = {}));
var StatusBarAlignment;
(function (StatusBarAlignment) {
    StatusBarAlignment[StatusBarAlignment["Left"] = 1] = "Left";
    StatusBarAlignment[StatusBarAlignment["Right"] = 2] = "Right";
})(StatusBarAlignment || (exports.StatusBarAlignment = StatusBarAlignment = {}));
/** Reset all shared mock state between tests. */
function resetMocks() {
    exports.createdPanels.length = 0;
    exports.createdTreeViews.length = 0;
    exports.createdDiagnosticCollections.length = 0;
    exports.messageMock.reset();
    exports.envMock.reset();
    for (const key of Object.keys(registeredCommands)) {
        delete registeredCommands[key];
    }
}
//# sourceMappingURL=vscode-mock.js.map