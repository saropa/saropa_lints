"""Tests for the even-minor rule on stable publish versions.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v
"""

from __future__ import annotations

import unittest
from unittest import mock

from scripts.modules import _version_changelog as vc
from scripts.modules._utils import (
    extension_version_for,
    stable_version_error,
    suggest_even_minor_stable,
)


class TestStableVersionError(unittest.TestCase):
    def test_even_minor_stable_accepted(self) -> None:
        self.assertIsNone(stable_version_error("16.8.0"))

    def test_odd_minor_stable_refused_with_suggestion(self) -> None:
        msg = stable_version_error("16.7.0")
        self.assertIsNotNone(msg)
        self.assertIn("even minor", msg)
        self.assertIn("Use 16.8.0.", msg)

    def test_prerelease_odd_and_even_minor_accepted(self) -> None:
        self.assertIsNone(stable_version_error("16.7.0-beta.1"))
        self.assertIsNone(stable_version_error("16.8.0-beta.1"))

    def test_suggest_even_minor(self) -> None:
        self.assertEqual(suggest_even_minor_stable("16.7.3"), "16.8.0")
        self.assertEqual(suggest_even_minor_stable("16.8.3"), "16.8.3")
        self.assertEqual(
            suggest_even_minor_stable("16.7.0-beta.1"), "16.7.0-beta.1",
        )


class TestExtensionVersionIdempotencyUnchanged(unittest.TestCase):
    def test_even_stable_maps_up(self) -> None:
        self.assertEqual(extension_version_for("16.6.0"), "16.8.0")

    def test_odd_minor_left_unchanged(self) -> None:
        self.assertEqual(extension_version_for("16.7.0"), "16.7.0")

    def test_idempotent(self) -> None:
        # Idempotency holds for converted prerelease (odd) values only.
        for v in ("16.0.0-beta.1", "16.7.0"):
            once = extension_version_for(v)
            self.assertEqual(extension_version_for(once), once)


class TestPromptRefusesOddMinor(unittest.TestCase):
    def test_odd_refused_then_even_accepted(self) -> None:
        with mock.patch.object(
            vc, "prompt_version", side_effect=["16.7.0", "16.8.0"],
        ) as p:
            self.assertEqual(vc.prompt_version_until_valid("16.8.0"), "16.8.0")
        self.assertEqual(p.call_args_list[1].args[0], "16.8.0")

    def test_prerelease_odd_accepted(self) -> None:
        with mock.patch.object(
            vc, "prompt_version", return_value="16.7.0-beta.1",
        ):
            self.assertEqual(
                vc.prompt_version_until_valid("16.7.0-beta.1"),
                "16.7.0-beta.1",
            )

    def test_default_skips_odd_minor(self) -> None:
        with mock.patch("builtins.input", return_value="n"), mock.patch.object(
            vc, "prompt_version_until_valid", side_effect=lambda d: d,
        ):
            self.assertEqual(
                vc.prompt_version_with_prerelease_toggle("16.7.1"), "16.8.0",
            )


if __name__ == "__main__":
    unittest.main()
