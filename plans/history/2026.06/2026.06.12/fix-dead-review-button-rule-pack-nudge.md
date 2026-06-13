# Dead "Review" button on the rule-pack suggestion notification (Extension)

On project open, the VS Code extension shows one coalesced notification summarizing how
many applicable-but-disabled rule packs the project has ("Saropa Lints: N rule pack
suggestion(s) apply to this project."). Its **Review** action produced no visible response:
clicking the button appeared to do nothing.

## Finish Report (2026-06-12)

### Scope
(B) VS Code extension (TypeScript under `extension/`). No Dart lint-rule, analyzer-plugin,
`example/`, or `analysis_options*.yaml` files were touched, so the Dart-rule sections of the
linter finish checklist are out of scope.

### Root cause
The notification's Review action ran `vscode.commands.executeCommand('saropaLints.suggestions.focus')`.
That auto-generated command focuses the standalone **Suggestions** sidebar tree. Focusing a
view yields no perceptible change when the view is hidden or collapsed, or when its
activity-bar container is already the open sidebar — the common cases at the moment a startup
toast fires. The action had no fallback and no error path: every call site invokes the nudge
as `void maybeShowStartupSuggestion(context)`, so a rejected `executeCommand` became a silent
unhandled rejection. The net effect was a button that could do nothing and report nothing.

### What changed
The Review action now opens the rule-pack **Config Dashboard** webview via
`saropaLints.openRulePacks` (registered at `extension/src/extension.ts`, backed by
`RulePacksWebviewProvider.openEditorPanel`). A webview panel always opens a visible editor
tab — unlike focusing a sidebar view, it cannot silently no-op — and it is the surface where
each applicable pack is listed with a toggle, which is the actual review-and-enable action the
button promises. The call is wrapped in try/catch; on failure it shows an error notification
(`startupNudge.reviewFailed`) so a non-functional Review button can never again fail silently.
The Suggestions sidebar view and its activity-bar count badge are unchanged and remain the
durable backstop for the suggestion count.

### Files changed
- `extension/src/rulePacks/startupSuggestionNudge.ts` — Review action retargeted from
  `saropaLints.suggestions.focus` to `saropaLints.openRulePacks`, wrapped in try/catch with a
  user-facing error fallback.
- `extension/src/i18n/locales/en.json` — added `startupNudge.reviewFailed`.
- `CHANGELOG.md` — bullet under `### Fixed (Extension)` in `[Unreleased]`.

These landed in commit `554404b6` (bundled with a concurrent publish-audit change).

### Verification
- `npm run check-types` (`tsc --noEmit`) — clean.
- The target command id `saropaLints.openRulePacks` is verified by inspection to be registered
  in `extension/src/extension.ts` and to call `RulePacksWebviewProvider.openEditorPanel`.

### Testing notes
The pure logic behind the suggestion set is already covered by `configSuggestions.test.ts` and
`upgradePackNudgeLogic.test.ts`. The vscode-wired toast action in `startupSuggestionNudge.ts`
(notification → `executeCommand`, plus disk-backed `computeConfigSuggestions`) has no
end-to-end unit test in the repo; exercising it would require an `ExtensionContext` mock, a
spy command, and a temporary project fixture that yields a non-empty suggestion set. A harness
of that size was judged disproportionate to a one-line command-target change whose correctness
rests on the target command existing (verified by inspection) and the call compiling (verified
by `tsc`). No existing test referenced the changed symbols, so none required updating.

### Outstanding
- The 24 translated locale catalogs are stale for the new `startupNudge.reviewFailed` key.
  Regenerating them is the machine-translation pipeline, a separately authorized job on its own
  cadence; it was not run here. The i18n runtime falls back to English for any key missing in a
  locale, so the error message renders in English on non-English UIs until the regeneration runs
  — the same standing condition already noted for the other `startupNudge` keys.
