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
    (discontinued, replacedBy, 404, revived, license drift) are printed as a
    FLAGGED report for a human to decide. Key order and formatting are
    preserved so the git diff stays minimal.

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
API = "https://pub.dev/api"
UA = "saropa_lints-pubdev-snapshot (+https://github.com/saropa/saropa_lints)"


# --------------------------------------------------------------------------
# Tracked-package sources (extend here)
# --------------------------------------------------------------------------
def _known_issue_names() -> Iterable[str]:
    data = json.loads(KNOWN_ISSUES.read_text(encoding="utf-8"))
    return [e["name"] for e in data["issues"]]


TRACKED_SOURCES: list[Callable[[], Iterable[str]]] = [_known_issue_names]


def tracked_names(extra: list[str]) -> list[str]:
    names: dict[str, None] = {}
    for src in TRACKED_SOURCES:
        for n in src():
            names[n] = None
    for n in extra:
        names[n] = None
    return [n for n in names if VALID_NAME.match(n)]


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
    url = latest.get("archive_url")
    if url:
        st, _, h = _request(url, "HEAD", timeout, retries)
        size = h.get("Content-Length") or h.get("x-goog-stored-content-length")
        if st == 200 and size and str(size).isdigit():
            out["archiveSizeBytes"] = int(size)
    return out


def cmd_snapshot(a: argparse.Namespace) -> int:
    names = tracked_names(a.package or [])
    if a.packages_file:
        names += [
            ln.strip()
            for ln in Path(a.packages_file).read_text().splitlines()
            if VALID_NAME.match(ln.strip())
        ]
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
            snap["packages"][n] = res
            done += 1
            if done % 50 == 0:
                print(f"  {done}/{len(names)}", file=sys.stderr)
    snap["fetched_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    snap["source"] = API
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
def cmd_apply(a: argparse.Namespace) -> int:
    snap = json.loads(Path(a.snapshot).read_text(encoding="utf-8"))
    pk = snap["packages"]
    raw = KNOWN_ISSUES.read_text(encoding="utf-8")
    data = json.loads(raw)
    updated = unchanged = 0
    not_found: list[str] = []
    errors: list[str] = []
    absent: list[str] = []
    flags: list[str] = []
    for e in data["issues"]:
        n = e["name"]
        if a.only and n not in a.only:
            continue
        s = pk.get(n)
        if s is None:
            absent.append(n)
            continue
        if s["status"] == "not_found":
            not_found.append(n)
            flags.append(f"{n} [{e['status']}]: 404 on pub.dev (removed?)")
            continue
        if s["status"] != "ok":
            errors.append(n)
            continue
        before = json.dumps(e)
        old_last = e.get("lastUpdated") or ""
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
        e["as_of"] = a.as_of
        # Flags: never auto-rewritten.
        st, disc = e["status"], s["isDiscontinued"]
        if disc and st != "end_of_life":
            flags.append(
                f"{n} [{st}]: now DISCONTINUED on pub.dev (replacedBy={s['replacedBy']})"
            )
        if st == "end_of_life" and not disc and old_last and (s["published"] or "") > old_last:
            flags.append(
                f"{n} [end_of_life]: not discontinued, published {s['published']} "
                f"(recorded {old_last}) - revived?"
            )
        rb = s["replacedBy"]
        if rb and e.get("replacement") != rb:
            flags.append(
                f"{n}: pub.dev replacedBy={rb!r} but replacement={e.get('replacement')!r}"
            )
        lic = e.get("license")
        if lic and s["licenseTags"] and lic.lower() not in s["licenseTags"]:
            flags.append(f"{n}: license {lic!r} vs pub.dev tags {s['licenseTags']}")
        if json.dumps(e) != before:
            updated += 1
        else:
            unchanged += 1
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    print(f"snapshot fetched_at={snap.get('fetched_at')}")
    print(
        f"updated={updated} unchanged={unchanged} not_in_snapshot={len(absent)} "
        f"404={len(not_found)} fetch_errors={len(errors)}"
    )
    if errors:
        print("fetch errors:", ", ".join(errors))
    print(f"FLAGGED ({len(flags)}):")
    for f in flags:
        print("  " + f)
    if a.dry_run:
        print("[dry-run] known_issues.json not written")
        return 0
    if text != raw:
        KNOWN_ISSUES.write_text(text, encoding="utf-8")
        print(f"Wrote {KNOWN_ISSUES}")
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
    ap.add_argument("--dry-run", action="store_true")
    ap.set_defaults(fn=cmd_apply)
    a = p.parse_args()
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
