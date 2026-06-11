#!/usr/bin/env python3
"""Generate extension locale files from English JSON sources.

Usage:
    py -3 extension/scripts/i18n/generate_locales.py              # English placeholders only
    py -3 extension/scripts/i18n/generate_locales.py --translate   # machine-translate via Google
    py -3 extension/scripts/i18n/generate_locales.py --translate --locales bn,de
"""

from __future__ import annotations

import argparse
import signal
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

# Force UTF-8 stdout/stderr so non-Latin translated text (Bengali, Arabic,
# Chinese, etc.) prints correctly on Windows consoles that default to cp1252.
if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
if sys.stderr.encoding != "utf-8":
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]

from dictionaries import TRANSLATIONS
from json_io import read_json, write_json
from mt_fallback import (
    active_engine_name,
    cache_lookup,
    cache_set,
    cache_unset,
    count_pending_translations,
    describe_engine_availability,
    engine_stats_for,
    fallback_log,
    load_mt_cache,
    load_provenance,
    low_quality_entries,
    prefetch_machine_translations,
    provenance_of,
    prune_all,
    prune_low_quality,
    request_stop,
    reset_engine_stats,
    save_mt_cache,
    save_provenance,
    should_skip_machine_translate,
    stop_requested,
)
from term_color import c
from tree_translate import apply_string_map, collect_unique_strings
from translator import HybridTranslator


@dataclass
class LocaleStats:
    """Per-locale audit counters.

    ``translated`` and ``skipped`` together cover every string we are okay
    with leaving unchanged or rendering in the target language. ``missing``
    is the actionable number: strings that should have a translation but
    came back identical to English (no dict entry, MT off or failed).
    """

    total: int
    translated: int
    skipped: int
    missing: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate extension locale JSON files.")
    parser.add_argument(
        "--locales",
        default=(
            "ar,bn,de,es,fa,fil,fr,he,hi,id,it,ja,ko,nl,pl,pt,ru,sw,th,tr,uk,ur,vi,zh"
        ),
        help=(
            "Comma-separated locale codes (default: full shipped set per "
            "plans/EXTENSION_LOCALIZATION_GUIDE.md primary and secondary tiers)."
        ),
    )
    parser.add_argument(
        "--fail-on-missing",
        action="store_true",
        help=(
            "Exit non-zero if any locale still has missing translations after "
            "this run. Used by the publish pipeline as a coverage gate so "
            "untranslated UI strings can never ship silently. Standalone dev "
            "runs omit this flag and always exit 0."
        ),
    )
    parser.add_argument(
        "--mode",
        choices=["gaps", "upgrade", "all", "audit"],
        default=None,
        help=(
            "What to translate: 'gaps' = only untranslated strings; 'upgrade' = "
            "gaps PLUS re-translate low-quality (Google/English) strings to NLLB; "
            "'all' = force re-translate everything except manual overrides; "
            "'audit' = translate nothing, only write the gaps + low-quality report "
            "to file. Omit on a terminal to choose from a menu (which also offers "
            "an abort option); defaults to 'gaps' non-interactively."
        ),
    )
    # Key-management subcommands — operate on the cache + provenance files only,
    # no translation run. Each returns immediately.
    parser.add_argument(
        "--show", nargs="+", metavar="LOCALE [FILTER]",
        help="List cached translations for LOCALE (English -> translation [engine]); optional FILTER substring.",
    )
    parser.add_argument(
        "--set", nargs=3, metavar=("LOCALE", "ENGLISH", "TRANSLATION"),
        help="Manually override one translation (provenance 'manual'; never re-translated).",
    )
    parser.add_argument(
        "--unset", nargs=2, metavar=("LOCALE", "ENGLISH"),
        help="Remove one cached translation so it is re-translated on the next run.",
    )
    return parser.parse_args()


