# Fix: Extension tsconfig.json missing explicit Node.js type declarations

The VS Code extension's `tsconfig.json` relied on TypeScript's automatic `@types/*` discovery to resolve Node.js globals (`Buffer`, `process`, `node:fs`, `node:path`, `node:child_process`). When the IDE's language service failed to auto-discover `@types/node`, every Node.js reference in `setup.ts` reported TS2591 errors.

## Finish Report (2026-08-16)

**Root cause:** `tsconfig.json` had no `"types"` field. TypeScript auto-includes every package under `node_modules/@types/` when `"types"` is absent — but this auto-discovery is fragile and depends on the TS language-service version and workspace state. The extension has six `@types/*` packages (`node`, `vscode`, `semver`, `jsdom`, `mocha`, `sinon`); the last three are test-only and already excluded via the `"exclude": ["src/test"]` directive.

**Fix:** Added `"types": ["node", "vscode", "semver"]` to `compilerOptions`. This explicitly declares the three runtime type packages. Test-only types (`jsdom`, `mocha`, `sinon`) are omitted because `src/test/` is excluded from compilation.

**Validation:** `npx tsc --noEmit` passes with zero errors.

**Risk mitigation:** A `verify-tsconfig-types.mjs` script scans non-test source files for imports of installed `@types/*` packages and fails if any are missing from the `"types"` array. Wired into `precompile` so every `npm run compile` and `npm run package` catches the gap before `tsc` runs. This eliminates the manual-maintenance risk of the explicit `"types"` field.

**Hardening verification:**
- `@types/semver` confirmed used in 7 non-test source files (vibrancy scoring modules).
- `@types/jsdom` confirmed test-only (2 files under `src/test/`).
- `@types/sinon` confirmed test-only (25 files under `src/test/`).
- `configTree.ts:85` TS2339 error was transient (stash state artifact); final `tsc --noEmit` clean.
