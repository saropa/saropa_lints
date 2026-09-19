"""Tests for the dead-key detectors in check_l10n_keys.py.

Run: python3 -m unittest extension/scripts/test_check_l10n_keys.py
"""
import importlib.util
import unittest
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "check_l10n_keys", Path(__file__).with_name("check_l10n_keys.py"))
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)


class PrefixConstTests(unittest.TestCase):
    def test_template_and_concat_resolve(self):
        src = "const tb = 'pkg.toolbar';\nl10n(`${tb}.rescan`); l10n(tb + '.reset');"
        self.assertEqual(_mod._prefix_const_refs(src), {"pkg.toolbar.rescan", "pkg.toolbar.reset"})

    def test_reused_const_name_tries_every_prefix(self):
        src = "const s = 'a.script';\nconst s = 'a.search';\nl10n(`${s}.x`);"
        self.assertEqual(_mod._prefix_const_refs(src), {"a.script.x", "a.search.x"})

    def test_unrelated_template_ignored(self):
        self.assertEqual(_mod._prefix_const_refs("l10n(`${other}.x`)"), set())


class DottedStringTests(unittest.TestCase):
    def test_plain_property_literal_matches(self):
        self.assertEqual(_mod._DOTTED_STRING_RE.findall("{ titleKey: 'a.b.c' }"), ["a.b.c"])

    def test_undotted_string_ignored(self):
        self.assertEqual(_mod._DOTTED_STRING_RE.findall("x = 'plain'"), [])


if __name__ == "__main__":
    unittest.main()
