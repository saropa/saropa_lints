# Performance and regression baselines — Plan §10 F1-F5

Captured 2026-05-01 against `pubspec.yaml: version: 12.8.4` on Windows 11.

## F1 — Regression baseline output

Captured raw `dart analyze --format=machine` output for both example packages, saved alongside this file:

- [`v12_8_4_example_analyze.txt`](v12_8_4_example_analyze.txt) — 288 lines.
- [`v12_8_4_example_packages_analyze.txt`](v12_8_4_example_packages_analyze.txt) — 8 lines.

Most entries are intentional fixture compile shapes (e.g. unresolved `package:firebase_messaging/...` imports, intentional bounds violations) used to drive specific rules under test. **A regression is any entry that did not appear in the previous tagged version.** To diff against the next release:

```bash
git worktree add /tmp/saropa-prev v12.8.4
cd /tmp/saropa-prev/example && dart analyze --format=machine > /tmp/prev.txt
diff <(sort /tmp/prev.txt) <(sort path/to/new.txt)
```

(Original plan §10 F1 said "v4 vs v5" — corrected here to "previous tag vs current" since the project is on the 12.x line; see plan §8.)

## F2 — `dart analyze` warm timings (example/)

Three consecutive runs after one warmup, each measured with `date +%s%N` deltas:

| Iteration | Duration (ms) | Exit code |
|-----------|--------------:|-----------|
| 1 | 8418 | 3 |
| 2 | 5416 | 3 |
| 3 | 5042 | 3 |

- **min:** 5042 ms
- **median:** 5416 ms
- **max:** 8418 ms (cold-ish; iteration 1 includes filesystem-cache warmup)

## F3 — `dart analyze` warm timings (example_packages/)

| Iteration | Duration (ms) | Exit code |
|-----------|--------------:|-----------|
| 1 | 3439 | 3 |
| 2 | 3048 | 3 |
| 3 | 3099 | 3 |

- **min:** 3048 ms
- **median:** 3099 ms
- **max:** 3439 ms

`example_packages/` is faster despite hosting more rule-pack fixtures because most fixtures import real package APIs that get resolved once across the run, while `example/` hosts more standalone shape-only fixtures that each force a separate analyzer load path.

## F4 — Peak RSS

Sampled via PowerShell `$proc.WorkingSet64` polled every 50 ms during the run:

| Workspace | Peak RSS (MB) |
|-----------|--------------:|
| example/ | 8.3 |

**Caveat:** The number above is the `dart` launcher process. The launcher spawns the analyzer binary in a child process; capturing the child's RSS would require WMI process-tree polling. This is recorded as a baseline shape only — for a real comparison-quality measure, follow up with a Linux/WSL `/usr/bin/time -v` capture or a Windows ETW trace.

## F5 — Time-to-squiggle (qualitative)

Skipped automated capture (would require WebDriver-driving VS Code). Instead, fold into the manual checklist at [`../ide_integration/README.md`](../ide_integration/README.md) step E1 — note the wall-clock between save and squiggle appearance there when a reviewer runs through the IDE checks.

## Methodology

- Run from a quiet system (no concurrent dart/flutter/IDE processes).
- Three iterations minimum to spot warmup outliers; record min/median/max, not mean.
- Capture `--format=machine` for diffability; `--format=json` is more verbose but harder to grep.
- For a release-gate, repeat the F2/F3 capture against the candidate tag and require **median ≤ 1.25× the prior median** — see plan §8 row "Regression baseline".

## Reproduce

```bash
# F2/F3 timing
cd <example_dir> && for i in 1 2 3; do
  start=$(date +%s%N)
  dart analyze >/dev/null 2>&1
  end=$(date +%s%N)
  echo "iter=$i duration_ms=$(( (end - start) / 1000000 ))"
done

# F4 RSS (PowerShell)
$out=Join-Path $env:TEMP "out.txt"; $err=Join-Path $env:TEMP "err.txt"
$p=Start-Process -FilePath dart -ArgumentList 'analyze' -WorkingDirectory <dir> -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
$max=0; while (-not $p.HasExited) { $p.Refresh(); if ($p.WorkingSet64 -gt $max) { $max = $p.WorkingSet64 }; Start-Sleep -Milliseconds 50 }
[math]::Round($max / 1MB, 1)
```