def split_locales(raw: str) -> list[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


def compute_stats(
    mapping: dict[str, str], dict_table: dict[str, str]
) -> tuple[LocaleStats, list[str]]:
    """Return (stats, sorted missing-list) for a single locale's mapping.

    *dict_table* is the curated dictionary for the locale. When the dictionary
    explicitly stores ``"X": "X"``, that is a deliberate human decision to
    leave the string in English (proper nouns like ``OWASP``, brand names,
    filenames). Those entries count as translated, not missing — otherwise
    the audit keeps flagging strings the user already triaged.
    """
    translated = 0
    skipped = 0
    missing: list[str] = []
    for src, out in mapping.items():
        if out != src:
            translated += 1
            continue
        # Output equals source. Three possibilities, in priority order:
        #   1. Curated passthrough: dict explicitly says "leave as English".
        #   2. Intentionally trivial: single letter / punctuation / pure {placeholder}.
        #   3. Genuinely missing: no dict entry and MT off/failed.
        if dict_table.get(src) == src:
            translated += 1
        elif should_skip_machine_translate(src):
            skipped += 1
        else:
            missing.append(src)
    return (
        LocaleStats(
            total=len(mapping),
            translated=translated,
            skipped=skipped,
            missing=len(missing),
        ),
        sorted(missing),
    )


def _pct(n: int, total: int) -> str:
    if total <= 0:
        return "  0%"
    return f"{(100 * n / total):4.0f}%"


def print_summary(stats_by_locale: dict[str, LocaleStats]) -> None:
    """Render a per-locale coverage table to stdout (colored if TTY)."""
    print()
    print(c("bold", "i18n translation audit"))
    header = f"  {'locale':<6}  {'total':>5}  {'translated':>10}  {'skipped':>7}  {'missing':>7}  {'coverage':>8}"
    print(c("gray", header))
    print(c("gray", "  " + "-" * (len(header) - 2)))

    grand = LocaleStats(total=0, translated=0, skipped=0, missing=0)
    for locale, s in stats_by_locale.items():
        # ``coverage`` here means: of strings that *needed* translation
        # (total minus intentionally skipped), how many actually got one.
        needs = max(0, s.total - s.skipped)
        coverage = _pct(s.translated, needs)
        missing_str = str(s.missing)
        missing_colored = c("green" if s.missing == 0 else "yellow", f"{missing_str:>7}")
        translated_colored = c("green", f"{s.translated:>10}")
        print(
            f"  {c('cyan', f'{locale:<6}')}  {s.total:>5}  {translated_colored}  "
            f"{s.skipped:>7}  {missing_colored}  {coverage:>8}"
        )
        grand.total += s.total
        grand.translated += s.translated
        grand.skipped += s.skipped
        grand.missing += s.missing

    print(c("gray", "  " + "-" * (len(header) - 2)))
    needs_total = max(0, grand.total - grand.skipped)
    total_coverage = _pct(grand.translated, needs_total)
    print(
        f"  {c('bold', 'TOTAL '):<6}  {grand.total:>5}  "
        f"{c('green', f'{grand.translated:>10}')}  "
        f"{grand.skipped:>7}  "
        f"{c('green' if grand.missing == 0 else 'yellow', f'{grand.missing:>7}')}  "
        f"{total_coverage:>8}"
    )


def print_missing_samples(missing_by_locale: dict[str, list[str]], sample_size: int = 3) -> None:
    """List the first few missing strings per affected locale (terminal preview)."""
    affected = {k: v for k, v in missing_by_locale.items() if v}
    if not affected:
        print()
        print(c("green", "  All requested locales fully translated."))
        return
    print()
    print(c("bold", "Locales with missing translations (sample):"))
    for locale, missing in affected.items():
        preview = ", ".join(repr(m[:60]) for m in missing[:sample_size])
        more = f" (+{len(missing) - sample_size} more)" if len(missing) > sample_size else ""
        print(f"  {c('cyan', locale)} {c('yellow', f'[{len(missing)}]')}: {preview}{more}")


def _invert_missing(missing_by_locale: dict[str, list[str]]) -> list[tuple[str, list[str]]]:
    """Return [(english, [locales missing it])] sorted by miss-count desc, then alphabetical.

    The high-count rows are the highest-leverage fixes: one dictionary entry
    can resolve a string across many locales at once.
    """
    rev: dict[str, list[str]] = {}
    for locale, strings in missing_by_locale.items():
        for src in strings:
            rev.setdefault(src, []).append(locale)
    for locales in rev.values():
        locales.sort()
    return sorted(rev.items(), key=lambda kv: (-len(kv[1]), kv[0]))


def _escape_for_python_string(text: str) -> str:
    """Escape *text* so it can sit inside a Python double-quoted string literal."""
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def _append_crossreverse_section(lines: list[str], inverted: list[tuple[str, list[str]]]) -> None:
    lines.append("## Cross-locale missing — most-missed first")
    lines.append("")
    lines.append("One row per unique English string. The `locales` column lists every locale that lacks a translation for it. Rows at the top are the highest-leverage fixes — a single dictionary entry covering an N-locale string resolves N gaps.")
    lines.append("")
    lines.append("| Missing in | English | Locales |")
    lines.append("|---:|---|---|")
    for src, locales in inverted[:1000]:
        preview = src.replace("|", "\\|").replace("\n", "\\n")
        lines.append(f"| {len(locales)} | `{preview}` | {', '.join(f'`{l}`' for l in locales)} |")
    if len(inverted) > 1000:
        lines.append(f"| | ... and {len(inverted) - 1000} more unique strings | |")
    lines.append("")


def _append_paste_ready_section(lines: list[str], missing_by_locale: dict[str, list[str]]) -> None:
    lines.append("## Paste-ready dictionary stubs")
    lines.append("")
    lines.append("Drop these into `extension/scripts/i18n/dictionaries.py` under the matching locale key, then fill in each right-hand value. After editing, re-run `generate_translations.py` to regenerate the locale JSON.")
    lines.append("")
    for locale, missing in missing_by_locale.items():
        if not missing:
            continue
        lines.append(f"### `{locale}` — {len(missing)} entries")
        lines.append("")
        lines.append("```python")
        for src in missing:
            lines.append(f'    "{_escape_for_python_string(src)}": "",')
        lines.append("```")
        lines.append("")


def _append_low_quality_section(
    lines: list[str], low_quality_by_locale: dict[str, list[str]]
) -> None:
    """List cached entries that rank below NLLB (Google/English/legacy provenance)
    and would be re-translated by mode `[2] upgrade`. A locale whose primary engine
    is not NLLB has nothing better to upgrade to, so it never appears here."""
    lines.append("## Low-quality translations (upgrade candidates)")
    lines.append("")
    affected = {k: v for k, v in low_quality_by_locale.items() if v}
    if not affected:
        lines.append("- None — no cached entry ranks below NLLB for the requested locales.")
        lines.append("")
        return
    lines.append(
        "These came from the Google/English/legacy engines and would be "
        "re-translated via NLLB by mode `[2] upgrade`. Each row is a source "
        "string still served by a sub-NLLB translation."
    )
    lines.append("")
    for locale, entries in affected.items():
        lines.append(f"### `{locale}` — {len(entries)} low-quality")
        lines.append("")
        for src in entries[:500]:
            preview = src.replace("\n", "\\n")
            lines.append(f"- `{preview}`")
        if len(entries) > 500:
            lines.append(f"- ... and {len(entries) - 500} more")
        lines.append("")


def write_audit_report(
    stats_by_locale: dict[str, LocaleStats],
    missing_by_locale: dict[str, list[str]],
    report_path: Path,
    low_quality_by_locale: dict[str, list[str]] | None = None,
) -> None:
    """Write the full audit (counts + every missing string + actionable stubs) to a markdown file.

    When *low_quality_by_locale* is supplied (audit-only mode), an extra section
    lists the sub-NLLB cached entries an 'upgrade' run would re-translate. Regular
    translation runs pass None and omit that section.
    """
    lines: list[str] = []
    lines.append("# i18n Translation Audit")
    lines.append("")
    lines.append(f"Generated: {datetime.now(timezone.utc).isoformat(timespec='seconds')}")
    lines.append("")
    lines.append("| Locale | Total | Translated | Skipped | Missing | Coverage |")
    lines.append("|---|---:|---:|---:|---:|---:|")
    for locale, s in stats_by_locale.items():
        needs = max(0, s.total - s.skipped)
        coverage = _pct(s.translated, needs).strip()
        lines.append(
            f"| `{locale}` | {s.total} | {s.translated} | {s.skipped} | {s.missing} | {coverage} |"
        )
    lines.append("")
    lines.append("## Definitions")
    lines.append("")
    lines.append("- **Total**: unique English strings collected from `package.nls.json` and `src/i18n/locales/en.json`.")
    lines.append("- **Translated**: locale output differs from source English.")
    lines.append("- **Skipped**: source is a single letter, punctuation-only, or pure `{placeholder}` — intentionally unchanged.")
    lines.append("- **Missing**: source needs translation but came back identical (no dictionary entry, MT off or failed).")
    lines.append("- **Coverage**: `Translated / (Total - Skipped)`.")
    lines.append("")

    # Low-quality block sits before the missing-strings early-return so it is
    # emitted even when every locale is gap-free (an upgrade can still be due).
    if low_quality_by_locale is not None:
        _append_low_quality_section(lines, low_quality_by_locale)

    affected = {k: v for k, v in missing_by_locale.items() if v}
    if not affected:
        lines.append("## Missing strings")
        lines.append("")
        lines.append("- None — all locales fully covered.")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return

    # High-leverage view first: fix strings missing in many locales before the per-locale dumps.
    _append_crossreverse_section(lines, _invert_missing(affected))

    # Per-locale lists, paste-ready dict stubs, then plain bulleted lists for grep.
    _append_paste_ready_section(lines, affected)

    lines.append("## Per-locale missing (plain list)")
    lines.append("")
    for locale, missing in affected.items():
        lines.append(f"### `{locale}` — {len(missing)} missing")
        lines.append("")
        for src in missing[:500]:
            preview = src.replace("\n", "\\n")
            lines.append(f"- `{preview}`")
        if len(missing) > 500:
            lines.append(f"- ... and {len(missing) - 500} more")
        lines.append("")

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_fallback_report(report_path: Path) -> int:
    """Write the per-string NLLB-fallback report and return its entry count.

    Names every string NLLB could not translate (served by Google, or left
    English) plus the over-gate inputs it could not split. This is the visibility
    the silent fallback lacked: a human can act on each — add a dictionary
    override, reword the source, or accept the Google value — instead of a count.
    """
    served = fallback_log()
    try:
        import nllb_engine
        unsplittable = nllb_engine.long_inputs()
    except ImportError:
        unsplittable = []
    if not served and not unsplittable:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text("# NLLB fallback report\n\nNo fallbacks — NLLB translated every string.\n", encoding="utf-8")
        return 0

    lines = ["# NLLB fallback report", ""]
    google = [(loc, t) for loc, eng, t in served if eng == "google"]
    english = [(loc, t) for loc, eng, t in served if eng == "english"]
    lines.append(f"- Served by Google (NLLB declined): {len(google)}")
    lines.append(f"- Left English (no engine produced a translation): {len(english)}")
    lines.append(f"- Over the token gate and unsplittable: {len(unsplittable)}")
    lines.append("")

    def _block(title: str, rows: list[tuple]) -> None:
        if not rows:
            return
        lines.append(f"## {title} ({len(rows)})")
        lines.append("")
        for row in rows:
            loc = row[0]
            text = row[-1]
            preview = text.replace("\n", " ⏎ ")
            if len(preview) > 160:
                preview = preview[:157] + "…"
            extra = f" [{row[1]} tokens]" if len(row) == 3 and isinstance(row[1], int) else ""
            lines.append(f"- `{loc}`{extra}: {preview}")
        lines.append("")

    _block("Left English — fix these first", english)
    _block("Over token gate, unsplittable", unsplittable)
    _block("Served by Google fallback", google)

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(served) + len(unsplittable)


def _install_sigint() -> None:
    """First Ctrl-C requests a graceful stop (finish current string, flush cache +
    provenance, exit); a second Ctrl-C restores the default handler for an
    immediate abort. Lets the operator cancel a multi-hour run without losing
    work or seeing a traceback."""
    def handler(signum: int, frame: object) -> None:  # noqa: ARG001
        if stop_requested():
            signal.signal(signal.SIGINT, signal.SIG_DFL)
            raise KeyboardInterrupt
        request_stop()
        sys.stderr.write(c(
            "yellow",
            "\n  Stop requested — finishing the current string, saving, then exiting. "
            "Ctrl-C again to force-quit.\n",
        ))
        sys.stderr.flush()
    signal.signal(signal.SIGINT, handler)


def _choose_mode(args_mode: str | None) -> str:
    """Resolve translation mode: explicit --mode, else a TTY menu, else 'gaps'."""
    if args_mode:
        return args_mode
    if not sys.stdin.isatty():
        return "gaps"
    print(c("bold", "\nTranslation mode:"))
    print("  [1] Close gaps only (translate untranslated strings)  [default]")
    print("  [2] Close gaps + upgrade low-quality (re-translate Google/English -> NLLB)")
    print("  [3] Re-translate everything (force; keeps manual overrides)")
    print("  [4] Audit only — write gaps + low-quality report to file, translate nothing")
    print("  [a] Abort — exit now, translate nothing, change no files")
    try:
        raw = input("  Choose [1/2/3/4/a]: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        # Treat an EOF/Ctrl-C at the prompt as an abort, not a silent default run.
        raw = "a"
    return {"2": "upgrade", "3": "all", "4": "audit", "a": "abort"}.get(raw, "gaps")


def _source_strings(root: Path) -> list[str]:
    """All unique English source strings (package.nls + runtime en.json)."""
    unique: set[str] = set()
    collect_unique_strings(read_json(root / "package.nls.json"), unique)
    collect_unique_strings(read_json(root / "src" / "i18n" / "locales" / "en.json"), unique)
    return sorted(unique)


def _run_key_command(args: argparse.Namespace, root: Path) -> int:
    """Handle --show / --set / --unset. Operates on the cache + provenance files
    only — no translation run. Returns an exit code."""
    cache = load_mt_cache()
    load_provenance()

    if args.set:
        locale, english, translation = args.set
        cache_set(cache, locale, english, translation)
        save_mt_cache(cache)
        save_provenance()
        print(c("green", f"  set [{locale}] {english!r} -> {translation!r} (manual)"))
        return 0

    if args.unset:
        locale, english = args.unset
        existed = cache_unset(cache, locale, english)
        save_mt_cache(cache)
        save_provenance()
        print(c("green" if existed else "yellow",
                f"  {'removed' if existed else 'no cached entry'}: [{locale}] {english!r}"))
        return 0

    # --show LOCALE [FILTER]
    locale = args.show[0]
    needle = args.show[1] if len(args.show) > 1 else None
    rows = 0
    for english in _source_strings(root):
        if needle and needle.lower() not in english.lower():
            continue
        value, prov = cache_lookup(cache, locale, english)
        if value is None:
            continue
        print(f"  [{prov or '?'}] {english[:48]!r} -> {value[:60]!r}")
        rows += 1
    print(c("bold", f"  {rows} cached entr{'y' if rows == 1 else 'ies'} for {locale}"
                    + (f" matching {needle!r}" if needle else "")))
    return 0


def _run_audit(
    locales: list[str],
    sorted_unique: list[str],
    mt_cache: dict[str, str],
    root: Path,
    *,
    fail_on_missing: bool = False,
) -> int:
    """Audit-only path: report translation gaps and low-quality (upgrade) entries
    WITHOUT translating, pruning, or writing any locale file. Reads the curated
    dictionaries + existing MT cache only — zero network calls — so it is safe to
    run anytime to preview what a gaps/upgrade run would change.

    With *fail_on_missing* (the publish pipeline's coverage gate) the exit code is
    non-zero when any gap remains, so the gate can prompt the operator without the
    audit ever translating anything itself.
    """
    print(
        f"[{c('blue', 'i18n')}] mode: {c('cyan', 'audit only')} "
        "(no translation, no files changed)",
        flush=True,
    )
    stats_by_locale: dict[str, LocaleStats] = {}
    missing_by_locale: dict[str, list[str]] = {}
    low_quality_by_locale: dict[str, list[str]] = {}
    for locale in locales:
        dict_table = TRANSLATIONS.get(locale, {})
        # Build the mapping from dictionary + cache ONLY (never machine_translate),
        # so the audit makes no network calls. compute_stats then reads a gap as
        # "output still equals the English source".
        mapping: dict[str, str] = {}
        for src in sorted_unique:
            if src and src in dict_table:
                mapping[src] = dict_table[src]
                continue
            value, _prov = cache_lookup(mt_cache, locale, src)
            mapping[src] = value if value is not None else src
        stats, missing = compute_stats(mapping, dict_table)
        stats_by_locale[locale] = stats
        missing_by_locale[locale] = missing
        low_quality_by_locale[locale] = low_quality_entries(
            mt_cache, locale, sorted_unique, dict_table
        )
        lq = len(low_quality_by_locale[locale])
        miss_tag = (
            c("green", "ok") if stats.missing == 0 else c("yellow", f"{stats.missing} missing")
        )
        lq_tag = c("gray", "0 low-quality") if lq == 0 else c("yellow", f"{lq} low-quality")
        print(f"[{c('blue', 'i18n')}] {c('cyan', locale)}: {miss_tag}, {lq_tag}", flush=True)

    print_summary(stats_by_locale)
    print_missing_samples(missing_by_locale)
    report_path = root / "reports" / "i18n_translation_audit.md"
    write_audit_report(stats_by_locale, missing_by_locale, report_path, low_quality_by_locale)
    total_missing = sum(s.missing for s in stats_by_locale.values())
    total_lq = sum(len(v) for v in low_quality_by_locale.values())
    print()
    print(c("bold", f"  Audit log ({total_missing} gaps, {total_lq} low-quality):"))
    print(f"    {c('blue', str(report_path))}")
    print(c("gray", "    Sections: low-quality -> cross-locale rollup -> paste-ready stubs -> per-locale lists."))

    # Coverage gate (publish only): a non-zero exit lets the caller prompt the
    # operator. The audit still translated nothing — closing the gap is a
    # separate, explicit translation run or a dictionaries.py edit.
    if fail_on_missing and total_missing > 0:
        print()
        print(
            c("red", f"  Coverage gate FAILED: {total_missing} missing translation(s) "
                     "across locales. This audit translated nothing — add curated "
                     "entries to dictionaries.py (or run the translator separately) "
                     "and re-audit."),
            file=sys.stderr,
        )
        return 1
    return 0


# Non-TTY cadence: how many strings between plain progress lines when stdout is
# piped (CI, log capture), where a carriage-return animation would corrupt the
# captured log. Kept independent of mt_fallback's internal checkpoint constant so
# the two can be tuned separately.
_PROGRESS_LOG_EVERY = 25


def _fmt_duration(seconds: float) -> str:
    """Compact ``mm:ss`` (or ``h:mm:ss`` past an hour) for an ETA/elapsed value.

    Returns ``--:--`` for a nonpositive or NaN input so an unknown ETA (rate not
    yet established, division by zero) renders as a placeholder rather than ``0:00``,
    which would falsely read as "done".
    """
    if seconds <= 0 or seconds != seconds:  # nonpositive, or NaN (x != x)
        return "--:--"
    total = int(seconds)
    hours, rem = divmod(total, 3600)
    minutes, secs = divmod(rem, 60)
    if hours:
        return f"{hours:d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


class _TranslationProgress:
    """Live per-locale throughput + ETA reporter, driven by the prefetch loop.

    The MT phase is otherwise silent for minutes — NLLB runs ~1-3 strings/sec, so
    a 1000+ string locale shows nothing between "translating N strings" and the
    final "wrote" line. This redraws one carriage-return line with words-per-minute
    and a remaining-time estimate so the operator can see the run is alive and how
    long it has left.

    Output goes to stdout because that is the handle term_color enabled Windows VT
    processing on (so ``\\r`` and the clear-to-EOL escape render), and it keeps the
    bar consistent with the surrounding ``[i18n]`` lines. On a non-TTY stdout (CI /
    piped capture) it emits a plain newline-terminated line every
    ``_PROGRESS_LOG_EVERY`` strings instead, so the animation never corrupts a log.

    ETA extrapolates from elapsed time and the fraction of strings done rather than
    the word rate: word counts per string vary wildly (a 2-word label vs a 60-word
    paragraph), which would make a word-rate ETA jump around. Words-per-minute is
    still reported from the word tally, since that is the operator-requested metric.
    """

    _BAR_WIDTH = 24

    def __init__(self, locale: str) -> None:
        self._locale = locale
        self._words = 0
        self._start = time.monotonic()
        self._last_render = 0.0
        # Color/VT was enabled against stdout, so gate the animation on the same
        # handle; a piped stdout falls back to plain checkpoint lines.
        self._tty = sys.stdout.isatty()

    def __call__(self, done: int, total: int, source: str) -> None:
        self._words += len(source.split())
        now = time.monotonic()
        final = done >= total
        if self._tty:
            # Throttle redraws so a fast Google run (~5/s) doesn't thrash the line;
            # always draw the final frame so the completed bar is left on screen.
            if not final and (now - self._last_render) < 0.2:
                return
        elif not final and done % _PROGRESS_LOG_EVERY != 0:
            # Non-TTY: only at checkpoints and on the last string.
            return
        self._last_render = now

        elapsed = now - self._start
        wpm = (self._words / elapsed * 60.0) if elapsed > 0 else 0.0
        rate = (done / elapsed) if elapsed > 0 else 0.0
        eta = ((total - done) / rate) if rate > 0 else 0.0

        line = (
            f"  {c('cyan', self._locale)} {self._bar(done, total)} "
            f"{done}/{total}  {c('gray', f'{wpm:,.0f} wpm')}  "
            f"{c('gray', f'ETA {_fmt_duration(eta)}')}"
        )
        if self._tty:
            # \r returns to column 0; \033[K clears to EOL so a shorter later line
            # (fewer digits, smaller ETA) can't leave stale trailing characters.
            sys.stdout.write("\r" + line + "\033[K")
            if final:
                sys.stdout.write("\n")
        else:
            sys.stdout.write(line + "\n")
        sys.stdout.flush()

    def _bar(self, done: int, total: int) -> str:
        if total <= 0:
            return "[" + " " * self._BAR_WIDTH + "]"
        filled = min(self._BAR_WIDTH, int(self._BAR_WIDTH * done / total))
        return "[" + "#" * filled + "-" * (self._BAR_WIDTH - filled) + "]"


def main() -> int:
    args = parse_args()

    root = Path(__file__).resolve().parents[2]

    # Key-management subcommands operate on the cache only — no translation run.
    if args.show or args.set or args.unset:
        return _run_key_command(args, root)

    locales = split_locales(args.locales)
    if not locales:
        print(c("red", "No locales provided."))
        return 1

    # Graceful Ctrl-C + persistent provenance for the translation run.
    _install_sigint()
    load_provenance()
    mode = _choose_mode(args.mode)

    if mode == "abort":
        # Interactive escape hatch ([a] at the menu): nothing translated, no cache
        # pruned, no locale file rewritten. Exit 0 — an abort is not a failure.
        print(c("yellow", "  Aborted — nothing translated, no files changed."))
        return 0

    package_en_path = root / "package.nls.json"
    runtime_en_path = root / "src" / "i18n" / "locales" / "en.json"

    package_en = read_json(package_en_path)
    runtime_en = read_json(runtime_en_path)

    mt_cache = load_mt_cache()
    unique_en: set[str] = set()
    collect_unique_strings(package_en, unique_en)
    collect_unique_strings(runtime_en, unique_en)
    sorted_unique = sorted(unique_en)

    if mode == "audit":
        # Read-only path: report gaps + low-quality entries to file and exit
        # before any MT engine is touched. Honors --fail-on-missing so the publish
        # coverage gate can run an audit (never a translation) and still gate.
        return _run_audit(
            locales, sorted_unique, mt_cache, root, fail_on_missing=args.fail_on_missing
        )

    # Announce the active MT engine up front so a silent Google downgrade (NLLB
    # model not installed) is visible before a multi-hour run starts.
    print(f"[{c('blue', 'i18n')}] {describe_engine_availability()}", flush=True)
    mode_label = {
        "gaps": "gaps only", "upgrade": "gaps + upgrade low-quality to NLLB",
        "all": "force re-translate all",
    }[mode]
    print(f"[{c('blue', 'i18n')}] mode: {c('cyan', mode_label)}  (Ctrl-C to stop gracefully)", flush=True)

    # Fresh engine tally + over-gate input log so the report reflects only this run.
    reset_engine_stats()
    try:
        import nllb_engine
        nllb_engine.reset_long_inputs()
    except ImportError:
        pass
    stats_by_locale: dict[str, LocaleStats] = {}
    missing_by_locale: dict[str, list[str]] = {}
    interrupted_locale: str | None = None

    try:
        for locale in locales:
            # Cooperative stop: a graceful Ctrl-C breaks here between locales (and
            # prefetch breaks between strings), so the partial cache already saved
            # is consistent and the run resumes cleanly next time.
            if stop_requested():
                break
            dict_table = TRANSLATIONS.get(locale, {})
            # Apply the chosen mode by pruning the cache before counting gaps:
            # 'upgrade' drops low-quality (Google/English) entries so NLLB redoes
            # them; 'all' drops everything except manual overrides. 'gaps' prunes
            # nothing. Each pruned entry becomes a gap the prefetch below refills.
            if mode == "upgrade":
                n = prune_low_quality(mt_cache, locale, sorted_unique, dict_table)
                if n:
                    print(f"[{c('blue', 'i18n')}] {c('cyan', locale)}: upgrade -> cleared "
                          f"{n} low-quality entr{'y' if n == 1 else 'ies'} for re-translation", flush=True)
            elif mode == "all":
                n = prune_all(mt_cache, locale, sorted_unique, dict_table)
                if n:
                    print(f"[{c('blue', 'i18n')}] {c('cyan', locale)}: force -> cleared "
                          f"{n} entr{'y' if n == 1 else 'ies'} for re-translation", flush=True)
            pending = count_pending_translations(
                locale, sorted_unique, cache=mt_cache, dict_table=dict_table
            )
            # ``prefetch`` is just the MT phase — explicit count tells the user
            # how many network calls are about to happen (or none, if all cached).
            if pending == 0:
                phase = c("gray", "all cached, mapping…")
            else:
                engine = active_engine_name(locale)
                engine_label = {"nllb": "NLLB", "google": "Google"}.get(engine or "", "MT")
                phase = c("gray", f"translating {pending} new strings via {engine_label}…")
            print(f"[{c('blue', 'i18n')}] {c('cyan', locale)}: {phase}", flush=True)

            # Live words-per-minute + ETA bar for the otherwise-silent MT phase.
            # Only when there is real work to translate; an all-cached locale
            # (pending == 0) prints nothing extra.
            progress = _TranslationProgress(locale) if pending else None
            prefetch_machine_translations(
                locale,
                sorted_unique,
                cache=mt_cache,
                dict_table=dict_table,
                progress=progress,
            )
            # Engine mix for the strings this run actually translated — makes a
            # silent NLLB->Google fallback visible instead of hidden behind the
            # "NLLB ready" banner. ('cached' here = warmed earlier this same run.)
            mix = engine_stats_for(locale)
            real = {k: v for k, v in mix.items() if k != "cached"}
            if real:
                parts = ", ".join(f"{k}:{v}" for k, v in sorted(real.items()))
                print(f"[{c('blue', 'i18n')}] {c('cyan', locale)}: engines -> {parts}", flush=True)

            translator = HybridTranslator(locale, mt_cache)
            # One ``translate_text`` per distinct English string (MT + cache), not per JSON leaf.
            mapping = {s: translator.translate_text(s) for s in sorted_unique}
            package_out = apply_string_map(package_en, mapping)
            runtime_out = apply_string_map(runtime_en, mapping)

            package_out_path = root / f"package.nls.{locale}.json"
            runtime_out_path = root / "src" / "i18n" / "locales" / f"{locale}.json"

            write_json(package_out_path, package_out)
            write_json(runtime_out_path, runtime_out)

            stats, missing = compute_stats(mapping, dict_table)
            stats_by_locale[locale] = stats
            missing_by_locale[locale] = missing
            # Persist after every locale so a Ctrl-C in a later locale cannot
            # discard already-paid-for MT calls. Cheap (two small JSON writes).
            save_mt_cache(mt_cache)
            save_provenance()

            missing_tag = (
                c("green", "ok") if stats.missing == 0 else c("yellow", f"{stats.missing} missing")
            )
            print(
                f"[{c('blue', 'i18n')}] {c('cyan', locale)}: "
                f"{c('green', 'wrote')} {package_out_path.name}, {runtime_out_path.name} "
                f"({stats.translated}/{max(1, stats.total - stats.skipped)} translated, {missing_tag})",
                flush=True,
            )
    except KeyboardInterrupt:
        # Hard abort (second Ctrl-C). Capture which locale was in flight so the
        # user can resume meaningfully; its stats are not in stats_by_locale yet.
        interrupted_locale = locales[len(stats_by_locale)] if len(stats_by_locale) < len(locales) else None
        save_mt_cache(mt_cache)
        save_provenance()

    # Cooperative stop (first Ctrl-C): the loop broke cleanly, no exception. Flush
    # and report the same way as a hard interrupt so the run is resumable.
    if stop_requested() and interrupted_locale is None:
        interrupted_locale = locales[len(stats_by_locale)] if len(stats_by_locale) < len(locales) else None
        save_mt_cache(mt_cache)
        save_provenance()

    if stats_by_locale:
        print_summary(stats_by_locale)
        print_missing_samples(missing_by_locale)
        report_path = root / "reports" / "i18n_translation_audit.md"
        write_audit_report(stats_by_locale, missing_by_locale, report_path)
        total_missing = sum(s.missing for s in stats_by_locale.values())
        print()
        # Make this line easy to find in the scrollback when scanning for "what to fix".
        print(c("bold", f"  Missing-translations log ({total_missing} entries):"))
        print(f"    {c('blue', str(report_path))}")
        print(c("gray", "    Sections: cross-locale rollup -> paste-ready stubs -> per-locale lists."))

        # Per-string NLLB-fallback report: names exactly what NLLB could not do
        # (Google-served, English-left, unsplittable) so fallbacks are visible and
        # actionable instead of hidden behind the engine-mix counts.
        fb_path = root / "reports" / "i18n_nllb_fallbacks.md"
        fb_count = write_fallback_report(fb_path)
        if fb_count:
            print()
            print(c("bold", f"  NLLB fallback report ({fb_count} string(s) NLLB did not translate):"))
            print(f"    {c('blue', str(fb_path))}")

    if interrupted_locale is not None:
        print()
        print(
            c("yellow", f"  Interrupted during '{interrupted_locale}'. "
                       f"MT cache saved; rerun the same command to resume."),
            file=sys.stderr,
        )
        # Standard convention: shells treat 128 + SIGINT(2) = 130 as Ctrl-C exit.
        return 130

    # Coverage gate (publish only): block the release rather than ship English
    # placeholders in a translated bundle. Dev runs omit --fail-on-missing and
    # always succeed so iterating on English strings is never gated.
    total_missing = sum(s.missing for s in stats_by_locale.values())
    if args.fail_on_missing and total_missing > 0:
        print()
        print(
            c("red", f"  Coverage gate FAILED: {total_missing} missing translation(s) "
                     "across locales. Add curated entries to dictionaries.py (or a "
                     '"X": "X" passthrough for words identical in the target language) '
                     "and rerun, then commit the regenerated locale JSON."),
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
