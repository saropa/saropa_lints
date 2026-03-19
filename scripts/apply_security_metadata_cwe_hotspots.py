#!/usr/bin/env python3
"""
Populate security-rule metadata for future CWE/reporting and hotspot workflows.

Targets the large, hand-authored security rule files and:
  1) Inserts `cweIds` overrides for known (lint-id -> CWE) mappings when the
     class currently lacks a `List<int> get cweIds => ...` override.
  2) Reclassifies some context-dependent security rules as
     `RuleType.securityHotspot` and adds the `review-required` tag.

This is intentionally metadata-only; it does not change lint detection logic.

Run from repo root:
  python scripts/apply_security_metadata_cwe_hotspots.py
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
from typing import Dict, List, Optional, Tuple


SECURITY_FILES = [
    Path("lib/src/rules/security/security_network_input_rules.dart"),
    Path("lib/src/rules/security/security_auth_storage_rules.dart"),
]


# Lint-id -> CWE mapping.
#
# Notes:
# - CWE IDs are best-effort until we have a fully curated mapping table.
# - Non-security-ish helper rules in this folder intentionally get no CWE.
CWE_BY_LINT_ID: Dict[str, List[int]] = {
    # Code injection / dynamic execution
    "avoid_dynamic_code_loading": [94],
    "avoid_eval_like_patterns": [94],
    "avoid_dynamic_sql": [89],
    "avoid_unsafe_deserialization": [502],

    # Path traversal / injection
    "avoid_path_traversal": [22],
    "avoid_redirect_injection": [601],
    "avoid_user_controlled_urls": [601],
    "require_deep_link_validation": [601],

    # Input validation/sanitization
    "require_input_sanitization": [20],
    "require_input_validation": [20],
    "require_url_validation": [20],
    "prefer_whitelist_validation": [20],
    "require_clipboard_paste_validation": [20],

    # Secrets in URLs / external surfaces / logs
    "avoid_generic_key_in_url": [598],
    "avoid_auth_in_query_params": [598],
    "avoid_external_storage_sensitive": [200],
    "avoid_hardcoded_signing_config": [798],
    "avoid_encryption_key_in_memory": [200],

    # Cryptography randomness / crypto correctness
    "prefer_secure_random": [330],

    # TLS / transport
    "avoid_ignoring_ssl_errors": [295],  # (already handled elsewhere, kept for safety)
    "require_certificate_pinning": [295],
    "require_https_only_test": [319],

    # WebView security posture (misconfiguration / policy bypass)
    "avoid_webview_javascript_enabled": [79],
    "prefer_webview_javascript_disabled": [79],
    "avoid_webview_insecure_content": [319],
    "avoid_webview_cors_issues": [346],
    "prefer_webview_sandbox": [284],
    "require_webview_error_handling": [703],

    # Crypto/auth flows
    "avoid_jwt_decode_client": [345],
    "prefer_oauth_pkce": [345],
    "require_token_refresh": [613],
    "require_session_timeout": [613],

    # Credentials / storage protection
    "avoid_storing_passwords": [522],
    "require_secure_password_field": [522],
    "avoid_storing_sensitive_unencrypted": [311],
    "avoid_secure_storage_large_data": [311],
    "require_data_encryption": [311],
    "require_secure_storage": [311],
    "require_secure_storage_for_auth": [311],
    "require_secure_storage_auth_data": [311],
    "require_secure_storage_error_handling": [703],
    "require_keychain_access": [522],
    "require_logout_cleanup": [613],

    # Authentication hardening
    "prefer_biometric_protection": [287],
    "prefer_local_auth": [287],
    "require_biometric_fallback": [287],
    "require_multi_factor": [287],
    "require_auth_check": [285],

    # Device integrity
    "prefer_root_detection": [284],

    # Misc security-relevant helper
    "avoid_unverified_native_library": [829],
    "prefer_html_escape": [79],
}


HOTSPOT_LINT_IDS = {
    # WebView config is frequently “context dependent” (trusted content vs risk).
    "avoid_webview_javascript_enabled",
    "prefer_webview_javascript_disabled",
    "avoid_webview_insecure_content",
    "avoid_webview_cors_issues",
    "require_webview_error_handling",
    "prefer_webview_sandbox",
    # Redirect/deep link injection safety checks are also app-context sensitive.
    "avoid_redirect_injection",
    "avoid_user_controlled_urls",
    "require_deep_link_validation",
}


CLASS_RE = re.compile(r"class\s+(\w+)\s+extends\s+SaropaLintRule\s*\{", re.M)
LINT_ID_RE = re.compile(r"LintCode\(\s*\n\s*'(\w+)'\s*", re.M)
LINT_ID_RE_ALT = re.compile(r"LintCode\(\s*'(\w+)'\s*", re.M)


def _extract_lint_id(block: str) -> Optional[str]:
    m = LINT_ID_RE.search(block) or LINT_ID_RE_ALT.search(block)
    return m.group(1) if m else None


def _class_spans(t: str) -> List[Tuple[str, int, int]]:
    matches = list(CLASS_RE.finditer(t))
    spans: List[Tuple[str, int, int]] = []
    for i, m in enumerate(matches):
        class_name = m.group(1)
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(t)
        spans.append((class_name, start, end))
    return spans


def _has_cwe_override(block: str) -> bool:
    return bool(re.search(r"List<int>\s+get\s+cweIds\s*=>", block))


def _replace_rule_type_and_tags_for_hotspot(block: str) -> str:
    # RuleType: vulnerability -> securityHotspot
    block = re.sub(
        r"RuleType\?\s+get\s+ruleType\s+=>\s+RuleType\.vulnerability;",
        "RuleType? get ruleType => RuleType.securityHotspot;",
        block,
    )

    # Tags: const {'security'}; -> const {'security', 'review-required'};
    block = re.sub(
        r"Set<String>\s+get\s+tags\s+=>\s+const\s+\{'security'\};",
        "Set<String> get tags => const {'security', 'review-required'};",
        block,
    )

    # Also handle cases where tags already contain multiple entries.
    # If 'review-required' is missing, we append it.
    def add_review_required(m: re.Match[str]) -> str:
        indent = m.group("indent")
        inner = m.group("inner")
        if "review-required" in inner:
            return m.group(0)
        tags = re.findall(r"'([^']+)'", inner)
        tags.append("review-required")
        tags_unique = list(dict.fromkeys(tags))  # preserve order
        rebuilt_inner = ", ".join(f"'{t}'" for t in tags_unique)
        return f"{indent}Set<String> get tags => const {{{rebuilt_inner}}};"

    block = re.sub(
        r"(?P<indent>[ \t]*)Set<String>\s+get\s+tags\s+=>\s+const\s+\{(?P<inner>[^}]*)\};",
        add_review_required,
        block,
    )

    return block


def _insert_cwe_override_after_tags(block: str, indent: str, cwes: List[int]) -> str:
    cwe_list = ", ".join(str(x) for x in cwes)
    insertion = (
        f"  @override\n"
        f"{indent}List<int> get cweIds => const <int>[{cwe_list}];\n"
    )

    # Insert directly after the tags getter.
    # Matches the common formatting: an @override line, then a single-line tags const.
    pattern = (
        r"(?P<all>(?P<ind>[ \t]*)@override\s*\n"
        r"(?P=ind)Set<String>\s+get\s+tags\s+=>\s+const\s*\{[^}]*\};\s*\n)"
    )
    m = re.search(pattern, block)
    if not m:
        # Fallback: insert after ruleType getter.
        fallback = (
            r"(?P<all>(?P<ind>[ \t]*)@override\s*\n"
            r"(?P=ind)RuleType\?\s+get\s+ruleType\s+=>\s+RuleType\.[^;]*;\s*\n)"
        )
        fm = re.search(fallback, block)
        if not fm:
            return block
        insert_point = fm.end("all")
        return block[:insert_point] + insertion + block[insert_point:]

    insert_point = m.end("all")
    return block[:insert_point] + insertion + block[insert_point:]


def _update_block_for_class(block: str, lint_id: str) -> Tuple[str, bool]:
    changed = False

    # Hotspot reclassification (ruleType + tag).
    if lint_id in HOTSPOT_LINT_IDS:
        new_block = _replace_rule_type_and_tags_for_hotspot(block)
        if new_block != block:
            block = new_block
            changed = True

    # CWE insertion.
    if not _has_cwe_override(block) and lint_id in CWE_BY_LINT_ID:
        # Determine indent from the tags getter line.
        indent_m = re.search(r"^([ \t]*)Set<String>\s+get\s+tags\s+=>", block, re.M)
        indent = indent_m.group(1) if indent_m else "  "
        block = _insert_cwe_override_after_tags(
            block, indent=indent, cwes=CWE_BY_LINT_ID[lint_id]
        )
        changed = True

    return block, changed


def apply_to_file(path: Path) -> int:
    t = path.read_text(encoding="utf-8")
    spans = _class_spans(t)

    updated = 0
    # Replace from bottom to top to avoid span index shifts.
    for class_name, start, end in reversed(spans):
        block = t[start:end]
        lint_id = _extract_lint_id(block)
        if not lint_id:
            continue

        block, changed = _update_block_for_class(block, lint_id)

        if changed:
            t = t[:start] + block + t[end:]
            updated += 1

    path.write_text(t, encoding="utf-8")
    return updated


def main() -> None:
    total = 0
    for p in SECURITY_FILES:
        total += apply_to_file(p)
        print(f"Updated {p} (classes touched: {total})")
    print(f"\nDone. Total classes touched: {total}")


if __name__ == "__main__":
    main()

