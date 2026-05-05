"""
Keep ``lib/tiers/*.yaml`` plugin-version constraint in sync with
``pubspec.yaml``.

**Why this module exists.**  Each tier yaml shipped by the package
declares ``plugins.saropa_lints.version: "<constraint>"``. The Dart
analyzer's plugin manager fetches this exact constraint into a
synthetic project under ``.dartServer/.plugin_manager/<hash>/`` and
runs ``dart pub upgrade`` against it. If the constraint is stale (we
shipped ``^5.0.0-beta.8`` from Feb 2026 right through to v13.4.x —
see https://github.com/saropa/saropa_lints/issues/216), pub resolves
a synthetic project demanding the old saropa_lints, which conflicts
with anything the consumer already has on a newer analyzer (e.g.
``riverpod_lint`` requiring ``analyzer ^9.0.0``). Result: the
consumer's ``dart analyze`` aborts with "An error occurred while
setting up the analyzer plugin package", and the saropa_lints plugin
never loads.

**The fix this module implements.**  At publish time, rewrite every
tier yaml's ``version:`` line to track the major of the current
package version. ``13.4.6`` → ``"^13.0.0"``; ``14.0.0`` → ``"^14.0.0"``.
A ``^MAJOR.0.0`` constraint is intentionally wide so a small patch
publish doesn't churn the yaml; only major bumps move the floor.

**Why we don't write the *exact* version.**  Two reasons:
  1. The synthetic plugin-manager project resolves cooperatively
     with the consumer's pubspec; pinning to an exact patch like
     ``"^13.4.6"`` would force every consumer that already has
     ``saropa_lints: ^13.0.0`` to bump in lockstep, which defeats
     the point of caret ranges.
  2. We'd touch the yaml on every patch release, which (a) churns
     git history for no semantic gain and (b) makes downstream
     installations spuriously stale until they re-pull.

The publish workflow calls :func:`sync_tier_yamls` in *write* mode
just before tagging, and :func:`assert_tier_yamls_synced` is also
useful as a CI guard so a manual edit can't drift back to a stale
value.

Version:   1.0
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import re
from pathlib import Path

# Match the YAML line we care about, allowing arbitrary indent and
# capturing the existing constraint so callers can report deltas.
# The line MUST be the saropa_lints version (not, say, an analyzer
# version somewhere else in the file), so the surrounding context is
# checked separately by [_find_saropa_version_line] below.
_VERSION_LINE_RE = re.compile(
    r'^(?P<indent>\s+)version:\s*"(?P<value>[^"]*)"\s*$',
    re.MULTILINE,
)
_PLUGINS_SAROPA_HEADER_RE = re.compile(
    r'^\s*saropa_lints:\s*$',
    re.MULTILINE,
)


def desired_constraint_for(package_version: str) -> str:
    """Return the tier-yaml constraint that pairs with ``package_version``.

    ``13.4.6`` → ``"^13.0.0"``. We use ``^MAJOR.0.0`` (not
    ``^MAJOR.MINOR.PATCH``) deliberately; see the module docstring
    for the rationale.

    Pre-release versions (``14.0.0-beta.1``) keep the major segment
    only, so beta builds resolve against the same wide constraint.
    Raises ``ValueError`` if the input is not parseable as semver —
    callers are expected to have read it straight out of pubspec.yaml,
    which is already validated by :mod:`_version_changelog`.
    """
    match = re.match(r'^(\d+)\.\d+\.\d+', package_version.strip())
    if not match:
        raise ValueError(f"Not a semver version: {package_version!r}")
    major = match.group(1)
    return f"^{major}.0.0"


def _find_saropa_version_line(content: str) -> tuple[int, int, str] | None:
    """Locate the ``saropa_lints`` version line in ``content``.

    Returns a tuple of (start, end, current_value) or ``None`` if no
    such line is present. Looks for a ``saropa_lints:`` header first,
    then takes the first ``version:`` line that follows within the
    same indented block. Anchoring to the header guards against
    matching, say, ``analyzer:`` ``version:`` if that ever appears in
    a tier yaml.
    """
    header = _PLUGINS_SAROPA_HEADER_RE.search(content)
    if not header:
        return None
    # Search for the version line strictly after the saropa_lints header.
    # Multiple `version:` keys in the same yaml are unlikely but cheap
    # to defend against — take the first one in our scan window.
    tail_start = header.end()
    match = _VERSION_LINE_RE.search(content, pos=tail_start)
    if not match:
        return None
    return match.start(), match.end(), match.group("value")


def update_tier_yaml(
    yaml_path: Path,
    desired: str,
) -> tuple[bool, str | None]:
    """Rewrite ``yaml_path``'s saropa_lints version line to ``desired``.

    Returns ``(changed, previous)``:

    * ``changed`` is ``True`` if the file was rewritten, ``False`` if
      it was already at the desired value or had no version line to
      update (e.g. a tier yaml that doesn't declare a plugin block).
    * ``previous`` is the constraint that was there before, or
      ``None`` if no version line was found.

    Preserves CRLF / LF line endings — we re-encode using whatever
    the file already uses, so updating these yamls doesn't churn the
    git diff with EOL flips on Windows.
    """
    raw = yaml_path.read_bytes()
    # Detect line endings on the original bytes BEFORE decoding so we
    # can restore them faithfully even if the regex normalised them.
    use_crlf = b"\r\n" in raw
    content = raw.decode("utf-8")
    found = _find_saropa_version_line(content)
    if found is None:
        return False, None
    start, end, current = found
    if current == desired:
        return False, current
    # Reconstruct the full line preserving the original indent. We
    # match a whole line (including its newline-less terminator) and
    # rebuild from the captured indent group rather than splicing the
    # value alone, so any drift in surrounding whitespace gets fixed
    # too — the "version:" token never floats relative to the parent
    # `saropa_lints:` block in valid yaml.
    # Re-grab the match to recover the indent capture group.
    m = _VERSION_LINE_RE.search(content, pos=start)
    assert m is not None  # We just located it via [_find_saropa_version_line].
    indent = m.group("indent")
    new_line = f'{indent}version: "{desired}"'
    updated = content[:start] + new_line + content[end:]
    if use_crlf and "\r\n" not in updated:
        # Defensive: the file used CRLF originally; preserve that.
        updated = updated.replace("\n", "\r\n")
    yaml_path.write_bytes(updated.encode("utf-8"))
    return True, current


def sync_tier_yamls(
    tier_dir: Path,
    package_version: str,
) -> dict[Path, tuple[str | None, str]]:
    """Update every ``*.yaml`` in ``tier_dir`` and report what changed.

    Returns a dict keyed by file path with ``(previous, desired)``.
    ``previous`` is ``None`` when the file had no version line to
    update; otherwise it's the value before the rewrite. Files that
    already matched the desired constraint are omitted from the
    returned dict so callers can render a clean "n files updated"
    summary.
    """
    desired = desired_constraint_for(package_version)
    changes: dict[Path, tuple[str | None, str]] = {}
    for yaml_path in sorted(tier_dir.glob("*.yaml")):
        changed, previous = update_tier_yaml(yaml_path, desired)
        if changed:
            changes[yaml_path] = (previous, desired)
    return changes


def assert_tier_yamls_synced(
    tier_dir: Path,
    package_version: str,
) -> list[Path]:
    """Return tier yamls whose version drifts from ``package_version``.

    Empty list means everything is in sync. Used by the publish
    workflow as a fail-fast guard before tagging — also suitable as a
    CI step on every PR so a manual edit cannot reintroduce
    https://github.com/saropa_lints/issues/216 silently.
    """
    desired = desired_constraint_for(package_version)
    drifted: list[Path] = []
    for yaml_path in sorted(tier_dir.glob("*.yaml")):
        content = yaml_path.read_text(encoding="utf-8")
        found = _find_saropa_version_line(content)
        if found is None:
            continue
        _, _, current = found
        if current != desired:
            drifted.append(yaml_path)
    return drifted
