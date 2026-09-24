import contextlib
import io
import unittest
from unittest.mock import patch

from lsy.cli import main


class CliTests(unittest.TestCase):
    def test_try_packages(self):
        with patch("lsy.commands.try_package.os.execvp") as execvp:
            self.assertEqual(main(["try", "ripgrep", "python313Packages.requests"]), 0)
        execvp.assert_called_once_with("nix", [
            "nix", "--extra-experimental-features", "nix-command flakes",
            "shell", "--", "nixpkgs#ripgrep", "nixpkgs#python313Packages.requests",
        ])

    def test_arguments_are_not_shell_interpolated(self):
        with patch("lsy.commands.try_package.os.execvp") as execvp:
            main(["try", "foo; echo unsafe"])
        self.assertEqual(execvp.call_args.args[1][-1], "nixpkgs#foo; echo unsafe")

    def test_invalid_usage(self):
        for argv in ([], ["try"], ["unknown"], ["try", "--unknown"]):
            with self.subTest(argv=argv), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    main(argv)
                self.assertEqual(error.exception.code, 2)

    def test_help(self):
        for argv in (["--help"], ["try", "--help"]):
            with self.subTest(argv=argv), contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    main(argv)
                self.assertEqual(error.exception.code, 0)

    def test_missing_nix(self):
        with patch("lsy.commands.try_package.os.execvp", side_effect=FileNotFoundError):
            with contextlib.redirect_stderr(io.StringIO()) as output:
                self.assertEqual(main(["try", "hello"]), 127)
        self.assertIn("nix was not found", output.getvalue())


if __name__ == "__main__":
    unittest.main()
