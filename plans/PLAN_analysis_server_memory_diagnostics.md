# PLAN: Find what really drives analysis-server memory on the 8 GB Mac

Created: 2026-09-19
Origin: `plans/history/2026.09/2026.09.19/infra_exclusion_audits_miss_claude_worktrees_nested_package_roots.md` (closed: its premise was disproved)
Related: `plans/ANALYSIS_dev_machine_stability.md`

---

## Question

On 2026-09-18 the `dart language-server` for the contacts workspace reached 6.7 GB on an 8 GB Mac. The closed report blamed `.claude/worktrees` copies. That is ruled out (step 1). What does drive it, and what should saropa_lints tell the user?

---

## Done (2026-09-19, by Claude, read-only on this machine)

1. **Dot-folder probe: worktrees ruled out.** A throwaway package with an error-bearing nested package in `claude/worktrees/w/` and an identical one in `.claude/worktrees/w/` gave, under `dart analyze` (SDK 3.13.3), only the `claude/` error. The analyzer skips dot-folders.
2. **Heap cap found.** The contacts workspace's `.vscode/settings.json` sets `dart.analyzerVmAdditionalArgs: ["--old_gen_heap_size=6144"]`. The server may grow to about 6 GB of heap before the VM collects hard, which matches the 6.7 GB reading (heap plus VM overhead).
3. **Live snapshot.** `top` MEM: language server 5.1 GB (PID 63549, up 8.5 h), plus saropa_lints' own `scan_daemon` at 3.1 GB for the same project (`--tier recommended`). Together that is more than the machine's RAM, hence the paging (149k pageouts).
4. **Worktree count.** Only one worktree (about 1 GB) is under `.claude/worktrees`. The other copies (`contacts-fr`, `-fs`, `-slice1`, `-slice2`) are sibling folders outside the workspace and cost the server nothing.

---

## Remaining steps

| # | Step | Who | Notes |
|---|---|---|---|
| 5 | Lower the heap cap in contacts to `4096` (or remove it), restart the analysis server, and check whether it settles lower and stays usable | User decides; Claude can edit the setting | This is a downstream project setting, so it needs your go-ahead. If the server hits the cap it slows down or restarts; watch for that. |
| 6 | Measure the project's real peak: `/usr/bin/time -l dart analyze` in contacts, reading "maximum resident set size" | Claude | Run only when the contacts sessions are idle. The run itself needs a few GB, and running it now would push the machine further into swap. |
| 7 | Find out why `scan_daemon` holds 3.1 GB | Claude (in this repo) | It's saropa_lints' own process, so this is our bug if it's a leak. Check its lifetime, whether it frees memory between scans, and whether `SAROPA_LINTS_MAX_RSS_MB` (default 4096) is applied. File a bug if it grows without bound. |
| 8 | System Health: warn when the heap cap is above about 50% of physical RAM, and suggest a RAM-based value in the heap-cap prompt | Claude (in this repo) | Today the dashboard only warns when there is no cap (`noHeapCap`); a cap of 6144 on 8 GB passes silently. File as `proposal_infra_…` first. |

## Done when

- Step 6 gives a baseline peak for the project, and step 5 shows whether a lower cap holds under normal editing.
- Step 7 either finds a daemon leak (bug filed) or explains the 3.1 GB.
- Step 8 is filed as a proposal.
