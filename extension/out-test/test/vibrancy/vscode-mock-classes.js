"use strict";
/**
 * Mock classes for the vscode API — used by vscode-mock.ts.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.MockSecretStorage = exports.WorkspaceEdit = exports.Selection = exports.MockMemento = exports.MockWebviewPanel = exports.TreeItem = exports.CodeAction = exports.CodeLens = exports.MockDiagnosticCollection = exports.Diagnostic = exports.DiagnosticSeverity = exports.Range = exports.Position = exports.Hover = exports.MarkdownString = exports.ThemeColor = exports.ThemeIcon = exports.TreeItemCollapsibleState = exports.MockOutputChannel = exports.EventEmitter = void 0;
class EventEmitter {
    _listeners = [];
    event = (listener) => {
        this._listeners.push(listener);
        return { dispose: () => { } };
    };
    fire(...args) {
        this._listeners.forEach((l) => l(...args));
    }
    dispose() {
        this._listeners.length = 0;
    }
}
exports.EventEmitter = EventEmitter;
class MockOutputChannel {
    name;
    lines = [];
    constructor(name = 'test') {
        this.name = name;
    }
    appendLine(line) { this.lines.push(line); }
    append() { }
    clear() { }
    show() { }
    hide() { }
    replace() { }
    dispose() { }
}
exports.MockOutputChannel = MockOutputChannel;
var TreeItemCollapsibleState;
(function (TreeItemCollapsibleState) {
    TreeItemCollapsibleState[TreeItemCollapsibleState["None"] = 0] = "None";
    TreeItemCollapsibleState[TreeItemCollapsibleState["Collapsed"] = 1] = "Collapsed";
    TreeItemCollapsibleState[TreeItemCollapsibleState["Expanded"] = 2] = "Expanded";
})(TreeItemCollapsibleState || (exports.TreeItemCollapsibleState = TreeItemCollapsibleState = {}));
class ThemeIcon {
    id;
    color;
    constructor(id, color) {
        this.id = id;
        this.color = color;
    }
}
exports.ThemeIcon = ThemeIcon;
class ThemeColor {
    id;
    constructor(id) {
        this.id = id;
    }
}
exports.ThemeColor = ThemeColor;
class MarkdownString {
    value;
    isTrusted;
    constructor(value = '') {
        this.value = value;
    }
    appendMarkdown(value) {
        this.value += value;
        return this;
    }
    appendText(value) {
        this.value += value;
        return this;
    }
}
exports.MarkdownString = MarkdownString;
class Hover {
    contents;
    range;
    constructor(contents, range) {
        this.contents = contents;
        this.range = range;
    }
}
exports.Hover = Hover;
class Position {
    line;
    character;
    constructor(line, character) {
        this.line = line;
        this.character = character;
    }
}
exports.Position = Position;
class Range {
    start;
    end;
    constructor(startLine, startCharacter, endLine, endCharacter) {
        this.start = new Position(startLine, startCharacter);
        this.end = new Position(endLine, endCharacter);
    }
}
exports.Range = Range;
var DiagnosticSeverity;
(function (DiagnosticSeverity) {
    DiagnosticSeverity[DiagnosticSeverity["Error"] = 0] = "Error";
    DiagnosticSeverity[DiagnosticSeverity["Warning"] = 1] = "Warning";
    DiagnosticSeverity[DiagnosticSeverity["Information"] = 2] = "Information";
    DiagnosticSeverity[DiagnosticSeverity["Hint"] = 3] = "Hint";
})(DiagnosticSeverity || (exports.DiagnosticSeverity = DiagnosticSeverity = {}));
class Diagnostic {
    range;
    message;
    severity;
    source;
    code;
    constructor(range, message, severity = DiagnosticSeverity.Error) {
        this.range = range;
        this.message = message;
        this.severity = severity;
    }
}
exports.Diagnostic = Diagnostic;
class MockDiagnosticCollection {
    name;
    _entries = new Map();
    constructor(name) { this.name = name; }
    set(uri, diagnostics) {
        this._entries.set(uri.toString(), diagnostics);
    }
    clear() { this._entries.clear(); }
    get(uri) {
        return this._entries.get(uri.toString());
    }
    entries() {
        return new Map(this._entries);
    }
    dispose() { this._entries.clear(); }
}
exports.MockDiagnosticCollection = MockDiagnosticCollection;
class CodeLens {
    range;
    command;
    constructor(range, command) {
        this.range = range;
        this.command = command;
    }
    get isResolved() { return this.command !== undefined; }
}
exports.CodeLens = CodeLens;
class CodeAction {
    title;
    kind;
    diagnostics;
    edit;
    constructor(title, kind) {
        this.title = title;
        this.kind = kind;
    }
}
exports.CodeAction = CodeAction;
class TreeItem {
    label;
    description;
    tooltip;
    iconPath;
    collapsibleState;
    contextValue;
    command;
    constructor(label, collapsibleState = TreeItemCollapsibleState.None) {
        this.label = label;
        this.collapsibleState = collapsibleState;
    }
}
exports.TreeItem = TreeItem;
class MockWebviewPanel {
    webview = { html: '', postMessage: async () => true };
    _onDidDispose = new EventEmitter();
    revealed = false;
    onDidDispose(listener) {
        return this._onDidDispose.event(listener);
    }
    reveal() { this.revealed = true; }
    dispose() { this._onDidDispose.fire(); }
}
exports.MockWebviewPanel = MockWebviewPanel;
class MockMemento {
    _data = new Map();
    get(key, defaultValue) {
        return this._data.has(key)
            ? this._data.get(key)
            : defaultValue;
    }
    async update(key, value) {
        if (value === undefined) {
            this._data.delete(key);
        }
        else {
            this._data.set(key, value);
        }
    }
    keys() {
        return [...this._data.keys()];
    }
}
exports.MockMemento = MockMemento;
class Selection {
    start;
    end;
    constructor(anchor, active) {
        this.start = anchor;
        this.end = active;
    }
}
exports.Selection = Selection;
class WorkspaceEdit {
    _edits = [];
    replace(uri, range, newText) {
        this._edits.push({ uri, range, newText });
    }
    delete(uri, range) {
        this._edits.push({ uri, range, newText: '' });
    }
    getEdits() { return this._edits; }
}
exports.WorkspaceEdit = WorkspaceEdit;
class MockSecretStorage {
    _data = new Map();
    _changeEmitter = new EventEmitter();
    get onDidChange() { return this._changeEmitter.event; }
    async get(key) {
        return this._data.get(key);
    }
    async store(key, value) {
        this._data.set(key, value);
        this._changeEmitter.fire({ key });
    }
    async delete(key) {
        this._data.delete(key);
        this._changeEmitter.fire({ key });
    }
    keys() {
        return [...this._data.keys()];
    }
    clear() {
        this._data.clear();
    }
}
exports.MockSecretStorage = MockSecretStorage;
//# sourceMappingURL=vscode-mock-classes.js.map