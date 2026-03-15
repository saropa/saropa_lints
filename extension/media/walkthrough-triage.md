## Triage & Config

The **Config view** groups rules by priority:

- **Critical** (flame icon) — Rules with critical-impact violations
- **Volume bands** A–D — Rules grouped by issue count (1–5, 6–20, 21–100, 100+)
- **Stylistic** — Opt-in formatting and naming rules

Each group shows the **estimated score impact** (e.g. "est. +8 pts") so you can prioritize what to fix first.

**Right-click** a rule or group to disable/enable it. Changes write to `analysis_options_custom.yaml` and re-run analysis automatically.

Packages are **auto-detected** from `pubspec.yaml` — no manual configuration needed.
