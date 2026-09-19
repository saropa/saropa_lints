import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_locales as v  # noqa: E402

ALLOW = {"values": {"ok"}, "words": {"dart"}, "keys": ["brand.*"], "reviewed_ok": {}}


class VerifyTests(unittest.TestCase):
    def audit(self, en, loc):
        return v.audit_pair(v.flatten(en), v.flatten(loc), ALLOW)

    def test_flatten(self):
        self.assertEqual(v.flatten({"a": {"b": "x"}, "c": "y"}), {"a.b": "x", "c": "y"})

    def test_missing_extra_empty(self):
        r = self.audit({"a": "One", "b": "Two"}, {"a": "", "z": "Zed"})
        self.assertEqual([x["key"] for x in r["missing"]], ["b"])
        self.assertEqual([x["key"] for x in r["extra"]], ["z"])
        self.assertEqual([x["key"] for x in r["empty"]], ["a"])

    def test_placeholder_mismatch(self):
        r = self.audit({"a": "Hi {name} `code` [x](command:foo.bar)"},
                       {"a": "Hola {nombre} `cod` [x](command:foo.baz)"})
        self.assertEqual(len(r["placeholder"]), 1)
        d = r["placeholder"][0]["detail"]
        self.assertIn("placeholders", d)
        self.assertIn("code", d)
        self.assertIn("links", d)

    def test_placeholder_ok(self):
        r = self.audit({"a": "Hi {name} `c`"}, {"a": "Hola `c` {name}"})
        self.assertEqual(r["placeholder"], [])

    def test_identical_rules(self):
        en = {"a": "Open the file", "b": "OK", "c": "`dart` {x}", "d": "Dart", "brand": {"n": "Some Words"}}
        # Locale identical to English: only the untranslated, non-allowlisted value is reported.
        r = self.audit(en, en)
        self.assertEqual([x["key"] for x in r["identical"]], ["a"])

    def test_suspicious_dismiss(self):
        r = self.audit({"a": "Dismiss"}, {"a": "Tu es viré, tout de suite!"})
        self.assertEqual(len(r["suspicious"]), 1)

    def test_normal_short_label_not_flagged(self):
        r = self.audit({"a": "Dismiss"}, {"a": "Schließen"})
        self.assertEqual(r["suspicious"], [])

    def test_long_english_not_label(self):
        r = self.audit({"a": "This is a long English sentence here."}, {"a": "Une longue phrase. Oui."})
        self.assertEqual(r["suspicious"], [])

    def test_end_to_end_exit_codes(self):
        with tempfile.TemporaryDirectory() as t:
            ext = Path(t)
            (ext / "src/i18n/locales").mkdir(parents=True)
            (ext / "src/i18n/locales/en.json").write_text(json.dumps({"a": {"b": "Hello world"}}))
            (ext / "src/i18n/locales/de.json").write_text(json.dumps({"a": {"b": "Hallo Welt"}}))
            (ext / "package.nls.json").write_text(json.dumps({"k": "Hello world"}))
            (ext / "package.nls.de.json").write_text(json.dumps({"k": "Hallo Welt"}))
            out = ext / "r.json"
            self.assertEqual(v.main(["--ext", t, "--json", str(out)]), 0)
            self.assertIn("locales", json.loads(out.read_text()))
            (ext / "package.nls.de.json").write_text(json.dumps({}))
            self.assertEqual(v.main(["--ext", t]), 1)


if __name__ == "__main__":
    unittest.main()
