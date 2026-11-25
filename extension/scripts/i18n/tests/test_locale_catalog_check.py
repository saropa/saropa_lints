"""Tests for catalog-level checks: missing keys, stale dictionary, garbage, gates."""

from __future__ import annotations

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import check_locale_garbage as garbage  # noqa: E402
import generate_locales as gl  # noqa: E402
import locale_catalog_check as cat  # noqa: E402


class TestMissingKeys(unittest.TestCase):
    def test_absent_short_key_is_missing(self) -> None:
        # Regression: pubGuard.explain.unknown ("unknown") was absent from every
        # catalog yet the dictionary-based audit reported 0 missing.
        en = {"pubGuard": {"explain": {"unknown": "unknown", "other": "Other"}}}
        loc = {"pubGuard": {"explain": {"other": "Andere"}}}
        self.assertEqual(cat.find_missing_keys(en, loc), ["pubGuard.explain.unknown"])

    def test_english_identical_value_is_not_missing(self) -> None:
        # Present key with an English-identical value is a different class.
        self.assertEqual(cat.find_missing_keys({"a": "OK"}, {"a": "OK"}), [])

    def test_empty_or_non_string_counts_as_missing(self) -> None:
        self.assertEqual(cat.find_missing_keys({"a": "x", "b": "y"}, {"a": "", "b": 3}), ["a", "b"])

    def test_flat_manifest_keys(self) -> None:
        self.assertEqual(cat.find_missing_keys({"x.y": "v"}, {}), ["x.y"])

    def test_list_items_are_compared_by_index(self) -> None:
        # Lists are flattened item by item so a short translated list is a gap.
        self.assertEqual(cat.find_missing_keys({"l": ["a", "b"]}, {"l": ["x"]}), ["l.1"])

    def test_extra_keys_reported(self) -> None:
        self.assertEqual(cat.find_extra_keys({"a": "x"}, {"a": "y", "old": "z"}), ["old"])
        self.assertEqual(cat.find_extra_keys({"a": "x"}, {"a": "y"}), [])


class TestStaleDictionary(unittest.TestCase):
    def test_reworded_english_is_stale(self) -> None:
        tr = {"de": {"Analyzer plugin": "Analyse-Plugin", "Live": "Live"}}
        self.assertEqual(
            cat.find_stale_dictionary_entries(tr, ["Analyzer Plugin"]),
            [("de", "Analyzer plugin")],
        )

    def test_live_entry_and_passthrough_not_stale(self) -> None:
        tr = {"de": {"Open": "Offnen", "Gone": "Gone"}}
        self.assertEqual(cat.find_stale_dictionary_entries(tr, ["Open"]), [])

    def test_unbacked_values(self) -> None:
        en = {"a": "Hello", "b": "Bye", "c": "Same"}
        loc = {"a": "Hallo", "b": "Tschuss", "c": "Same"}
        self.assertEqual(cat.find_unbacked_values(en, loc, {"Hello": "Hallo"}), ["b"])


