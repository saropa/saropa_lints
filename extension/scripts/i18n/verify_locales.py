#!/usr/bin/env python3
"""Deterministic locale audit (stdlib only, no network).

Checks every non-English locale in both file families against English:
  * runtime: src/i18n/locales/<loc>.json (nested)   source en.json
  * manifest: package.nls.<loc>.json (flat)         source package.nls.json
Problem classes: missing, extra, empty, placeholder, identical, suspicious.
Exit code 1 if any problem is found (see --warn-identical / --only).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
EXT = HERE.parent.parent
CLASSES = ["missing", "extra", "empty", "placeholder", "identical", "suspicious"]

# Short action labels: English values (lowercased) treated as button labels.
LABELS = {"dismiss", "cancel", "close", "ignore", "open", "apply", "ok", "save",
          "delete", "remove", "retry", "yes", "no", "skip", "done", "back",
          "next", "later", "refresh", "copy", "edit", "add", "show", "hide",
          "undo", "reset", "clear", "confirm", "continue", "install", "update"}
SENTENCE_PUNCT = re.compile(r"[.!?;。！？؟。।]|\.\.\.|…")
PH = re.compile(r"\{[A-Za-z_][\w.]*\}")
BACKTICK = re.compile(r"`[^`]*`")
MD_LINK = re.compile(r"\[[^\]]*\]\(([^)]*)\)")
URL = re.compile(r"(?:https?|command|file)://\S+|command:[\w.\-?=%&/,]+")
WORD = re.compile(r"[A-Za-z]{3,}")


def flatten(obj, prefix=""):
    out = {}
    for k, v in obj.items():
        key = f"{prefix}{k}"
        if isinstance(v, dict):
            out.update(flatten(v, key + "."))
        else:
            out[key] = v
    return out


def load(path: Path):
    return flatten(json.loads(path.read_text(encoding="utf-8")))


def tokens(s: str) -> dict:
    """Things that must match English exactly (as multisets)."""
    return {
        "placeholders": Counter(PH.findall(s)),
        "code": Counter(BACKTICK.findall(s)),
        "links": Counter(MD_LINK.findall(s)),
        "urls": Counter(URL.findall(s)),
    }


def placeholder_problems(en: str, loc: str) -> list[str]:
    a, b = tokens(en), tokens(loc)
    msgs = []
    for kind in a:
        if a[kind] != b[kind]:
            miss = list((a[kind] - b[kind]).elements())
            extra = list((b[kind] - a[kind]).elements())
            msgs.append(f"{kind}: missing={miss} extra={extra}")
    return msgs


def real_words(s: str, allowed_words: set) -> list[str]:
    s = BACKTICK.sub(" ", s)
    s = URL.sub(" ", s)
    s = PH.sub(" ", s)
    s = MD_LINK.sub(" ", s)
    return [w for w in WORD.findall(s) if w.lower() not in allowed_words]


def is_short_label(en: str) -> bool:
    e = en.strip()
    if e.lower().rstrip(".…") in LABELS:
        return True
    return len(e) <= 16 and len(e.split()) <= 2 and not PH.search(e) and not SENTENCE_PUNCT.search(e)


def suspicious(en: str, loc: str):
    """Return (score, reason) or None for short labels that look wrong."""
    if not is_short_label(en):
        return None
    e, l = en.strip(), loc.strip()
    reasons, score = [], 0.0
    if len(l) > 3 * len(e) and len(l) >= 8:
        reasons.append(f"length {len(l)} > 3x English {len(e)}")
        score += len(l) / max(len(e), 1)
    if SENTENCE_PUNCT.search(l) and not SENTENCE_PUNCT.search(e):
        reasons.append("sentence punctuation")
        score += 5
    if len(l.split()) > 3 and len(e.split()) <= 2:
        reasons.append("more than 3 words")
        score += 2
    return (score, "; ".join(reasons)) if reasons else None


def load_allow(path: Path) -> dict:
    d = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    return {
        "values": {v.lower() for v in d.get("values", [])},
        "words": {w.lower() for w in d.get("words", [])},
        "keys": list(d.get("keys", [])),
        "reviewed_ok": {l: set(v) for l, v in d.get("reviewed_ok", {}).items()},
    }


def key_allowed(key: str, patterns) -> bool:
    return any(key == p or (p.endswith("*") and key.startswith(p[:-1])) for p in patterns)


def audit_pair(en: dict, loc: dict, allow: dict, locale: str = "") -> dict:
    reviewed = allow["reviewed_ok"].get(locale, set())
    res = {c: [] for c in CLASSES}
    for k in sorted(en):
        if k not in loc:
            res["missing"].append({"key": k})
            continue
        ev, lv = en[k], loc[k]
        if not isinstance(lv, str):
            res["placeholder"].append({"key": k, "detail": "value is not a string"})
            continue
        if lv.strip() == "":
            if str(ev).strip() != "":
                res["empty"].append({"key": k})
            continue
        pm = placeholder_problems(str(ev), lv)
        if pm:
            res["placeholder"].append({"key": k, "detail": " | ".join(pm), "en": ev, "value": lv})
        if lv == ev and k not in reviewed and not key_allowed(k, allow["keys"]) and ev.strip().lower() not in allow["values"]:
            if real_words(ev, allow["words"]):
                res["identical"].append({"key": k, "en": ev})
        s = None if k in reviewed else suspicious(str(ev), lv)
        if s:
            res["suspicious"].append({"key": k, "en": ev, "value": lv, "score": round(s[0], 2), "reason": s[1]})
    for k in sorted(loc):
        if k not in en:
            res["extra"].append({"key": k})
    return res


def discover(ext: Path):
    fams = {
        "runtime": (ext / "src/i18n/locales/en.json",
                    lambda l: ext / f"src/i18n/locales/{l}.json"),
        "manifest": (ext / "package.nls.json",
                     lambda l: ext / f"package.nls.{l}.json"),
    }
    locales = sorted(p.stem for p in (ext / "src/i18n/locales").glob("*.json") if p.stem != "en")
    return fams, locales


def run(ext: Path, allow_path: Path) -> dict:
    allow = load_allow(allow_path)
    fams, locales = discover(ext)
    report = {"locales": {}, "totals": {c: 0 for c in CLASSES}}
    for fam, (src, pathfn) in fams.items():
        en = load(src)
        for l in locales:
            p = pathfn(l)
            entry = report["locales"].setdefault(l, {})
            if not p.exists():
                entry[fam] = {"file_missing": True, **{c: [{"key": k} for k in sorted(en)] if c == "missing" else [] for c in CLASSES}}
                report["totals"]["missing"] += len(en)
                continue
            r = audit_pair(en, load(p), allow, l)
            entry[fam] = r
            for c in CLASSES:
                report["totals"][c] += len(r[c])
    return report


def summarize(report: dict) -> str:
    lines = [f"{'locale':<7}" + "".join(f"{c:>12}" for c in CLASSES)]
    for l, fams in sorted(report["locales"].items()):
        cnt = {c: sum(len(f[c]) for f in fams.values()) for c in CLASSES}
        lines.append(f"{l:<7}" + "".join(f"{cnt[c]:>12}" for c in CLASSES))
    lines.append(f"{'TOTAL':<7}" + "".join(f"{report['totals'][c]:>12}" for c in CLASSES))
    return "\n".join(lines)


def top_suspicious(report: dict, n=30):
    rows = []
    for l, fams in report["locales"].items():
        for fam, r in fams.items():
            for x in r["suspicious"]:
                rows.append({"locale": l, "family": fam, **x})
    rows.sort(key=lambda x: (-x["score"], x["locale"], x["key"]))
    return rows[:n]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", help="write machine-readable report to this path")
    ap.add_argument("--ext", default=str(EXT), help="extension root")
    ap.add_argument("--allow", default=str(HERE / "english_allowed.json"))
    ap.add_argument("--warn-identical", action="store_true",
                    help="do not fail on 'identical' (still reported)")
    args = ap.parse_args(argv)
    report = run(Path(args.ext), Path(args.allow))
    report["top_suspicious"] = top_suspicious(report)
    if args.json:
        Path(args.json).parent.mkdir(parents=True, exist_ok=True)
        Path(args.json).write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    print(summarize(report))
    failing = [c for c in CLASSES if not (c == "identical" and args.warn_identical)]
    bad = sum(report["totals"][c] for c in failing)
    print(f"\n{'FAIL' if bad else 'OK'}: {bad} problem(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
