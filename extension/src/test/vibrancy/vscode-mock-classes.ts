/**
 * Mock classes for the vscode API — used by vscode-mock.ts.
 */

export class EventEmitter {
    private _listeners: Array<(...args: any[]) => void> = [];
    event = (listener: (...args: any[]) => void) => {
        this._listeners.push(listener);
        return { dispose: () => { /* no-op */ } };
    };
    fire(...args: any[]) {
        this._listeners.forEach((l) => l(...args));
    }
    dispose() {
        this._listeners.length = 0;
    }
}

export class MockOutputChannel {
    readonly lines: string[] = [];
    constructor(public readonly name: string = 'test') {}
    appendLine(line: string): void { this.lines.push(line); }
    append(): void { /* no-op */ } clear(): void { /* no-op */ }
    show(): void { /* no-op */ } hide(): void { /* no-op */ }
    replace(): void { /* no-op */ } dispose(): void { /* no-op */ }
}

export enum TreeItemCollapsibleState {
    None = 0,
    Collapsed = 1,
    Expanded = 2,
}

export class ThemeIcon {
    constructor(
        public readonly id: string,
        public readonly color?: ThemeColor,
    ) {}
}

export class ThemeColor {
    constructor(public readonly id: string) {}
}

export class MarkdownString {
    value: string;
    isTrusted?: boolean;
    constructor(value = '') {
        this.value = value;
    }
    appendMarkdown(value: string): this {
        this.value += value;
        return this;
    }
    appendText(value: string): this {
        this.value += value;
        return this;
    }
}

export class Hover {
    contents: MarkdownString | MarkdownString[];
    range?: Range;
    constructor(contents: MarkdownString | MarkdownString[], range?: Range) {
        this.contents = contents;
        this.range = range;
    }
}

export class Position {
    constructor(
        public readonly line: number,
        public readonly character: number,
    ) {}
}

export class Range {
    readonly start: Position;
    readonly end: Position;
    constructor(
        startLine: number,
        startCharacter: number,
        endLine: number,
        endCharacter: number,
    ) {
        this.start = new Position(startLine, startCharacter);
        this.end = new Position(endLine, endCharacter);
    }
}

export enum DiagnosticSeverity {
    Error = 0,
    Warning = 1,
    Information = 2,
    Hint = 3,
}

export class Diagnostic {
    range: Range;
    message: string;
    severity: DiagnosticSeverity;
    source?: string;
    code?: string | number;

    constructor(
        range: Range,
        message: string,
        severity: DiagnosticSeverity = DiagnosticSeverity.Error,
    ) {
        this.range = range;
        this.message = message;
        this.severity = severity;
    }
}

export class MockDiagnosticCollection {
    readonly name: string;
    private _entries = new Map<string, Diagnostic[]>();

    constructor(name: string) { this.name = name; }

    set(uri: any, diagnostics: Diagnostic[]): void {
        this._entries.set(uri.toString(), diagnostics);
    }

    clear(): void { this._entries.clear(); }

    get(uri: any): Diagnostic[] | undefined {
        return this._entries.get(uri.toString());
    }

    entries(): Map<string, Diagnostic[]> {
        return new Map(this._entries);
    }

    dispose(): void { this._entries.clear(); }
}

export class CodeLens {
    range: Range;
    command?: { title: string; command: string; arguments?: any[] };
    constructor(range: Range, command?: CodeLens['command']) {
        this.range = range;
        this.command = command;
    }
    get isResolved(): boolean { return this.command !== undefined; }
}

export class CodeAction {
    title: string;
    kind?: string;
    diagnostics?: Diagnostic[];
    edit?: any;

    constructor(title: string, kind?: string) {
        this.title = title;
        this.kind = kind;
    }
}

export class TreeItem {
    label?: string;
    description?: string;
    tooltip?: string | MarkdownString;
    iconPath?: ThemeIcon | { light: string; dark: string };
    collapsibleState?: TreeItemCollapsibleState;
    contextValue?: string;
    command?: any;

    constructor(
        label: string,
        collapsibleState: TreeItemCollapsibleState = TreeItemCollapsibleState.None,
    ) {
        this.label = label;
        this.collapsibleState = collapsibleState;
    }
}

export class MockWebviewPanel {
    webview = { html: '', postMessage: async () => true };
    private _onDidDispose = new EventEmitter();
    revealed = false;

    onDidDispose(listener: () => void) {
        return this._onDidDispose.event(listener);
    }

    reveal() { this.revealed = true; }
    dispose() { this._onDidDispose.fire(); }
}

export class MockMemento {
    private _data = new Map<string, unknown>();

    get<T>(key: string, defaultValue?: T): T | undefined {
        return this._data.has(key)
            ? (this._data.get(key) as T)
            : defaultValue;
    }

    async update(key: string, value: unknown): Promise<void> {
        if (value === undefined) {
            this._data.delete(key);
        } else {
            this._data.set(key, value);
        }
    }

    keys(): readonly string[] {
        return [...this._data.keys()];
    }
}

export class Selection {
    readonly start: Position;
    readonly end: Position;
    constructor(anchor: Position, active: Position) {
        this.start = anchor;
        this.end = active;
    }
}

export class WorkspaceEdit {
    private _edits: any[] = [];
    replace(uri: any, range: any, newText: string): void {
        this._edits.push({ uri, range, newText });
    }
    delete(uri: any, range: any): void {
        this._edits.push({ uri, range, newText: '' });
    }
    getEdits(): any[] { return this._edits; }
}

export class MockSecretStorage {
    private _data = new Map<string, string>();
    private _changeEmitter = new EventEmitter();

    get onDidChange() { return this._changeEmitter.event; }

    async get(key: string): Promise<string | undefined> {
        return this._data.get(key);
    }

    async store(key: string, value: string): Promise<void> {
        this._data.set(key, value);
        this._changeEmitter.fire({ key });
    }

    async delete(key: string): Promise<void> {
        this._data.delete(key);
        this._changeEmitter.fire({ key });
    }

    keys(): readonly string[] {
        return [...this._data.keys()];
    }

    clear(): void {
        this._data.clear();
    }
}
