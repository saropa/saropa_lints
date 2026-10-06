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


class KeyUnionRegexTests(unittest.TestCase):
    def _members(self, text):
        out = []
        for m in _mod._KEY_UNION_RE.finditer(text):
            out += _mod._UNION_MEMBER_RE.findall(m.group(1))
        return out

    def test_single_member(self):
        self.assertEqual(self._members("type AKey = 'a.b';"), ["a.b"])

    def test_multi_member(self):
        self.assertEqual(
            self._members("type AKey = 'a.b' | \"c.d.e\" | 'f.g';"),
            ["a.b", "c.d.e", "f.g"])

    def test_leading_pipe(self):
        self.assertEqual(self._members("type AKey =\n  | 'a.b'\n  | 'c.d';"),
                         ["a.b", "c.d"])

    def test_multiline(self):
        self.assertEqual(
            self._members("type XKey =\n  'a.b'\n  | 'c.d'\n  ;"),
            ["a.b", "c.d"])

    def test_non_matching(self):
        self.assertEqual(self._members("type AKey = 'plain';"), [])
        self.assertEqual(self._members("type A = 'a.b';"), [])
        self.assertEqual(self._members("type AKey = 'a.b' | string;"), [])

    def test_pathological_input_is_fast(self):
        import time
        text = 'type Key="0.0"' + '\t"0.0"' * 5000
        start = time.perf_counter()
        self.assertEqual(self._members(text), [])
        self.assertLess(time.perf_counter() - start, 1.0)


if __name__ == "__main__":
    unittest.main()
