"""Pins which `dart pub publish` output lines are surfaced as auth prompts.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v
"""

import unittest

from scripts.modules._git_ops import _is_auth_prompt_line


class IsAuthPromptLineTest(unittest.TestCase):
    def test_matches_authorize_prompt(self) -> None:
        self.assertTrue(_is_auth_prompt_line("Please Authorize pub to continue"))

    def test_matches_google_accounts_url(self) -> None:
        self.assertTrue(_is_auth_prompt_line(
            "  https://accounts.google.com/o/oauth2/auth?client_id=x\\n"))

    def test_matches_host_case_insensitively(self) -> None:
        self.assertTrue(_is_auth_prompt_line("Open ACCOUNTS.GOOGLE.COM now"))

    def test_ignores_unrelated_lines(self) -> None:
        self.assertFalse(_is_auth_prompt_line("Publishing saropa_lints 1.0.0"))
        self.assertFalse(_is_auth_prompt_line("see accountsXgoogleXcom"))


if __name__ == "__main__":
    unittest.main()
