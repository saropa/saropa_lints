#!/usr/bin/env python3
"""Snapshot pub.dev facts for every tracked package, and apply them to
``extension/src/vibrancy/data/known_issues.json``.

Two subcommands, deliberately separate so the (slow, networked) fetch and the
(fast, offline, reviewable) data update can be run independently:

``snapshot``
    Query pub.dev for each tracked package (``/api/packages/<n>``,
    ``/api/packages/<n>/score`` and a HEAD on the archive for its size) and
    write a cached JSON snapshot including ``fetched_at``. The snapshot is a
    source of truth other tools may read (default:
    ``reports/pubdev_snapshot.json`` - ``reports/*`` is gitignored).

``apply``
    Read a snapshot (no network) and refresh ONLY machine-derivable fields of
    known_issues.json entries that already carry them: ``lastUpdated``,
    ``pubPoints``, ``archiveSizeBytes``/``archiveSizeMB``, ``verifiedPublisher``
    and ``platforms``; plus ``as_of`` for every entry re-verified against the
    snapshot. Hand-written prose (``reason``, ``migrationNotes``), ``status``
    and ``replacement`` are NEVER rewritten - status-relevant changes
    (discontinued, replacedBy, 404, revived, stale, license drift) are printed as a
    FLAGGED report for a human to decide. Key order and formatting are
    preserved so the git diff stays minimal.

    Flags are printed as ``[kind] message`` and summarised per kind:

    * ``revived``: unbounded ``end_of_life`` released <12 months ago.
    * ``stale``: ``active`` 12-24 months old (maintenance_mode candidate) or
      >24 (end_of_life candidate) AND >=1 corroborating weak signal
      (pubPoints <100, SDK upper bound <3.0.0, likes <100). pubPoints >=140
      is exempt (finished mature library; mirrors status-classifier.ts).
      The message lists the signals that fired.
    * ``bounded-includes-latest`` / ``bounded-min-gt-max`` /
      ``bounded-above-all`` / ``bounded-template-reason`` /
      ``bounded-recent-release`` (INFO only): re-checks of
      appliesToMinVersion/MaxVersion entries. ``appliesToMaxVersion`` is
      EXCLUSIVE (matches the extension), so max > latest means the entry still
      covers the newest release.
    * ``replacement-404`` / ``replacement-discontinued`` /
      ``replacement-chain`` / ``replacement-cycle``: replacement targets that
      look like package names (same rule as isReplacementPackageName:
      ``^[a-z0-9_]+$``); freeform replacements never trigger the
      ``replacedBy-mismatch`` flag.
    * ``dead-data`` (informational): tracked names that 404, SDK packages
      (flutter_localizations, flutter_web_plugins) or names with
      parentheses/suffix aliases, unless listed in SYNTHETIC_NAMES.
    * ``stale-as-of``: entries NOT refreshed this run whose as_of is >90 days
      before --as-of. ``--strict`` exits 1 if any exist.
    * ``retracted-latest`` / ``advisories``: from snapshot format 2.

    as_of is only ever refreshed for entries whose snapshot status is ``ok``
    (verified). ``--refresh-as-of-only-verified`` is stricter: also leave
    as_of alone for entries that raised any non-INFO flag this run.

Snapshot ``format`` is 2 (adds ``origin``, ``allVersions``, ``retracted``,
``advisories``); apply still reads format-1 snapshots (missing fields are
simply skipped). Replacement targets are snapshotted with origin
``replacement``. One extra request per package (``/advisories``) is made;
concurrency is 8 by default.

Tracked packages come from ``TRACKED_SOURCES`` (currently: names in
known_issues.json). Add a function returning an iterable of names to extend
it, or pass ``--package NAME`` (repeatable) / ``--packages-file FILE``.

Examples (from the repo root)::

    python scripts/pubdev_snapshot.py snapshot
    python scripts/pubdev_snapshot.py snapshot --only analyzer --only meta
    python scripts/pubdev_snapshot.py snapshot --concurrency 4 --retries 5
    python scripts/pubdev_snapshot.py apply --dry-run
    python scripts/pubdev_snapshot.py apply --only analyzer
    python scripts/pubdev_snapshot.py apply --snapshot path/to/old.json
    python scripts/pubdev_snapshot.py apply --as-of 2026-09-19
    python scripts/pubdev_snapshot.py selftest

``snapshot --only`` merges into an existing snapshot rather than replacing it.
Related: ``check_known_issues_freshness.py`` (lifecycle-claim audit).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Iterable

REPO = Path(__file__).resolve().parent.parent
KNOWN_ISSUES = REPO / "extension/src/vibrancy/data/known_issues.json"
DEFAULT_SNAPSHOT = REPO / "reports/pubdev_snapshot.json"
VALID_NAME = re.compile(r"^[a-z0-9_]+$")  # excludes synthetic "x (Orig)" names
SNAPSHOT_FORMAT = 2
SDK_PACKAGES = {"flutter_localizations", "flutter_web_plugins", "flutter_test", "flutter"}
# Intentionally virtual tracked names (skipped by the dead-data flag).
SYNTHETIC_NAMES: set[str] = set()
STALE_AS_OF_DAYS = 90
RETRACT_WINDOW = 10
# Generic reasons that say nothing package-specific; bounded entries using them
# deserve a human re-check.
TEMPLATE_REASONS = (
    "fails android 14",
    "fundamentally broken",
    "fundamentally incompatible",
    "fails dart 3",
    "fail dart 3",
    "fails completely",
    "completely fails",
    "totally obsolete",
    "blocks dart 3",
)
API = "https://pub.dev/api"
UA = "saropa_lints-pubdev-snapshot (+https://github.com/saropa/saropa_lints)"


# --------------------------------------------------------------------------
# Tracked-package sources (extend here)
# --------------------------------------------------------------------------
def _known_issue_names() -> Iterable[str]:
    data = json.loads(KNOWN_ISSUES.read_text(encoding="utf-8"))
    return [e["name"] for e in data["issues"]]


def is_replacement_package_name(r: str | None) -> bool:
    """Mirror of isReplacementPackageName in extension/src/vibrancy/scoring/known-issues.ts."""
    return bool(r) and re.fullmatch(r"[a-z0-9_]+", r.strip()) is not None


def _replacement_names() -> Iterable[str]:
    data = json.loads(KNOWN_ISSUES.read_text(encoding="utf-8"))
    return [
        e["replacement"].strip()
        for e in data["issues"]
        if is_replacement_package_name(e.get("replacement"))
    ]


TRACKED_SOURCES: list[tuple[str, Callable[[], Iterable[str]]]] = [
    ("known_issue", _known_issue_names),
    ("replacement", _replacement_names),
]


def tracked_origins(extra: list[str]) -> dict[str, str]:
    """name -> origin tag ('known_issue' wins over 'replacement')."""
    names: dict[str, str] = {}
    for tag, src in TRACKED_SOURCES:
        for n in src():
            names.setdefault(n, tag)
    for n in extra:
        names.setdefault(n, "extra")
    return {n: o for n, o in names.items() if VALID_NAME.match(n)}


def tracked_names(extra: list[str]) -> list[str]:
    return list(tracked_origins(extra))


# --------------------------------------------------------------------------
# Fetching
# --------------------------------------------------------------------------
def _request(url: str, method: str, timeout: float, retries: int):
    """Return (status, body_bytes, headers). Retries 429/5xx/network errors
    with exponential backoff (honouring Retry-After). 404 returns (404,...)."""
    delay = 1.0
    for attempt in range(retries + 1):
        try:
            req = urllib.request.Request(url, method=method, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:  # noqa: S310
                return r.status, r.read() if method == "GET" else b"", r.headers
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return 404, b"", e.headers
            if e.code not in (429, 500, 502, 503, 504) or attempt == retries:
                return e.code, b"", e.headers
            ra = e.headers.get("Retry-After")
            time.sleep(float(ra) if ra and ra.isdigit() else delay)
        except (urllib.error.URLError, TimeoutError, OSError):
            if attempt == retries:
                return 0, b"", {}
            time.sleep(delay)
        delay *= 2
    return 0, b"", {}


def fetch_package(name: str, timeout: float, retries: int) -> dict:
    st, body, _ = _request(f"{API}/packages/{name}", "GET", timeout, retries)
    if st == 404:
        return {"status": "not_found"}
    if st != 200:
        return {"status": "error", "http": st}
    pkg = json.loads(body)
    st, body, _ = _request(f"{API}/packages/{name}/score", "GET", timeout, retries)
    if st != 200:
        return {"status": "error", "http": st}
    score = json.loads(body)
    tags = score.get("tags") or []
    latest = pkg.get("latest") or {}
    out = {
        "status": "ok",
        "version": latest.get("version"),
        "published": (latest.get("published") or "")[:10] or None,
        "isDiscontinued": bool(pkg.get("isDiscontinued")) or "is:discontinued" in tags,
        "isUnlisted": "is:unlisted" in tags,
        "replacedBy": pkg.get("replacedBy"),
        "pubPoints": score.get("grantedPoints"),
        "maxPoints": score.get("maxPoints"),
        "likes": score.get("likeCount"),
        "downloads30d": score.get("downloadCount30Days"),
        "publisher": next(
            (t[len("publisher:"):] for t in tags if t.startswith("publisher:")), None
        ),
        "platforms": sorted(
            t[len("platform:"):] for t in tags if t.startswith("platform:")
        ),
        "wasmReady": "is:wasm-ready" in tags,
        # pub.dev exposes the license only as a lowercased tag, not SPDX-cased.
        "licenseTags": sorted(
            t[len("license:"):]
            for t in tags
            if t.startswith("license:")
            and t not in ("license:fsf-libre", "license:osi-approved")
        ),
        "sdk": (latest.get("pubspec", {}).get("environment") or {}).get("sdk"),
        "archiveSizeBytes": None,
    }
    vers = pkg.get("versions") or []
    out["allVersions"] = [v.get("version") for v in vers if v.get("version")]
    recent = vers[-RETRACT_WINDOW:]
    out["retracted"] = {
        "window": len(recent),
        "latestRetracted": bool(latest.get("retracted")),
        "versions": [v["version"] for v in recent if v.get("retracted")],
    }
    st, body, _ = _request(f"{API}/packages/{name}/advisories", "GET", timeout, retries)
    out["advisories"] = None
    if st == 200:
        try:
            adv = json.loads(body).get("advisories") or []
            out["advisories"] = [a.get("id") for a in adv if isinstance(a, dict)]
            out["advisoryDetails"] = [advisory_detail(a, name, out["version"]) for a in adv if isinstance(a, dict)]
        except ValueError:
            pass
    url = latest.get("archive_url")
    if url:
        st, _, h = _request(url, "HEAD", timeout, retries)
        size = h.get("Content-Length") or h.get("x-goog-stored-content-length")
        if st == 200 and size and str(size).isdigit():
            out["archiveSizeBytes"] = int(size)
    return out


def advisory_detail(rec: dict, pkg: str, latest: str | None) -> dict:
    """Reduce an OSV record to the fields needed to judge the latest version.

    ``ranges`` is a list of ``{introduced, fixed, lastAffected}`` groups (one
    per OSV event sequence); ``latestListed`` says whether the record's
    explicit ``versions`` list names ``latest``. Malformed input is tolerated.
    """
    ranges: list[dict] = []
    listed = False
    for aff in rec.get("affected") or []:
        if not isinstance(aff, dict):
            continue
        nm = (aff.get("package") or {}).get("name")
        if nm and nm != pkg:
            continue
        if latest and latest in (aff.get("versions") or []):
            listed = True
        for r in aff.get("ranges") or []:
            if not isinstance(r, dict):
                continue
            cur: dict = {}
            for ev in r.get("events") or []:
                if not isinstance(ev, dict):
                    continue
                if ev.get("introduced") is not None:
                    if cur:
                        ranges.append(cur)
                    cur = {"introduced": str(ev["introduced"])}
                if ev.get("fixed") is not None:
                    cur["fixed"] = str(ev["fixed"])
                if ev.get("last_affected") is not None:
                    cur["lastAffected"] = str(ev["last_affected"])
            if cur:
                ranges.append(cur)
    return {"id": rec.get("id"), "summary": rec.get("summary"), "ranges": ranges, "latestListed": listed}


def advisory_status(detail: dict, latest: str | None) -> str:
    """'affected' (latest inside an unfixed range), 'fixed' (bounded ranges
    all end at/below latest) or 'unknown' (no usable range data)."""
    if not isinstance(detail, dict):
        return "unknown"
    if detail.get("latestListed"):
        return "affected"
    if not latest:
        return "unknown"
    lv = _ver(latest)
    usable = False
    for r in detail.get("ranges") or []:
        if not isinstance(r, dict) or not r.get("introduced"):
            continue
        usable = True
        if lv < _ver(r["introduced"]) and r["introduced"] != "0":
            continue
        fixed, last = r.get("fixed"), r.get("lastAffected")
        if fixed is not None and lv >= _ver(fixed):
            continue
        if last is not None and lv > _ver(last):
            continue
        return "affected"
    return "fixed" if usable else "unknown"


def cmd_snapshot(a: argparse.Namespace) -> int:
    origins = tracked_origins(a.package or [])
    if a.packages_file:
        for ln in Path(a.packages_file).read_text().splitlines():
            if VALID_NAME.match(ln.strip()):
                origins.setdefault(ln.strip(), "extra")
    names = list(origins)
    if a.only:
        names = list(dict.fromkeys(a.only))
    out_path = Path(a.output)
    snap: dict = {"packages": {}}
    if a.only and out_path.exists():
        snap = json.loads(out_path.read_text(encoding="utf-8"))
    done = 0

    def work(n: str):
        return n, fetch_package(n, a.timeout, a.retries)

    with ThreadPoolExecutor(max_workers=a.concurrency) as ex:
        for n, res in ex.map(work, names):
            res["origin"] = origins.get(n, "extra")
            snap["packages"][n] = res
            done += 1
            if done % 50 == 0:
                print(f"  {done}/{len(names)}", file=sys.stderr)
    snap["fetched_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    snap["source"] = API
    snap["format"] = SNAPSHOT_FORMAT
    counts: dict[str, int] = {}
    for n in names:
        s = snap["packages"][n]["status"]
        counts[s] = counts.get(s, 0) + 1
    if a.dry_run:
        print(f"[dry-run] would write {out_path}: {counts}")
        return 0
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(snap, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {out_path} ({len(names)} packages): {counts}")
    return 0


# --------------------------------------------------------------------------
# Applying
# --------------------------------------------------------------------------
def _months_between(published: str, as_of: str) -> float | None:
    """Approximate months from ``published`` to ``as_of`` (YYYY-MM-DD prefixes)."""
    try:
        d1 = datetime.strptime(published[:10], "%Y-%m-%d")
        d2 = datetime.strptime(as_of[:10], "%Y-%m-%d")
    except (TypeError, ValueError):
        return None
    return (d2 - d1).days / 30.44


Flag = tuple[str, str]  # (kind, message)


def _ver(v: str | None) -> tuple[int, ...]:
    base = re.sub(r"[-+].*$", "", (v or "").strip())
    out = []
    for seg in base.split("."):
        m = re.match(r"\d+", seg)
        out.append(int(m.group()) if m else 0)
    return tuple(out) + (0,) * (3 - len(out))


def _sdk_upper_is_old(sdk: str | None) -> bool:
    m = re.search(r"<\s*=?\s*([0-9][0-9.]*)", sdk or "")
    return bool(m) and _ver(m.group(1)) <= (3, 0, 0)


def stale_signals(s: dict) -> list[str]:
    """Weak corroborating signals for an old release (commit data is not in the snapshot)."""
    sig = []
    pp = s.get("pubPoints")
    if pp is not None and pp < 100:
        sig.append(f"pubPoints={pp}<100")
    if _sdk_upper_is_old(s.get("sdk")):
        sig.append(f"sdk={s.get('sdk')} (old Dart upper bound)")
    lk = s.get("likes")
    if lk is not None and lk < 100:
        sig.append(f"likes={lk}<100")
    return sig


def bounded_flags(e: dict, s: dict, as_of: str, age: float) -> list[Flag]:
    n, out = e["name"], []
    lo, hi = e.get("appliesToMinVersion"), e.get("appliesToMaxVersion")
    latest = s.get("version")
    allv = s.get("allVersions") or ([latest] if latest else [])
    if lo and hi and _ver(lo) >= _ver(hi):
        out.append(("bounded-min-gt-max", f"{n}: appliesToMinVersion {lo} >= appliesToMaxVersion {hi} (empty range)"))
    if lo and allv and all(_ver(v) < _ver(lo) for v in allv):
        out.append(("bounded-above-all", f"{n}: appliesToMinVersion {lo} is above every published version (latest {latest})"))
    if hi and latest and _ver(latest) < _ver(hi):
        out.append((
            "bounded-includes-latest",
            f"{n} [{e['status']}]: appliesToMaxVersion {hi} (exclusive) does not exclude latest {latest}"
            + (f" and is above every published version" if allv and all(_ver(v) < _ver(hi) for v in allv) else "")
            + " - entry still describes the newest release",
        ))
    low = (e.get("reason") or "").lower()
    hit = next((t for t in TEMPLATE_REASONS if t in low), None)
    if hit:
        out.append(("bounded-template-reason", f"{n}: bounded reason is generic ('{hit}') - verify it against the bounded range"))
    if age < 12:
        out.append(("bounded-recent-release", f"INFO {n} [{e['status']}]: latest release {s['published'][:10]} ({age:.0f} months old); bound may still be right"))
    return out


def lifecycle_flags(e: dict, s: dict, as_of: str) -> list[Flag]:
    """Status-review flags (never auto-applied). Returns (kind, message) pairs."""
    n, st, out = e["name"], e["status"], []
    age = _months_between(s.get("published") or "", as_of)
    if age is None or s.get("isDiscontinued"):
        return out
    bounded = "appliesToMinVersion" in e or "appliesToMaxVersion" in e
    if bounded:
        if st == "end_of_life":
            out.extend(bounded_flags(e, s, as_of, age))
        return out
    if st == "end_of_life" and age < 12:
        out.append(("revived", f"{n} [end_of_life]: not discontinued, latest release {s['published'][:10]} "
                    f"({age:.0f} months old) - revived?"))
    elif st == "active" and age >= 12:
        if (s.get("pubPoints") or 0) >= 140:
            return out  # finished mature library, same exemption as status-classifier.ts
        sig = stale_signals(s)
        if sig:
            cand = "end_of_life" if age >= 24 else "maintenance_mode"
            out.append(("stale", f"{n} [active]: latest release {s['published'][:10]} ({age:.0f} months old) "
                        f"- stale, candidate {cand}; signals: {'; '.join(sig)}"))
    return out


def replacement_flags(e: dict, pk: dict, by_name: dict[str, list[dict]]) -> list[Flag]:
    n, r = e["name"], e.get("replacement")
    if not is_replacement_package_name(r):
        return []
    r, out = r.strip(), []
    rs = pk.get(r)
    if rs and rs.get("status") == "not_found":
        out.append(("replacement-404", f"{n}: replacement {r!r} 404s on pub.dev"))
    elif rs and rs.get("isDiscontinued"):
        out.append(("replacement-discontinued", f"{n}: replacement {r!r} is discontinued upstream"))
    if any(x["status"] == "end_of_life" and "appliesToMinVersion" not in x and "appliesToMaxVersion" not in x
           for x in by_name.get(r, [])):
        out.append(("replacement-chain", f"{n} -> {r}: replacement is itself end_of_life in known_issues"))
    # cycle: follow unbounded replacement links from n
    seen, cur = [n], r
    while cur and cur not in seen:
        seen.append(cur)
        nxt = next((x.get("replacement") for x in by_name.get(cur, [])
                    if is_replacement_package_name(x.get("replacement"))), None)
        cur = nxt.strip() if nxt else None
    if cur == n:
        out.append(("replacement-cycle", f"{n}: replacement cycle {' -> '.join(seen + [n])}"))
    return out


def dead_data_flag(e: dict, s: dict | None) -> list[Flag]:
    n = e["name"]
    if n in SYNTHETIC_NAMES:
        return []
    if n in SDK_PACKAGES:
        why = "SDK package (not on pub.dev as a normal dependency)"
    elif not VALID_NAME.match(n):
        why = "name has parentheses/suffix alias (not a real package name)"
    elif s and s.get("status") == "not_found":
        why = "404 on pub.dev (removed?)"
    else:
        return []
    return [("dead-data", f"INFO {n} [{e['status']}]: {why}")]


def cmd_apply(a: argparse.Namespace) -> int:
    snap = json.loads(Path(a.snapshot).read_text(encoding="utf-8"))
    pk = snap["packages"]
    raw = KNOWN_ISSUES.read_text(encoding="utf-8")
    data = json.loads(raw)
    by_name: dict[str, list[dict]] = {}
    for x in data["issues"]:
        by_name.setdefault(x["name"], []).append(x)
    updated = unchanged = 0
    not_found: list[str] = []
    errors: list[str] = []
    absent: list[str] = []
    flags: list[Flag] = []
    unrefreshed: list[tuple[str, str]] = []
    for e in data["issues"]:
        n = e["name"]
        if a.only and n not in a.only:
            continue
        s = pk.get(n)
        flags.extend(dead_data_flag(e, s))
        flags.extend(replacement_flags(e, pk, by_name))
        if s is None:
            absent.append(n)
            unrefreshed.append((n, e.get("as_of") or ""))
            continue
        if s["status"] == "not_found":
            not_found.append(n)
            unrefreshed.append((n, e.get("as_of") or ""))
            continue
        if s["status"] != "ok":
            errors.append(n)
            unrefreshed.append((n, e.get("as_of") or ""))
            continue
        before = json.dumps(e)
        if "lastUpdated" in e and s["published"]:
            e["lastUpdated"] = s["published"]
        if "pubPoints" in e and s["pubPoints"] is not None:
            e["pubPoints"] = s["pubPoints"]
        if "archiveSizeBytes" in e and s["archiveSizeBytes"]:
            e["archiveSizeBytes"] = s["archiveSizeBytes"]
            if "archiveSizeMB" in e:
                e["archiveSizeMB"] = round(s["archiveSizeBytes"] / 1048576, 2)
        if "verifiedPublisher" in e:
            e["verifiedPublisher"] = bool(s["publisher"])
        if "platforms" in e:
            e["platforms"] = [
                p
                for p in ("android", "ios", "linux", "macos", "web", "windows")
                if p in s["platforms"]
            ]
        # Flags: never auto-rewritten.
        mine: list[Flag] = []
        st, disc = e["status"], s["isDiscontinued"]
        if disc and st != "end_of_life":
            mine.append(("discontinued", f"{n} [{st}]: now DISCONTINUED on pub.dev (replacedBy={s['replacedBy']})"))
        mine.extend(lifecycle_flags(e, s, a.as_of))
        rb = s["replacedBy"]
        # Freeform replacement text is not comparable to a package name.
        if rb and is_replacement_package_name(e.get("replacement")) and e.get("replacement", "").strip() != rb:
            mine.append(("replacedBy-mismatch", f"{n}: pub.dev replacedBy={rb!r} but replacement={e.get('replacement')!r}"))
        lic = e.get("license")
        if lic and s["licenseTags"] and lic.lower() not in s["licenseTags"]:
            mine.append(("license", f"{n}: license {lic!r} vs pub.dev tags {s['licenseTags']}"))
        rt = s.get("retracted") or {}
        if rt.get("latestRetracted"):
            mine.append(("retracted-latest", f"{n}: latest {s.get('version')} is RETRACTED"))
        details = s.get("advisoryDetails")
        if details is not None:
            live = [d.get("id") for d in details if advisory_status(d, s.get("version")) == "affected"]
            old_fixed = [d.get("id") for d in details if advisory_status(d, s.get("version")) == "fixed"]
            if live:
                mine.append(("advisories", f"{n}: latest {s.get('version')} affected by unfixed advisories ({', '.join(map(str, live[:3]))})"))
            if old_fixed:
                mine.append(("advisories-fixed", f"INFO {n}: {len(old_fixed)} advisories affect older versions, fixed in latest ({', '.join(map(str, old_fixed[:3]))})"))
        elif s.get("advisories"):
            # format-2 snapshot without range data: cannot judge; stay quiet-but-informative.
            mine.append(("advisories", f"INFO {n}: {len(s['advisories'])} advisories on record (re-run snapshot for range data)"))
        flags.extend(mine)
        real = [f for f in mine if not f[1].startswith("INFO")]
        if not (a.refresh_as_of_only_verified and real):
            e["as_of"] = a.as_of
        else:
            unrefreshed.append((n, e.get("as_of") or ""))
        if json.dumps(e) != before:
            updated += 1
        else:
            unchanged += 1
    # Entries left un-refreshed with an old as_of.
    stale_as_of = []
    for n, ao in unrefreshed:
        age = _months_between(ao, a.as_of)
        if age is None or age * 30.44 > STALE_AS_OF_DAYS:
            stale_as_of.append(f"{n} (as_of={ao or 'missing'})")
    if stale_as_of:
        flags.append(("stale-as-of", f"{len(stale_as_of)} entries not refreshed with as_of >{STALE_AS_OF_DAYS}d old: "
                      + ", ".join(stale_as_of)))
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    print(f"snapshot format={snap.get('format', 1)} fetched_at={snap.get('fetched_at')}")
    print(
        f"updated={updated} unchanged={unchanged} not_in_snapshot={len(absent)} "
        f"404={len(not_found)} fetch_errors={len(errors)}"
    )
    if errors:
        print("fetch errors:", ", ".join(errors))
    counts: dict[str, int] = {}
    for k, _ in flags:
        counts[k] = counts.get(k, 0) + 1
    print(f"FLAGGED ({len(flags)}):")
    for k, m in flags:
        print(f"  [{k}] {m}")
    print("flag counts:", json.dumps(dict(sorted(counts.items()))))
    rc = 1 if (a.strict and stale_as_of) else 0
    if a.dry_run:
        print("[dry-run] known_issues.json not written")
        return rc
    if text != raw:
        KNOWN_ISSUES.write_text(text, encoding="utf-8")
        print(f"Wrote {KNOWN_ISSUES}")
    return rc


def cmd_selftest(_a: argparse.Namespace) -> int:
    def s(pub, disc=False, **kw):
        return {"published": pub, "isDiscontinued": disc, **kw}

    def kinds(fl):
        return [k for k, _ in fl]

    ao = "2026-09-19"
    eol = {"name": "x", "status": "end_of_life"}
    assert kinds(lifecycle_flags(eol, s("2026-05-01T00:00:00Z"), ao)) == ["revived"]
    assert not lifecycle_flags(eol, s("2025-01-01T00:00:00Z"), ao)
    assert not lifecycle_flags(eol, s("2026-05-01T00:00:00Z", True), ao)
    # T1 bounded
    b = {**eol, "appliesToMaxVersion": "1.0.0", "reason": "Fails Android 14 stuff"}
    k = kinds(lifecycle_flags(b, s("2026-05-01", version="0.21.3", allVersions=["0.21.3"]), ao))
    assert "bounded-includes-latest" in k and "bounded-template-reason" in k and "bounded-recent-release" in k, k
    k = kinds(lifecycle_flags({**b, "reason": "specific"}, s("2020-01-01", version="3.0.0"), ao))
    assert k == [], k
    k = kinds(lifecycle_flags({**eol, "appliesToMinVersion": "3.0.0", "appliesToMaxVersion": "2.0.0"},
                              s("2020-01-01", version="1.0.0", allVersions=["1.0.0"]), ao))
    assert "bounded-min-gt-max" in k and "bounded-above-all" in k, k
    # T2 stale
    act = {"name": "y", "status": "active"}
    assert not lifecycle_flags(act, s("2026-01-01", pubPoints=50), ao)
    assert not lifecycle_flags(act, s("2023-03-01", pubPoints=150, likes=5), ao), "exempt >=140"
    assert not lifecycle_flags(act, s("2023-03-01", pubPoints=120, likes=500, sdk=">=3.0.0 <4.0.0"), ao), "no signal"
    f = lifecycle_flags(act, s("2025-03-01", pubPoints=90), ao)
    assert "maintenance_mode" in f[0][1] and "pubPoints=90" in f[0][1]
    f = lifecycle_flags(act, s("2023-03-01", pubPoints=120, likes=500, sdk=">=2.12.0 <3.0.0"), ao)
    assert "end_of_life" in f[0][1] and "sdk=" in f[0][1]
    assert not lifecycle_flags(act, s(""), ao)
    # T3 replacements
    assert is_replacement_package_name("get_it") and not is_replacement_package_name("get_it with injectable")
    bn = {"a": [{"name": "a", "status": "active", "replacement": "b"}],
          "b": [{"name": "b", "status": "end_of_life", "replacement": "a"}]}
    assert set(kinds(replacement_flags(bn["a"][0], {}, bn))) == {"replacement-chain", "replacement-cycle"}
    pk = {"b": {"status": "not_found"}, "c": {"status": "ok", "isDiscontinued": True}}
    assert kinds(replacement_flags({"name": "a", "status": "active", "replacement": "b"}, pk, {})) == ["replacement-404"]
    assert kinds(replacement_flags({"name": "a", "status": "active", "replacement": "c"}, pk, {})) == ["replacement-discontinued"]
    assert not replacement_flags({"name": "a", "status": "active", "replacement": "the `intl` package"}, pk, {})
    # T6 dead data
    assert dead_data_flag({"name": "flutter_localizations", "status": "active"}, None)
    assert dead_data_flag({"name": "js (original)", "status": "active"}, None)
    assert dead_data_flag({"name": "gone", "status": "active"}, {"status": "not_found"})
    assert not dead_data_flag({"name": "ok_pkg", "status": "active"}, {"status": "ok"})
    # advisories
    def adv(**r):
        return {"id": "G", "ranges": [r], "latestListed": False}
    assert advisory_status(adv(introduced="0", fixed="0.13.3"), "1.2.0") == "fixed"
    assert advisory_status(adv(introduced="0", fixed="2.0.0"), "1.2.0") == "affected"
    assert advisory_status(adv(introduced="1.0.0"), "1.2.0") == "affected"  # only introduced
    assert advisory_status(adv(introduced="3.0.0"), "1.2.0") == "fixed"  # not yet introduced
    assert advisory_status(adv(introduced="0", lastAffected="1.1.0"), "1.2.0") == "fixed"
    assert advisory_status({"id": "G", "ranges": [], "latestListed": True}, "1.2.0") == "affected"
    for bad in (None, {}, {"ranges": "x"}, {"ranges": [None, {}, {"fixed": "1"}]}):
        assert advisory_status(bad, "1.2.0") == "unknown", bad
    assert advisory_status(adv(introduced="0", fixed="1.0.0"), None) == "unknown"
    d = advisory_detail({"id": "X", "affected": [None, {"package": {"name": "p"}, "versions": ["1.2.0"], "ranges": [
        {"events": [{"introduced": "0", "fixed": None}, {"introduced": None, "fixed": "1.0.0"}, None]}, "junk"]}]}, "p", "1.2.0")
    assert d["ranges"] == [{"introduced": "0", "fixed": "1.0.0"}] and d["latestListed"], d
    assert advisory_detail({"affected": "oops"}, "p", "1.0.0")["ranges"] == []
    print("selftest ok")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("snapshot", help="fetch pub.dev data into a snapshot file")
    s.add_argument("--output", default=str(DEFAULT_SNAPSHOT))
    s.add_argument("--only", action="append", help="limit to a package (repeatable; merges into existing snapshot)")
    s.add_argument("--package", action="append", help="add an extra tracked package (repeatable)")
    s.add_argument("--packages-file", help="file with one extra package name per line")
    s.add_argument("--concurrency", type=int, default=8)
    s.add_argument("--retries", type=int, default=4)
    s.add_argument("--timeout", type=float, default=30.0)
    s.add_argument("--dry-run", action="store_true")
    s.set_defaults(fn=cmd_snapshot)
    ap = sub.add_parser("apply", help="apply a snapshot to known_issues.json (offline)")
    ap.add_argument("--snapshot", default=str(DEFAULT_SNAPSHOT))
    ap.add_argument("--only", action="append")
    ap.add_argument("--as-of", default=datetime.now().strftime("%Y-%m-%d"))
    ap.add_argument("--strict", action="store_true", help="exit 1 when un-refreshed entries have as_of >90 days old")
    ap.add_argument("--refresh-as-of-only-verified", action="store_true",
                    help="do not bump as_of for entries that raised a non-INFO flag this run")
    ap.add_argument("--dry-run", action="store_true")
    ap.set_defaults(fn=cmd_apply)
    st = sub.add_parser("selftest", help="run the built-in lifecycle-flag self-test")
    st.set_defaults(fn=cmd_selftest)
    a = p.parse_args()
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
