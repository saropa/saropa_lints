"""Extension version must be the mapped Dart version and rise above the Marketplace."""

import unittest

from scripts.modules._extension_publish import extension_version_sync_error
from scripts.modules._utils import extension_version_for


class TestExtensionVersionSync(unittest.TestCase):
    def test_stable_maps_to_slot_nine(self) -> None:
        self.assertEqual(extension_version_for("17.0.0"), "17.0.9")

    def test_matching_mapped_version_passes(self) -> None:
        self.assertIsNone(extension_version_sync_error("17.0.0", "17.0.9", None))

    def test_unmapped_package_json_fails(self) -> None:
        err = extension_version_sync_error("17.0.0", "17.0.0", None)
        self.assertIn("share major.minor", err)

    def test_major_minor_mismatch_fails(self) -> None:
        err = extension_version_sync_error("17.0.0", "17.1.9", None)
        self.assertIn("share major.minor", err)

    def test_below_marketplace_fails(self) -> None:
        err = extension_version_sync_error("17.0.0", "17.0.9", "17.0.12")
        self.assertIn("not higher than", err)

    def test_equal_to_marketplace_fails(self) -> None:
        err = extension_version_sync_error("17.0.0", "17.0.9", "17.0.9")
        self.assertIn("not higher than", err)

    def test_above_marketplace_passes(self) -> None:
        self.assertIsNone(extension_version_sync_error("17.0.0", "17.0.9", "17.0.8"))


if __name__ == "__main__":
    unittest.main()
