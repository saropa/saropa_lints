"""Regression tests for the dependency-import consistency audit check.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

Pins the contract that prevents a recurrence of the v13.12.6 / v13.12.7
failures (2026-06-12): both releases imported ``package:meta/meta.dart`` from
lib/ without declaring ``meta`` in pubspec ``dependencies``. ``dart pub
publish`` rejected the package, but only on the tag-triggered CI job — after
the version tag had already been pushed. lib/** is in ``analyzer.exclude``
(plugin dogfooding), so no ``dart analyze`` run ever inspects these imports;
this audit check is the only thing that can catch the defect before the tag.

The decisive correctness property is the false-positive guard: lib/ is full of
rule sources that embed ``package:...`` URIs inside detection patterns and
Bad/Good DartDoc examples. The check must count only real header directives,
never those strings.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path


_PUBSPEC = """\
name: demo_pkg
version: 1.0.0
environment:
  sdk: ">=3.9.0 <4.0.0"
dependencies:
  analyzer: ^1.0.0
  collection: ^1.19.1
  meta: ^1.18.0
dev_dependencies:
  test: ^1.31.0
"""


class TestDependencyImportStatus(unittest.TestCase):
    """Pin the publish-blocking import/dependency consistency check."""

    def setUp(self) -> None:
        from scripts.modules._audit_checks import get_dependency_import_status

        self._fn = get_dependency_import_status
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "pubspec.yaml").write_text(_PUBSPEC, encoding="utf-8")
        (self.root / "lib").mkdir()
        (self.root / "bin").mkdir()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _write_lib(self, name: str, body: str) -> None:
        (self.root / "lib" / name).write_text(body, encoding="utf-8")

    def test_declared_imports_pass(self) -> None:
        # Every imported package is a declared dependency -> no findings.
        self._write_lib(
            "ok.dart",
            "import 'package:analyzer/analyzer.dart';\n"
            "import 'package:meta/meta.dart';\n\n"
            "class Ok {}\n",
        )
        result = self._fn(self.root)
        self.assertEqual(result["missing"], {})

    def test_undeclared_import_is_flagged(self) -> None:
        # `path` is imported but not in dependencies -> flagged with its file.
        self._write_lib(
            "bad.dart",
            "import 'package:path/path.dart';\n\n"
            "class Bad {}\n",
        )
        result = self._fn(self.root)
        self.assertIn("path", result["missing"])
        self.assertEqual(result["missing"]["path"], ["lib/bad.dart"])

    def test_package_uri_in_string_literal_is_not_an_import(self) -> None:
        # The exact failure mode the header bound exists to prevent: a rule
        # that documents a `package:` URI inside an example string must NOT be
        # read as importing that package.
        self._write_lib(
            "rule.dart",
            "import 'package:meta/meta.dart';\n\n"
            "const badExample = '''\n"
            "import 'package:firebase_auth/firebase_auth.dart';\n"
            "void main() {}\n"
            "''';\n"
            "final pattern = \"package:get_it/get_it.dart\";\n",
        )
        result = self._fn(self.root)
        self.assertEqual(result["missing"], {})

    def test_dev_dependency_does_not_satisfy_shipped_import(self) -> None:
        # `test` is a dev_dependency only; shipped lib/ code may not import it.
        self._write_lib(
            "uses_test.dart",
            "import 'package:test/test.dart';\n\nclass T {}\n",
        )
        result = self._fn(self.root)
        self.assertIn("test", result["missing"])

    def test_own_package_name_is_allowed(self) -> None:
        # A self-referential `package:<own_name>/` import is always valid.
        self._write_lib(
            "selfref.dart",
            "import 'package:demo_pkg/demo_pkg.dart';\n\nclass S {}\n",
        )
        result = self._fn(self.root)
        self.assertEqual(result["missing"], {})

    def test_dependencies_header_with_trailing_comment_is_parsed(self) -> None:
        # Regression: a `dependencies:` header carrying a trailing comment is
        # valid YAML, but the old exact `^dependencies:\\s*$` match missed it,
        # so the parser found ZERO declared deps and the gate reported every
        # shipped import as undeclared -> a false hard-block of the release.
        (self.root / "pubspec.yaml").write_text(
            "name: demo_pkg\n"
            "version: 1.0.0\n"
            "environment:\n"
            '  sdk: ">=3.9.0 <4.0.0"\n'
            "dependencies:  # runtime dependencies only\n"
            "  analyzer: ^1.0.0\n"
            "  meta: ^1.18.0\n"
            "dev_dependencies:\n"
            "  test: ^1.31.0\n",
            encoding="utf-8",
        )
        self._write_lib(
            "ok.dart",
            "import 'package:analyzer/analyzer.dart';\n"
            "import 'package:meta/meta.dart';\n\n"
            "class Ok {}\n",
        )
        result = self._fn(self.root)
        self.assertEqual(
            result["missing"],
            {},
            msg="declared deps under a commented header must be recognized",
        )


if __name__ == "__main__":
    unittest.main()
