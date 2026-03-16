# Bug: `focusIssuesForOwasp` command not declared in package.json

**Status:** Fixed
**Component:** VS Code extension — package.json manifest
**Severity:** Medium — command works but VS Code cannot display it in command palette or validate it
**Origin:** Pre-existing in saropa_lints (predates vibrancy merge)

## Problem

The command `saropaLints.focusIssuesForOwasp` is registered programmatically in `extension.ts` but is **not declared** in the `contributes.commands` section of `extension/package.json`.

VS Code requires commands to be declared in `contributes.commands` for them to appear in the Command Palette, receive titles/icons, and be validated by the extension host. Without a declaration, the command still works when invoked programmatically (e.g. from a TreeItem click) but is invisible to users browsing the Command Palette.

Note: `saropaLints.focusIssuesForRules` IS declared (line 272 of package.json) — only `focusIssuesForOwasp` is missing.

## Reproduction

1. Open VS Code with Saropa Lints extension
2. Open Command Palette (Ctrl+Shift+P)
3. Search for "focusIssuesForOwasp" — not found
4. But clicking an OWASP category in the Security Posture tree invokes it successfully

## Relevant code

**Registration (extension.ts, ~line 504):**

```typescript
...['saropaLints.focusIssuesForOwasp', 'saropaLints.focusIssuesForRules'].map((cmdId) =>
  vscode.commands.registerCommand(cmdId, (arg: unknown) => {
    // ...shared handler for both commands
  })
)
```

**TreeItem reference (views/securityPostureTree.ts, line 89):**

```typescript
command: 'saropaLints.focusIssuesForOwasp',
```

**package.json — only focusIssuesForRules is declared:**

```json
{
  "command": "saropaLints.focusIssuesForRules",
  "title": "Focus Issues for Rules"
}
```

## Fix

Add the missing command declaration to `contributes.commands` in `extension/package.json`:

```json
{
  "command": "saropaLints.focusIssuesForOwasp",
  "title": "Focus Issues for OWASP Category"
}
```

The command should also have `"when": "false"` in `commandPalette` menus since it requires a structured argument (OWASP category node) and is not useful from the palette directly.

## Impact

Low user impact — the command works via the Security Posture tree's click handler. The missing declaration only affects discoverability in the Command Palette and VS Code's extension validation.
