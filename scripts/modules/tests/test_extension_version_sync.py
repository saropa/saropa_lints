"""Extension version must equal the Dart package version and not go below the Marketplace."""

import unittest

from scripts.modules._extension_publish import extension_version_sync_error
from scripts.modules._utils import extension_version_for


class TestExtensionVersionSync(unittest.TestCase):
    def test_stable_is_identity(self) -> None:
        self.assertEqual(extension_version_for("16.10.0"), "16.10.0")

    def test_equal_versions_pass(self) -> None:
        self.assertIsNone(extension_version_sync_error("16.10.0", "16.10.0", None))

    def test_mismatch_fails(self) -> None:
        err = extension_version_sync_error("16.10.0", "16.12.0", None)
        self.assertIn("must always be equal", err)

    def test_below_marketplace_fails(self) -> None:
        err = extension_version_sync_error("16.10.0", "16.10.0", "16.12.0")
        self.assertIn("lower than", err)

    def test_at_or_above_marketplace_passes(self) -> None:
        self.assertIsNone(extension_version_sync_error("16.10.0", "16.10.0", "16.10.0"))
        self.assertIsNone(extension_version_sync_error("16.10.0", "16.10.0", "16.8.0"))


if __name__ == "__main__":
    unittest.main()