class TestGarbage(unittest.TestCase):
    def test_leaked_prompts_flagged_in_header_position(self) -> None:
        for lc, text in [
            ("id", "Aturan Ketat:\n1. Kembalikan HANYA keluaran"),
            ("es", "Reglas estrictas: devolver"),
            ("en", "Return ONLY the string"),
            ("de", "Strenge Regel: nur"),
            ("pt", "Regra estrita: x"),
            ("fr", "Bonjour\nTranslate the following text"),
        ]:
            self.assertTrue(garbage.check_value(lc, text, "Source"), text)

    def test_marker_mid_sentence_not_flagged(self) -> None:
        # A legitimate translation may contain the phrase inside a sentence.
        self.assertEqual(garbage.check_value("es", "Aplique las reglas estrictas del paquete", "Apply"), [])
        self.assertEqual(garbage.check_value("en", "Use a strict rule set here", "x"), [])

    def test_loops_flagged(self) -> None:
        self.assertTrue(garbage.check_value("he", "abc " + "痰" * 12, "Source"))
        self.assertTrue(garbage.check_value("ur", "x " + "1" * 31, "Source"))
        self.assertTrue(garbage.check_value("de", "ababababababababab", "Source"))

    def test_benign_repeats_not_flagged(self) -> None:
        self.assertEqual(garbage.check_value("de", "Laden.............. fertig", "Loading"), [])
        self.assertEqual(garbage.check_value("de", "Wert 1000000 und " + "…" * 9, "v"), [])
        self.assertEqual(garbage.check_value("de", "Limit 100000000000", "Limit 100000000000"), [])
        for ch in "—–•·●█▓░│┃┌┐└┘├┤?!=-_.*#":
            self.assertEqual(garbage.check_value("de", "x " + ch * 12 + " y", "x"), [], repr(ch))

    def test_cjk_in_rtl_locale_flagged(self) -> None:
        self.assertTrue(garbage.check_value("he", "בדיקה 健全性", "Health check"))
        self.assertTrue(garbage.check_value("ar", "ال报告", "Report"))

    def test_extended_scripts_flagged(self) -> None:
        self.assertTrue(garbage.check_value("de", "x 㐀 y", "x"))          # CJK Ext-A
        self.assertTrue(garbage.check_value("de", "x Ａ y", "x"))          # fullwidth
        self.assertTrue(garbage.check_value("de", "x ᄀ y", "x"))          # Hangul Jamo
        self.assertTrue(garbage.check_value("de", "x ㄱ y", "x"))          # Compat Jamo
        self.assertTrue(garbage.check_value("de", "x прав y", "x"))  # Cyrillic in de
        self.assertTrue(garbage.check_value("ar", "שלום", "x"))      # Hebrew in ar
        self.assertTrue(garbage.check_value("he", "مرحبا", "x"))  # Arabic in he

    def test_scripts_allowed_where_expected(self) -> None:
        self.assertEqual(garbage.check_value("ru", "правило", "x"), [])
        self.assertEqual(garbage.check_value("uk", "правило", "x"), [])
        self.assertEqual(garbage.check_value("zh", "你好，世界！", "x"), [])
        self.assertEqual(garbage.check_value("ja", "設定を開く：", "Open settings"), [])
        self.assertEqual(garbage.check_value("zh", "打开设置", "Open settings"), [])
        # Source-provided CJK (e.g. a language-name list) is never a finding.
        self.assertEqual(garbage.check_value("he", "日本語", "日本語"), [])

    def test_wrong_cjk_script_flagged(self) -> None:
        self.assertTrue(garbage.check_value("zh", "打开を", "Open"))
        self.assertTrue(garbage.check_value("ja", "設定한", "Settings"))

    def test_ko_han_only_as_run(self) -> None:
        self.assertEqual(garbage.check_value("ko", "파일 漢 목록", "Files"), [])
        self.assertTrue(garbage.check_value("ko", "파일 漢字 목록", "Files"))
        self.assertEqual(garbage.check_value("ko", "파일 漢字", "Files 漢字"), [])

    def test_latin_sentence_in_cjk_flagged(self) -> None:
        self.assertTrue(garbage.check_value("ja", "Open the settings page now please", "Open the settings"))

    def test_product_list_and_identifiers_not_flagged(self) -> None:
        self.assertEqual(garbage.check_value("ja", "Isar Hive Firebase Riverpod", "x"), [])
        self.assertEqual(garbage.check_value("zh", "avoid_print_in_release", "x"), [])
        self.assertEqual(garbage.check_value("zh", "`avoid print in the release build` and more", "x"), [])
        self.assertEqual(garbage.check_value("ko", "avoid_print_in_release prefer_const_constructors", "x"), [])

    def test_protected_tokens_in_cjk_not_flagged(self) -> None:
        self.assertEqual(
            garbage.check_value("zh", "PATH pubspec.lock Dart SDK Flutter pubspec.yaml", "src"), [])
        self.assertEqual(
            garbage.check_value("ja", "これは PATH と pubspec.lock", "This is PATH"), [])
        self.assertEqual(garbage.check_value("zh", "`some long code span here` {count} OWASP", "src"), [])

    def test_lists_are_scanned(self) -> None:
        found = garbage.scan_catalog("id", {"l": ["ok", "Aturan Ketat: x"]}, {"l": ["a", "b"]})
        self.assertEqual([f[0] for f in found], ["l.1"])

    def test_scan_extension_end_to_end(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ext = _make_ext(Path(td), id_value="Aturan Ketat: x")
            rows = garbage.scan_extension(ext)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0][0], "xx.json")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(garbage.main(["--root", str(ext)]), 1)
                _write(ext / "src/i18n/locales/xx.json", {"a": {"b": "Halo"}})
                self.assertEqual(garbage.main(["--root", str(ext)]), 0)


