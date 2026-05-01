#!/usr/bin/env python3
"""
Build and launch the Saropa Lints VS Code extension in a local Extension Development Host.

Pipeline (default run, no flags)
------------------------------
1. Validate ``extension/`` layout (``package.json``, ``esbuild.js``) and Node/npm versions.
2. Install npm dependencies under ``extension/`` (``npm ci`` when ``package-lock.json`` exists).
3. Run ``npm outdated --json`` for an advisory upgrade summary (never blocks success).
4. Run ``npm run compile`` (TypeScript + esbuild → ``dist/extension.js``).
5. Sanity-check the bundle size, then spawn VS Code (or Cursor) with ``--extensionDevelopmentPath``.

The editor is started with this **repository root** as the opened folder unless you pass a
different path, ``--bare``, or ``--compile-only``. That keeps Saropa Lints (Dart/custom_lint)
activation realistic because the repo contains ``pubspec.yaml``. VS Code/Cursor get
``--extensionDevelopmentPath`` pointing at ``extension/`` and ``--new-window`` plus the host
folder so the Extension Development Host does not restore an empty window.

Editor auto-detection prefers ``code`` (VS Code) over ``code-insiders`` and ``cursor``. Override
with ``--editor cursor`` or ``SAROPA_VSCODE_CLI``.

Usage (from repository root):

    python scripts/run_extension_local.py
    python scripts/run_extension_local.py --compile-only
    python scripts/run_extension_local.py --launch-only
    python scripts/run_extension_local.py --bare
    python scripts/run_extension_local.py D:\\src\\my_dart_app
    python scripts/run_extension_local.py --editor code
    python scripts/run_extension_local.py --no-logo --quiet
    python scripts/run_extension_local.py --verbose-npm

Environment:

    SAROPA_VSCODE_CLI   Full path to the editor executable (overrides ``--editor``).

Prerequisites:

    - Node.js 18+ and npm on PATH
    - extension/package-lock.json (recommended; enables npm ci)

Version:   2.1
Author:    Saropa
Copyright: (c) 2025-2026 Saropa

Exit Codes:
    0  - Success
    1  - Prerequisites / validation failed
    2  - Install or compile failed
    3  - Launch failed
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable

# Import shared terminal helpers (colors, banners) from the same tree as ``publish.py``.
# ``__file__`` lives under ``scripts/``; parent.parent is the repo root — insert it first so
# ``from scripts.modules...`` resolves the same way whether you run from repo root or elsewhere.
_SCRIPTS_PARENT = str(Path(__file__).resolve().parent.parent)
if _SCRIPTS_PARENT not in sys.path:
    sys.path.insert(0, _SCRIPTS_PARENT)

from scripts.modules._utils import (  # noqa: E402  # late import after sys.path fix
    Color,
    OutputLevel,
    enable_ansi_support,
    get_shell_mode,
    print_colored,
    print_error,
    print_header,
    print_info,
    print_section,
    print_success,
    print_warning,
    set_output_level,
    show_saropa_logo,
)

# Bumped when launch/install UX or validation rules change materially (shown in banner).
SCRIPT_VERSION = "2.1"

# VS Code’s extension host and current @types/vscode targets expect a reasonably modern Node;
# 18 matches common engine fields in extension ecosystems; older majors often break esbuild/tsc.
_MIN_NODE_MAJOR = 18

# Relative to ``_EXTENSION_DIR``: ``npm run compile`` writes here; we only check existence/size,
# not contents, to keep this script free of JS parsing.
_DIST_ENTRY = Path("dist") / "extension.js"

# All paths derived from this file so the script is cwd-independent (important on Windows when
# launched from Explorer or another drive letter).
_REPO_ROOT = Path(__file__).resolve().parent.parent
_EXTENSION_DIR = _REPO_ROOT / "extension"
_LOCKFILE = _EXTENSION_DIR / "package-lock.json"
_ESBUILD = _EXTENSION_DIR / "esbuild.js"
_PACKAGE_JSON = _EXTENSION_DIR / "package.json"


# ── Progress (always visible at NORMAL+) ──────────────────────────────────────


def _flush_out() -> None:
    """Flush stdout so banners and step bars appear before npm’s buffered child output.

    Child processes may inherit a block-buffered stdout on some platforms; without an explicit
    flush, the Saropa banner can appear *after* long npm logs and look like a ordering bug.
    """
    try:
        sys.stdout.flush()
    except OSError:
        # Rare on closed pipes; ignore — best-effort UX only.
        pass


def _print_step_bar(step: int, total: int, label: str) -> None:
    """Draw a single-line ASCII progress bar: step index, percentage, and human label.

    ``step`` is 1-based in call sites (first real work is step 1). ``total`` must match the
    number of user-visible milestones so the bar reaches 100% on the final line.
    """
    if total <= 0:
        return
    width = 36
    filled = int((step / total) * width)
    filled = min(max(filled, 0), width)
    bar = "█" * filled + "░" * (width - filled)
    pct = 100.0 * step / total
    line = f"  [{bar}]  {step}/{total}  ({pct:5.1f}%)  {label}"
    print_colored(line, Color.CYAN)
    _flush_out()


def _step(
    step: int,
    total: int,
    label: str,
    fn: Callable[[], bool],
) -> bool:
    """Print the bar for ``step``, run ``fn``, emit success only when ``fn`` returns True."""
    _print_step_bar(step, total, label)
    ok = fn()
    if ok:
        print_success(label)
    return ok


# ── Validations ─────────────────────────────────────────────────────────────


def _validate_extension_layout() -> bool:
    """Fail fast if ``extension/`` is missing or cannot be compiled/bundled."""
    if not _EXTENSION_DIR.is_dir():
        print_error(f"Extension directory missing: {_EXTENSION_DIR}")
        return False
    if not _PACKAGE_JSON.is_file():
        print_error(f"Missing {_PACKAGE_JSON}")
        return False
    if not _ESBUILD.is_file():
        print_error(f"Missing {_ESBUILD} (cannot bundle)")
        return False
    print_info(f"Extension root: {_EXTENSION_DIR}")
    return True


def _get_node_version_tuple() -> tuple[int, int, int] | None:
    """Parse ``node -v`` into (major, minor, patch) or None if Node is missing/unreadable.

    Node prints ``v22.12.0`` (leading ``v``); pre-release suffixes are stripped by taking only
    the leading digit run of the patch segment so ``22.0.0-nightly`` still yields patch 0.
    """
    node = shutil.which("node")
    if not node:
        return None
    try:
        r = subprocess.run(
            [node, "-v"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
            check=False,
        )
    except OSError:
        return None
    if r.returncode != 0 or not (r.stdout or "").strip():
        return None
    raw = (r.stdout or "").strip().lstrip("vV")
    parts = raw.split(".")
    try:
        major = int(parts[0])
        minor = int(parts[1]) if len(parts) > 1 else 0
        patch_s = re.match(r"(\d+)", parts[2]) if len(parts) > 2 else None
        patch = int(patch_s.group(1)) if patch_s else 0
        return (major, minor, patch)
    except (ValueError, IndexError):
        return None


def _validate_node_npm() -> bool:
    """Require Node >= ``_MIN_NODE_MAJOR`` and an ``npm`` executable on PATH.

    We only print npm’s version string for diagnostics; we do not enforce an npm major — the
    lockfile format is npm’s concern, and ``npm ci`` will error clearly if incompatible.
    """
    ver = _get_node_version_tuple()
    if ver is None:
        print_error("Node.js not found on PATH (install Node 18+ LTS).")
        return False
    major, minor, patch = ver
    print_info(f"Node {major}.{minor}.{patch}")
    if major < _MIN_NODE_MAJOR:
        print_error(
            f"Node {major} is too old; need Node {_MIN_NODE_MAJOR}+ for the extension toolchain.",
        )
        return False

    npm = shutil.which("npm")
    if not npm:
        print_error("npm not found on PATH.")
        return False
    try:
        r = subprocess.run(
            [npm, "-v"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
            check=False,
        )
        nv = (r.stdout or "").strip() if r.returncode == 0 else "?"
    except OSError:
        nv = "?"
    print_info(f"npm {nv}")
    return True


def _validate_dist_bundle() -> bool:
    """After compile: ``dist/extension.js`` must exist and be plausibly non-empty.

    The 500-byte floor catches “wrote an empty file” or failed partial writes without parsing JS.
    """
    dist_path = _EXTENSION_DIR / _DIST_ENTRY
    if not dist_path.is_file():
        print_error(f"Missing bundle: {dist_path}")
        return False
    try:
        size = dist_path.stat().st_size
    except OSError as e:
        print_error(f"Cannot stat {dist_path}: {e}")
        return False
    if size < 500:
        print_error(f"Bundle suspiciously small ({size} bytes): {dist_path}")
        return False
    print_info(f"Bundle OK: {dist_path.name} ({size:,} bytes)")
    return True


def _warn_workspace_activation(host: Path | None, bare: bool) -> None:
    """If the opened folder has no ``pubspec.yaml``, remind the user the Dart extension may idle.

    Saropa Lints activates in Dart/Flutter workspaces; opening e.g. a pure JS repo is valid for
    UI testing but analyzers may not run until a Dart root is opened.
    """
    if bare or host is None:
        return
    pubspec = host / "pubspec.yaml"
    if not pubspec.is_file():
        print_warning(
            f"No pubspec.yaml under {host} — extension may stay idle until you open a Dart folder.",
        )


def _resolve_editor_cli(explicit: str | None) -> str | None:
    """Resolve the path or name of the VS Code / Cursor CLI.

    Precedence: ``SAROPA_VSCODE_CLI`` (must be an existing file), then ``--editor`` if not
    ``auto``, then ``shutil.which`` for ``code``, ``code-insiders``, ``cursor`` in that order.
    VS Code first because the extension targets the VS Code API surface; Cursor is a fallback.
    """
    env_path = os.environ.get("SAROPA_VSCODE_CLI", "").strip()
    if env_path:
        p = Path(env_path)
        if p.is_file():
            print_info(f"Editor (SAROPA_VSCODE_CLI): {p}")
            return str(p.resolve())
        print_warning(f"SAROPA_VSCODE_CLI is not a file: {env_path}")

    if explicit and explicit != "auto":
        found = shutil.which(explicit)
        if found:
            return found
        print_error(f"--editor {explicit!r} not found on PATH.")
        return None

    # Prefer VS Code over Cursor in auto mode; users can still pick Cursor via --editor cursor
    # or SAROPA_VSCODE_CLI. This matches the default Saropa workflow (extension targets VS Code
    # API surface; Cursor occasionally lags on EDH behavior).
    for name in ("code", "code-insiders", "cursor"):
        found = shutil.which(name)
        if found:
            print_info(f"Editor (auto): {found}")
            return found

    print_error(
        "No VS Code/Cursor CLI on PATH. Install VS Code (or Cursor), or set SAROPA_VSCODE_CLI.",
    )
    return None


# ── Install & compile ─────────────────────────────────────────────────────────


def _npm_cmd_install_args() -> list[str]:
    """Return the npm subcommand list after ``npm`` for a reproducible install.

    Prefer ``ci`` when ``package-lock.json`` exists so CI and local runs match the same graph;
    fall back to ``install`` only to avoid hard-failing on a missing lockfile (with a warning).
    """
    if _LOCKFILE.is_file():
        return ["ci"]
    print_warning("No package-lock.json — using npm install (consider committing the lockfile).")
    return ["install"]


def _print_subprocess_failure_tail(proc: subprocess.CompletedProcess, *, lines: int = 18) -> None:
    """When npm fails in captured mode, show the tail of combined stdout+stderr (npm logs are long)."""
    out = ((proc.stdout or "") + "\n" + (proc.stderr or "")).strip()
    if not out:
        return
    tail = out.splitlines()[-lines:]
    for ln in tail:
        print_colored(f"      {ln}", Color.DIM)


def _run_npm(
    npm_exe: str,
    npm_args: list[str],
    doing: str,
    *,
    verbose_npm: bool,
) -> bool:
    """Run npm in ``extension/``; avoid printing a raw ``$ npm …`` line unless ``verbose_npm``.

    Default path captures output so the terminal stays readable; on failure we dump a short tail.
    ``get_shell_mode()`` mirrors publish/other scripts: some Windows setups need shell=True for
    ``.cmd`` shims; Unix keeps a direct argv list.
    """
    print_info(doing + "…")
    _flush_out()
    cmd = [npm_exe, *npm_args]
    shell = get_shell_mode()
    if verbose_npm:
        r = subprocess.run(cmd, cwd=_EXTENSION_DIR, shell=shell, encoding="utf-8", errors="replace")
        if r.returncode == 0:
            print_success(doing + " — done")
        else:
            print_error(f"{doing} failed (exit {r.returncode})")
        return r.returncode == 0

    r = subprocess.run(
        cmd,
        cwd=_EXTENSION_DIR,
        shell=shell,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if r.returncode != 0:
        print_error(f"{doing} failed (exit {r.returncode})")
        _print_subprocess_failure_tail(r)
        return False
    print_success(doing + " — done")
    return True


def _run_install(npm_exe: str, skip: bool, *, verbose_npm: bool) -> bool:
    """Install ``extension/node_modules`` unless ``--skip-install`` (then require existing tree)."""
    if skip:
        if not (_EXTENSION_DIR / "node_modules").is_dir():
            print_error("--skip-install requires existing extension/node_modules.")
            return False
        print_info("Skipping install dependencies (--skip-install).")
        _flush_out()
        return True
    action = (
        "Installing extension dependencies from lockfile (npm ci)"
        if _LOCKFILE.is_file()
        else "Installing extension dependencies (npm install)"
    )
    return _run_npm(npm_exe, _npm_cmd_install_args(), action, verbose_npm=verbose_npm)


def _run_compile(npm_exe: str, *, verbose_npm: bool) -> bool:
    """Invoke ``npm run compile`` (see ``extension/package.json`` for precompile + tsc + esbuild)."""
    _flush_out()
    return _run_npm(
        npm_exe,
        ["run", "compile"],
        "Compiling extension (TypeScript check + esbuild bundle)",
        verbose_npm=verbose_npm,
    )


def _report_dependency_upgrades(npm_exe: str) -> bool:
    """Summarize ``npm outdated --json``; informational only — never fails the pipeline.

    npm exits 1 when anything is outdated but still prints JSON on stdout; an empty ``{}`` means
    everything is in range. We never treat JSON parse errors as fatal: network/registry hiccups
    should not block local extension runs.
    """
    print_info("Checking for newer dependency versions (npm outdated)…")
    _flush_out()
    cmd = [npm_exe, "outdated", "--json"]
    r = subprocess.run(
        cmd,
        cwd=_EXTENSION_DIR,
        shell=get_shell_mode(),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    raw = (r.stdout or "").strip()
    if not raw:
        err = (r.stderr or "").strip()
        if err:
            print_warning(f"npm outdated produced no JSON ({err[:120]}…)" if len(err) > 120 else f"npm outdated: {err}")
        return True
    if raw == "{}" or raw == "null":
        print_success("Dependencies: no newer versions reported within current semver ranges.")
        return True
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        print_warning("npm outdated returned non-JSON; check extension/ manually.")
        return True
    if not isinstance(data, dict) or not data:
        print_success("Dependencies: lockfile ranges look current.")
        return True

    rows: list[tuple[str, str, str, str]] = []
    for name, meta in sorted(data.items()):
        if not isinstance(meta, dict):
            continue
        cur = str(meta.get("current", "?"))
        wanted = str(meta.get("wanted", "?"))
        latest = str(meta.get("latest", "?"))
        rows.append((name, cur, wanted, latest))

    print_warning(
        f"{len(rows)} package(s) have newer versions (see wanted vs latest). "
        "This is advisory — build still uses the lockfile until you upgrade.",
    )
    for name, cur, wanted, latest in rows[:10]:
        print_info(f"  · {name}: installed {cur} → wanted {wanted}, latest {latest}")
    if len(rows) > 10:
        print_info(f"  · … and {len(rows) - 10} more (cd extension && npm outdated)")
    print_info("  To upgrade later: cd extension && npm update  (or bump package.json / npm install <pkg>)")
    return True


def _run_launch(editor_cli: str, host_folder: Path | None) -> int:
    """Spawn the editor detached; return 0 on Popen success, 3 if the executable cannot start.

    Argument order matters for Electron-based editors: ``--extensionDevelopmentPath`` must point at
    ``extension/`` (the VSIX root), and an optional **folder path** at the end opens that workspace.
    ``--new-window`` avoids Cursor/VS Code attaching the folder to a restored empty session.
    """
    print_section("Launch Extension Development Host")
    ext_path = str(_EXTENSION_DIR.resolve())
    # VS Code / Cursor may restore an empty session and ignore a trailing folder unless we
    # force a new window; folder path must remain a positional path after the flags.
    args: list[str] = [editor_cli]
    if host_folder is not None:
        args.append("--new-window")
    args.extend(["--extensionDevelopmentPath", ext_path])
    if host_folder is not None:
        args.append(str(host_folder.resolve()))

    print_info(f"CLI: {editor_cli}")
    if host_folder is not None:
        print_info("--new-window  (open this folder in a fresh window)")
    print_info(f"--extensionDevelopmentPath  {ext_path}")
    if host_folder is not None:
        print_info(f"Workspace folder: {host_folder.resolve()}")
    else:
        print_info("Workspace folder: (none — use --bare or pass a path to open a folder)")

    try:
        kwargs: dict = {"cwd": str(_REPO_ROOT)}
        if sys.platform != "win32":
            # Detach from the terminal session so closing the parent shell does not SIGHUP the EDH.
            kwargs["start_new_session"] = True
        proc = subprocess.Popen(args, **kwargs)  # noqa: S603  # argv built from this script, not user shell
    except OSError as e:
        print_error(f"Could not start editor: {e}")
        return 3

    # Tiny pause so a failed immediate spawn is slightly less likely to race the success line.
    time.sleep(0.05)
    print_success(f"Editor started (PID {proc.pid}).")
    print()
    print_colored(
        "  Tip: In the new window, Saropa Lints loads from source. Reload after edits: "
        "Command Palette → “Developer: Reload Window”.",
        Color.DIM,
    )
    print()
    return 0


def _parse_args(argv: list[str]) -> argparse.Namespace:
    """Define CLI; ``epilog`` pulls in the module docstring for ``--help``."""
    p = argparse.ArgumentParser(
        description="Compile the Saropa Lints VS Code extension and open an Extension Development Host.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument(
        "workspace",
        nargs="?",
        default=None,
        help="Folder to open as the host workspace. "
        f"Default: this repo ({_REPO_ROOT}) so the extension can activate.",
    )
    p.add_argument(
        "--bare",
        action="store_true",
        help="Open the editor without a workspace folder.",
    )
    p.add_argument(
        "--compile-only",
        action="store_true",
        help="Install (if needed) + compile only; do not launch an editor.",
    )
    p.add_argument(
        "--launch-only",
        action="store_true",
        help="Skip install/compile; launch using existing dist/ (must exist).",
    )
    p.add_argument(
        "--skip-install",
        action="store_true",
        help="Skip npm ci/install (use when node_modules is already up to date).",
    )
    p.add_argument(
        "--editor",
        choices=("auto", "cursor", "code", "code-insiders"),
        default="auto",
        help="Editor CLI (default: auto). Overridden by SAROPA_VSCODE_CLI.",
    )
    p.add_argument(
        "--no-logo",
        action="store_true",
        help="Skip Saropa ASCII logo (for CI or narrow terminals).",
    )
    p.add_argument(
        "--quiet",
        action="store_true",
        help="Less output (warnings and errors only).",
    )
    p.add_argument(
        "--verbose-npm",
        action="store_true",
        help="Stream full npm stdout/stderr (install + compile); shows raw npm output and deprecation lines.",
    )
    p.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {SCRIPT_VERSION}",
    )
    ns = p.parse_args(argv)
    if ns.compile_only and ns.launch_only:
        p.error("--compile-only and --launch-only are mutually exclusive.")
    if ns.bare and ns.workspace is not None:
        p.error("Pass either a workspace path or --bare, not both.")
    return ns


def main(argv: list[str] | None = None) -> int:
    """Entry: parse args, run either the short ``--launch-only`` path or the full build pipeline."""
    args = _parse_args(argv if argv is not None else sys.argv[1:])

    enable_ansi_support()
    if args.quiet:
        set_output_level(OutputLevel.WARNINGS_ONLY)
    else:
        set_output_level(OutputLevel.VERBOSE)

    if not args.no_logo:
        show_saropa_logo()
        _flush_out()

    print_header("SAROPA LINTS · EXTENSION DEV HOST")
    _flush_out()
    print_colored(
        f"  Script v{SCRIPT_VERSION}  ·  Local Extension Development Host",
        Color.MAGENTA,
    )
    print()
    _flush_out()

    # ── ``--launch-only``: trust existing ``dist/``; 5 progress steps ───────────
    if args.launch_only:
        total_steps = 5
        # Step map: 1 layout, 2 dist bundle, 3 resolve editor, 4 workspace hints, 5 launch.
        cur = 0

        def v1() -> bool:
            return _validate_extension_layout()

        def v2() -> bool:
            return _validate_dist_bundle()

        cur += 1
        if not _step(cur, total_steps, "Validate extension layout", v1):
            return 1
        cur += 1
        if not _step(cur, total_steps, "Validate compiled bundle (dist/)", v2):
            return 1

        editor_cli = _resolve_editor_cli(None if args.editor == "auto" else args.editor)
        if editor_cli is None:
            return 1
        cur += 1
        _print_step_bar(cur, total_steps, "Resolve editor CLI")
        print_success("Editor CLI OK")

        host: Path | None
        if args.bare:
            host = None
        elif args.workspace is not None:
            host = Path(args.workspace)
            if not host.is_dir():
                print_error(f"Workspace is not a directory: {host}")
                return 1
        else:
            # Default host: repo root (contains pubspec + lib/ for realistic Saropa activation).
            host = _REPO_ROOT

        cur += 1
        _print_step_bar(cur, total_steps, "Workspace activation hints")
        _warn_workspace_activation(host, args.bare)
        print_success("Workspace path OK")

        cur += 1
        _print_step_bar(cur, total_steps, "Launch")
        return _run_launch(editor_cli, host)

    # ── Full pipeline: 6 steps if ``--compile-only``, else 7 (adds launch) ─────
    total_steps = 7 if not args.compile_only else 6
    cur = 0

    def v_layout() -> bool:
        return _validate_extension_layout()

    def v_toolchain() -> bool:
        return _validate_node_npm()

    cur += 1
    if not _step(cur, total_steps, "Validate extension layout & toolchain", lambda: v_layout() and v_toolchain()):
        return 1

    # ``_validate_node_npm`` already checked ``which("npm")``; this is a narrow second guard if
    # someone edits validation later and drops the npm half.
    npm = shutil.which("npm")
    if not npm:
        print_error("npm not found after validation.")
        return 1

    cur += 1
    _print_step_bar(cur, total_steps, "Install dependencies")
    if not _run_install(npm, args.skip_install, verbose_npm=args.verbose_npm):
        return 2

    cur += 1
    _print_step_bar(cur, total_steps, "Dependency upgrade check")
    _report_dependency_upgrades(npm)

    cur += 1
    _print_step_bar(cur, total_steps, "Compile extension")
    if not _run_compile(npm, verbose_npm=args.verbose_npm):
        return 2

    cur += 1
    if not _step(cur, total_steps, "Validate output bundle", _validate_dist_bundle):
        return 2

    if args.compile_only:
        cur += 1
        _print_step_bar(cur, total_steps, "Done")
        print()
        print_success("Compile-only complete. Run without --compile-only to launch the Extension Host.")
        return 0

    cur += 1
    _print_step_bar(cur, total_steps, "Resolve editor & workspace")
    editor_cli = _resolve_editor_cli(None if args.editor == "auto" else args.editor)
    if editor_cli is None:
        return 1

    host_lp: Path | None
    if args.bare:
        host_lp = None
    elif args.workspace is not None:
        host_lp = Path(args.workspace)
        if not host_lp.is_dir():
            print_error(f"Workspace is not a directory: {host_lp}")
            return 1
    else:
        host_lp = _REPO_ROOT

    _warn_workspace_activation(host_lp, args.bare)
    print_success("Ready to launch")

    print()
    cur += 1
    _print_step_bar(cur, total_steps, "Launch editor")
    return _run_launch(editor_cli, host_lp)


if __name__ == "__main__":
    raise SystemExit(main())
