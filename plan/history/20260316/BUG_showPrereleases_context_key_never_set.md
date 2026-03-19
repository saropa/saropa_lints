# Bug: `showPrereleases` when-clause context key never set via setContext

**Status:** Fixed
**Component:** VS Code extension — Package Vibrancy prerelease toggle
**Severity:** Medium — show/hide prerelease menu buttons may not toggle correctly
**Origin:** Pre-existing in saropa-package-vibrancy (carried over during merge)

## Problem

The `package.json` menus use `when` clauses that reference `saropaLints.packageVibrancy.showPrereleases` as a **context key**:

```json
{
  "command": "saropaLints.packageVibrancy.showPrereleases",
  "when": "!saropaLints.packageVibrancy.showPrereleases"
},
{
  "command": "saropaLints.packageVibrancy.hidePrereleases",
  "when": "saropaLints.packageVibrancy.showPrereleases"
}
```

However, the `PrereleaseToggle` class (`extension/src/vibrancy/ui/prerelease-toggle.ts`) only stores the toggle state in **workspace configuration** via `vscode.workspace.getConfiguration()`. It never calls `vscode.commands.executeCommand('setContext', ...)` to set the context key that the `when` clauses evaluate.

In VS Code, `when` clauses evaluate **context keys** (set via `setContext`), not configuration values. To read a configuration value in a `when` clause, the `config.` prefix is required (e.g. `config.saropaLints.packageVibrancy.showPrereleases`).

This means both menu items may be visible (or both hidden) regardless of the actual toggle state, since the context key is never set.

## Relevant code

**PrereleaseToggle (ui/prerelease-toggle.ts):**

```typescript
private saveToConfig(enabled: boolean): void {
    const config = vscode.workspace.getConfiguration(CONFIG_SECTION);
    config.update(
        SHOW_PRERELEASES_KEY, enabled,
        vscode.ConfigurationTarget.Global,
    );
    // BUG: No setContext call here
}
```

**package.json when clauses (lines 854, 858):**

```json
"when": "!saropaLints.packageVibrancy.showPrereleases"
"when": "saropaLints.packageVibrancy.showPrereleases"
```

## Fix options

### Option A: Add setContext calls (recommended)

Add `setContext` calls in `PrereleaseToggle.show()` and `PrereleaseToggle.hide()`:

```typescript
show(): void {
    if (this._enabled) { return; }
    this._enabled = true;
    this.saveToConfig(true);
    void vscode.commands.executeCommand(
        'setContext',
        'saropaLints.packageVibrancy.showPrereleases',
        true,
    );
    this._onDidChange.fire(true);
}

hide(): void {
    if (!this._enabled) { return; }
    this._enabled = false;
    this.saveToConfig(false);
    void vscode.commands.executeCommand(
        'setContext',
        'saropaLints.packageVibrancy.showPrereleases',
        false,
    );
    this._onDidChange.fire(false);
}
```

Also set the initial context key in the constructor or during activation:

```typescript
constructor() {
    this._enabled = this.readFromConfig();
    void vscode.commands.executeCommand(
        'setContext',
        'saropaLints.packageVibrancy.showPrereleases',
        this._enabled,
    );
}
```

### Option B: Use config prefix in when clauses

Change the `when` clauses to read from configuration directly:

```json
"when": "!config.saropaLints.packageVibrancy.showPrereleases"
"when": "config.saropaLints.packageVibrancy.showPrereleases"
```

This avoids needing `setContext` calls but relies on VS Code's config-based when-clause evaluation.

## Impact

The show/hide prerelease toggle buttons in the Package Vibrancy view title bar may both appear simultaneously or neither appear, depending on VS Code's default for an unset context key. Users can still toggle prereleases via the command palette, but the visual toggle buttons won't reflect the current state.
