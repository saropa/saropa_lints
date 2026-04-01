# BUG: TypeScript 5.9 Breaks Extension Compilation — Marketplace Stuck at v10.2.2

**Status: RESOLVED 2026-03-29**

**Resolution:** Pinned `typescript` in `extension/package.json` from `^5.3.0` (which
auto-upgraded to 5.9.3) to `~5.8.3` (latest working 5.8.x). This restores `tsc --noEmit`
and unblocks extension packaging and Marketplace publishing.

Created: 2026-03-29
Component: VS Code extension build toolchain
File: `extension/package.json` (devDependencies)
Severity: Critical — blocked all Marketplace releases from v10.2.3 through v10.4.0
Impact window: v10.2.3 through v10.4.0 (5 versions missed on Marketplace)

---

## Summary

The VS Code Marketplace extension was stuck at version 10.2.2 despite the pub.dev package
successfully publishing through v10.4.0. Every run of `python scripts/publish.py` completed
the pub.dev publish via GitHub Actions but silently failed the extension packaging step.

The root cause is a **bug in TypeScript 5.9** where `tsc` cannot recognize ANY command-line
compiler option (`--noEmit`, `--version`, `--help`, etc.) — they all produce:

```
error TS5023: Unknown compiler option '--noEmit'.
```

---

## Root Cause: Broken Option Name Lookup in TypeScript 5.9

### The bug in TypeScript's source

In TypeScript 5.9, the `createOptionNameMap()` function builds a lookup map used by
`parseCommandLine()` to resolve CLI flags like `--noEmit`:

```javascript
// From typescript/lib/_tsc.js (TS 5.9.3)
function createOptionNameMap(optionDeclarations2) {
  const optionsNameMap = new Map();
  const shortOptionNames = new Map();
  forEach(optionDeclarations2, (option) => {
    optionsNameMap.set(option.lowerCaseName, option);  // <-- BUG: property doesn't exist
    if (option.shortName) {
      shortOptionNames.set(option.shortName, option.name);
    }
  });
  return { optionsNameMap, shortOptionNames };
}
```

The function reads `option.lowerCaseName`, but **this property does not exist on any
option declaration object**. Every option declaration has a `name` property (e.g.
`"noEmit"`) but no `lowerCaseName` property.

### Proof

```javascript
const ts = require('typescript'); // v5.9.3

// The option declaration exists and is correct
const noEmit = ts.optionDeclarations.find(o => o.name === 'noEmit');
console.log(noEmit.name);           // "noEmit"
console.log(noEmit.lowerCaseName);  // undefined  <-- property missing

// The name map is essentially empty (1 garbage entry)
const map = ts.getOptionsNameMap();
console.log(map.optionsNameMap.size);  // 1
// Single entry: undefined -> ignoreDeprecations (last option processed)

// Short names still work (different code path)
console.log(map.shortOptionNames.size); // 9 (h, ?, w, i, d, v, p, t, m)

// So parseCommandLine rejects all long-form options
const result = ts.parseCommandLine(['--noEmit']);
console.log(result.errors[0].messageText);
// "Unknown compiler option '--noEmit'."
```

The map ends up with exactly **1 entry** keyed by `undefined` (because every
`option.lowerCaseName` evaluates to `undefined`, each iteration overwrites the
same key, leaving only the last option processed: `ignoreDeprecations`).

Short names (`-v`, `-p`, `-d`, etc.) still work because `shortOptionNames` uses
`option.shortName` which does exist.

### Previous behavior (TypeScript 5.8 and earlier)

In 5.8.x, `createOptionNameMap` used `option.name.toLowerCase()`:

```javascript
function createOptionNameMap(optionDeclarations2) {
  const optionsNameMap = new Map();
  forEach(optionDeclarations2, (option) => {
    optionsNameMap.set(option.name.toLowerCase(), option);  // correct
    // ...
  });
}
```

---

## Why It Was Silent

The publish script's extension compile step captures output and treats failure as non-fatal:

```python
# _extension_publish.py — run_extension_compile()
r = run_command(
    ["npm", "run", "compile"],
    ext_dir,
    "Compile extension",
    capture_output=True,   # <-- stderr/stdout captured
    allow_failure=True,    # <-- returns False instead of raising
)
```

When compile fails, `package_extension()` returns `None`, and
`run_extension_after_publish()` prints a warning:

```
Extension packaging failed — .vsix was not created.
Check compile errors above.
```

But this appeared after the "PUBLISHED" success banner for pub.dev, and the captured
compile output (with the TS error) was not prominently displayed. The user saw the
pub.dev success and didn't notice the extension warning.

---

## Timeline

| Date | Event |
|------|-------|
| 2026-03-28 | v10.2.2 published to pub.dev AND Marketplace (last working extension publish) |
| 2026-03-28 | npm auto-upgraded typescript from 5.8.x to 5.9.x at some point after 10.2.2 |
| 2026-03-28 | v10.2.3 attempted — pub.dev succeeded, extension compile failed silently |
| 2026-03-29 | v10.3.0 attempted — same silent extension failure |
| 2026-03-30 | v10.4.0 attempted — same silent extension failure |
| 2026-03-29 | Root cause identified and fixed (pinned to ~5.8.3) |

---

## Fix Applied

Changed `extension/package.json`:

```diff
-    "typescript": "^5.3.0"
+    "typescript": "~5.8.3"
```

Using `~5.8.3` (tilde) instead of `^5.8.3` (caret) to prevent auto-upgrade to 5.9.x
or any future minor version that might reintroduce the bug. Only patch-level updates
(5.8.4, 5.8.5, etc.) will be picked up automatically.

### Reverting this pin

When TypeScript 5.9.x or 6.x ships a fix for the `lowerCaseName` bug, the pin can
be relaxed back to `^5.x.0`. Test by running:

```bash
cd extension && npx tsc --noEmit
```

If it exits cleanly (exit code 0), the fix is in and the pin can be relaxed.

---

## Lessons Learned

1. **Pin critical toolchain dependencies with `~` (tilde), not `^` (caret).** A minor
   version bump in TypeScript broke a core CLI feature. Using `~` limits auto-upgrades
   to patch versions only.

2. **Extension compile failures should be more visible.** The publish script's
   `capture_output=True` on the compile step hid the actual error. Consider echoing
   captured stderr when compilation fails, or making extension compile failure a
   blocking error (not just a warning) when the user chose "full publish."

3. **The publish script should verify the .vsix was created before reporting success.**
   Currently the pub.dev success banner prints before the extension step runs, making
   it look like everything worked.

---

## Environment

- TypeScript: 5.9.3 (broken), 5.8.3 (working)
- Node.js: 25.2.1
- VS Code: latest
- OS: Windows 11 Pro
- npm scripts affected: `check-types` (`tsc --noEmit`), `compile`, `package`
