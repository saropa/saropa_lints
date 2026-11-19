# PROPOSAL: One obvious on/off switch for Saropa Lints in the VS Code extension

**Status: Implemented in 17.0.1-beta.3. Follow-up fixes (display ignores saved record; init exit on default projects) in Unreleased. Original toggle failure in the contacts project not reproduced; closed per owner 2026-10-29.**

Created: 2026-10-29
Type: Tooling / Infrastructure (extension UX)
Engine: extension-native (`extension/src/`)
Found in: extension 17.0.11, package 17.0.0 (project pinned to 17.0.1-beta.2 afterward)

**Owner decisions (2026-10-29):** treat as a bug report; fix all issues. The single switch controls the full live plugin and `saropaLints.enabled` follows it. Ownership record stays internal.

**Owner decision (2026-10-29), On definition:** "On" = setting `saropaLints.enabled` true AND the plugin block is live OR was never turned off by the extension (default new-project sentinel-wrapped block, no ownership memento = daemon-only = On). "Partly off" shows only when the extension itself turned the block off (ownership memento present) or the setting and block otherwise disagree in a non-default way. Turning On from the default state must NOT load the heavy plugin.

**Review notes:** defect 5 root cause is `lib/src/init/preflight.dart:165` (regex matches the first `version:` anywhere). `pluginDivergencePrompt.ts` already exists but is silent when both switches are off. Fix split: Dart (`lib/`) and extension (`extension/`).

---

## Summary

Turning Saropa Lints on or off takes two switches (setting, plugin block) plus one internal record of whether the extension turned the block off, across several screens.
The owner could not turn it on from the UI. The UI showed a healthy state while nothing ran.
Wanted: one switch, one true state, one repair button.

---

## What happened (reporter: owner of the `contacts` app)

- Lints were not running. The owner tried the recommended ways and none turned them on.
- Cause found by reading the extension bundle and the project files. Three independent switches were all off:

| # | Switch | Where it lives | State found |
|---|---|---|---|
| 1 | `saropaLints.enabled` | `.vscode/settings.json` (workspace setting) | `false` |
| 2 | `plugins: saropa_lints:` block | `analysis_options.yaml` | commented out under the marker `# >>> saropa_lints integration turned OFF by the VS Code extension` |
| 3 | Ownership record | VS Code workspace state, plus `.dart_tool/saropa_lints/plugin_ownership.json` | file absent |

- Fix applied by hand: set switch 1 to `true`, and uncomment the block for switch 2.
- The owner's words: the extension UI is far too complicated; turning it on and off should be easy.

---

## Defects

1. **No single on/off control.** The Lints Config dashboard has 7 tabs (Tier, Rule packs, Overrides, SDK rollout, Config file, Automation, Extension). None of the visible ones is an obvious "Lints: On/Off". The only hint is a marker comment in `analysis_options.yaml` that says to toggle "Lint integration" On.
2. **The dashboard reports healthy while off.** With the plugin block commented out and `saropaLints.enabled` false, the dashboard showed `100% coverage`, `105/151 packs enabled`, `2727 pack rules enabled`. The sidebar showed `Engines: 2 running` next to `Live Analysis stopped`. Nothing said "off".
3. **The two switches disagree silently.** `saropaLints.enabled` (setting) and the plugin block (file) are separate. Turning one on leaves the other off, with no warning.
4. **`dart run saropa_lints:init --tier recommended` exits successfully while the result is broken.** It printed `Written to: analysis_options.yaml`, then:
   - `[WARN] plugins: — section missing`
   - `[WARN] version: — key missing — analyzer will silently ignore plugin`
   - `[WARN] diagnostics: — section missing`
   - `[WARN] Rule count — 0 rules found, expected ~2386`
   It did not re-enable the commented block, and it did not fail.
5. **Wrong text in a warning.** `[WARN] Existing config — version true may be stale (current: 17.0.0)`. The version printed is the word `true`. The comment block the extension wrote says `version: "17.0.0"`, so the value read is wrong.
6. **Version drift is silent.** The project pinned `17.0.1-beta.2`; `analysis_options.yaml` still said `17.0.0`. Nothing prompted a sync.
7. **The CLI is called deprecated but is the fallback the init output points to.** The init output says `CLI init is deprecated. Use the Saropa Lints VS Code extension for setup.` The extension then could not do the job.

---

## Proposal

1. **One switch, top of the Saropa Lints sidebar and in the status bar:** `Saropa Lints: On` / `Off`. One click turns lints on or off. Turning On from a new project's default state turns on only the `saropaLints.enabled` setting and does not load the in-process plugin.
2. **One computed state.** The switch shows the real state from two switches (setting, plugin block) plus one internal record of whether the extension turned the block off:
   - `On`: setting true AND the plugin block is live or was never turned off by the extension.
   - `Off`: setting false and the block is not live.
   - `Partly off: <setting|plugin>`: the extension turned the block off while the setting is on, or the block is live while the setting is off. A `Fix` button makes both agree. Never show healthy numbers in this state.
3. **Dashboard banner when off.** Replace the coverage ring and counts with `Lints are off. [Turn on]`.
4. **`init` must fail loudly.** `init` exits non-zero when the result has no `plugins:` block at all, a live block with 0 rules, or the extension turned lints off. A commented default block exits 0 with a plain sentence. The sentence says 'switched off in the extension' only when the ownership record exists; otherwise it says 'default lightweight mode'.
5. **Fix the `version true` text** and auto-sync the `version:` line to the package in `pubspec.lock`, or offer a one-click sync.
6. **Keep the 7-tab dashboard for tuning only.** Turning on and off must not need it.

---

## Acceptance

- A new user can turn lints on in one click without opening the dashboard.
- With either switch off, the UI says so in words and offers one `Fix` action.
- `dart run saropa_lints:init` never reports success with 0 rules found.

---

## Unverified

- Why the "Lint integration" toggle did not work for the owner is not reproduced. The restore code in `extension/src/` (`cm`, `Ub`, `reenablePlugin`) reads correct, but it only acts on the `plugins:` block. It does not touch the `saropaLints.enabled` setting. A likely reason: switch 1 stayed off while the owner toggled switch 2. This needs a reproduction.
- The init output marked nearly every package as disabled (drift, supabase, http and others) while the dashboard counts those packs as detected. Not investigated here.