def _write(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")


def _make_ext(root: Path, id_value: str = "Halo") -> Path:
    """Hermetic extension dir with one fake locale "xx" (real files untouched)."""
    loc = root / "src" / "i18n" / "locales"
    _write(loc / "en.json", {"a": {"b": "Hello"}})
    _write(loc / "xx.json", {"a": {"b": id_value}})
    _write(root / "package.nls.json", {"k": "World"})
    _write(root / "package.nls.xx.json", {"k": "Welt"})
    return root


class TestGates(unittest.TestCase):
    TR = {"xx": {"Hello": "Halo", "World": "Welt"}}
    SOURCES = ["Hello", "World"]

    def _audit(self, ext: Path, **kw: bool) -> int:
        # update_readme would rewrite the real README; stub it out. stdout and
        # stderr are swallowed to keep the test log clean.
        with mock.patch("coverage_report.update_readme"), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return gl._run_audit(["xx"], self.SOURCES, {}, ext, translations=self.TR, **kw)

    def test_catalog_gate_counters_are_separate(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ext = _make_ext(Path(td))
            _write(ext / "src/i18n/locales/xx.json", {"a": {}})  # key absent
            with contextlib.redirect_stdout(io.StringIO()):
                rep = gl._catalog_gate(["xx"], self.SOURCES, ext, self.TR)
            self.assertEqual(rep.absent, {"xx": 1})
            self.assertEqual(rep.garbage, {})
            self.assertEqual(rep.stale, 0)

    def test_clean_catalog_is_silent_and_exits_zero(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ext = _make_ext(Path(td))
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rep = gl._catalog_gate(["xx"], self.SOURCES, ext, self.TR)
            self.assertEqual((rep.absent, rep.garbage, rep.stale), ({}, {}, 0))
            self.assertEqual(buf.getvalue(), "")
            self.assertEqual(self._audit(ext, fail_on_missing=True, fail_on_stale=True), 0)

    def test_absent_key_fails_gate(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ext = _make_ext(Path(td))
            _write(ext / "src/i18n/locales/xx.json", {"a": {}})
            self.assertNotEqual(self._audit(ext, fail_on_missing=True), 0)
            self.assertEqual(self._audit(ext), 0)  # dev run never gated

    def test_garbage_fails_gate(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ext = _make_ext(Path(td), id_value="Aturan Ketat: x")
            self.assertNotEqual(self._audit(ext, fail_on_missing=True), 0)

    def test_stale_only_fails_with_flag(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ext = _make_ext(Path(td))
            stale_tr = {"xx": dict(self.TR["xx"], Gone="Weg")}
            with mock.patch("coverage_report.update_readme"), \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                ok = gl._run_audit(["xx"], self.SOURCES, {}, ext, fail_on_missing=True, translations=stale_tr)
                bad = gl._run_audit(["xx"], self.SOURCES, {}, ext, fail_on_stale=True, translations=stale_tr)
            self.assertEqual(ok, 0)
            self.assertNotEqual(bad, 0)

    def test_coverage_json_charges_catalog_defects(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ext = _make_ext(Path(td), id_value="Aturan Ketat: x")
            self._audit(ext)
            cov = json.loads((ext / "src/i18n/locale_coverage.json").read_text(encoding="utf-8"))
            self.assertLess(cov["locales"]["xx"]["coveragePct"], 100)


if __name__ == "__main__":
    unittest.main()
