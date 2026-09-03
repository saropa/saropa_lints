# Publish Script: Log File, Remote Execution, and Auto-Retry

The publish script (`scripts/publish.py`) lacked file logging and could not run unattended — every mode required interactive prompting, and step failures blocked on `input()`.

## Changes

### `scripts/publish.py`
- Added `--log-file <path>` flag to mirror all output (ANSI-stripped) to a plain-text file.
- Added `--mode <name>` flag to select any of the 10 publish modes non-interactively, with short aliases (`audit` for `audit_only`, `analyze` for `analyze_only`, etc.).
- Added `--auto-retry <n>` flag to auto-retry failed steps up to N times before aborting.
- Auto-detects non-TTY stdin (piped / remote execution) and enables non-interactive mode.
- Unified mode definitions: `_MODE_TABLE` is the single source of truth for both the interactive menu and CLI `--mode` flag. Adding a mode in one place updates both surfaces.
- `_parse_args` replaces `_parse_mode_from_argv` with full flag parsing, including missing-value error handling for all flags.
- Auto-retry is prompted interactively at startup (not buried behind a CLI-only flag).
- `close_log_file()` called in a `finally` block to ensure log is flushed on any exit path.

### `scripts/modules/_utils.py`
- Added `set_log_file(path)` / `close_log_file()` — opens a UTF-8 log file; all `print_*` output is mirrored with ANSI codes stripped via `_ANSI_RE`. Gracefully handles unwritable paths.
- Added `set_non_interactive(bool)` / `is_non_interactive()` — global flag for unattended mode.
- Added `safe_input(prompt, default)` — returns default without blocking in non-interactive mode; catches `EOFError`/`KeyboardInterrupt` in interactive mode.
- Added `set_auto_retry_limit(n)` / `get_auto_retry_limit()` — per-step retry budget tracked in `_auto_retry_counts`.
- `prompt_step_failure()` now: (1) auto-retries up to the limit, (2) then auto-aborts in non-interactive mode.
- `log_write()` (renamed from `_log_write`) is the public API for tee-logging from other modules.
- `print_colored()`, `print_stat()`, `print_stat_bar()`, `run_command()`, `show_saropa_logo()` all tee to log file.

### `scripts/modules/_timing.py`
- Timing rows and summary totals now tee to log file via `log_write`.

## Review Findings (all fixed)
1. `--mode` without a value was silently dropped — now errors with valid mode list.
2. `set_log_file` crashed on unwritable paths — now warns and continues.
3. Per-line `flush()` in `log_write` — removed (Python text-mode buffering + `close_log_file` flush suffice).
4. Stale docstring on `_prompt_publish_mode` — corrected ("1-8" → generated from table).
5. Mode definitions duplicated between `_VALID_MODES` dict and `_prompt_publish_mode` if/elif chain — unified into `_MODE_TABLE`.

## Known Remaining Work
~25 `input()` calls in sub-modules (`_publish_steps.py`, `_extension_publish.py`, `_git_ops.py`, `_version_changelog.py`, etc.) still use raw `input()`. These affect `full` and `extension_only` modes when they hit failure/prompt paths. The `safe_input()` infrastructure is in place for incremental migration.

## Finish Report (2026-09-03)

The publish script gained three CLI flags (`--log-file`, `--mode`, `--auto-retry`) and non-interactive execution support. The logging layer tees all `print_*` output through a centralized `log_write` function that strips ANSI codes, with graceful handling of unwritable log paths. The non-interactive mode auto-answers prompts with safe defaults and auto-retries failed steps (up to the configured limit) before aborting. Mode definitions are unified in a single `_MODE_TABLE` that drives both the interactive menu and CLI flag parsing. Auto-retry is surfaced in both CLI (`--auto-retry <n>`) and the interactive startup prompt, per the project's "no buried features" rule. Sub-module `input()` calls remain as incremental migration targets.
