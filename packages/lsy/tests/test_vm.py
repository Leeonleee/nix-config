import argparse
import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import MagicMock, patch

from lsy.cli import main
from lsy.commands import vm


class VmTests(unittest.TestCase):
    def setUp(self):
        account = patch.object(vm.pwd, "getpwuid", return_value=argparse.Namespace(pw_name="alice"))
        self.account = account.start()
        self.addCleanup(account.stop)

    def test_rejects_root_and_invalid_names(self):
        for name in ("root", "nobody", "bad/name", '${malicious}'):
            self.account.return_value.pw_name = name
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(vm.run(argparse.Namespace(flake="/unused")), 1)

    def test_missing_account(self):
        self.account.side_effect = KeyError
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(vm.run(argparse.Namespace(flake="/unused")), 1)

    def test_linux_only(self):
        with patch("lsy.cli.sys.platform", "darwin"), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main(["vm", "run"]), 1)
            self.assertEqual(main(["try", "hello"]), 1)

    def test_missing_kvm(self):
        with patch.object(vm.os, "access", return_value=False):
            with contextlib.redirect_stderr(io.StringIO()) as output:
                self.assertEqual(vm.run(argparse.Namespace(flake="/unused")), 1)
        self.assertIn("/dev/kvm", output.getvalue())

    def test_missing_nix(self):
        with patch.object(vm.Path, "exists", return_value=True), patch.object(vm.os, "access", return_value=True):
            with patch.object(vm.shutil, "which", return_value=None), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(vm.run(argparse.Namespace(flake="/unused")), 127)

    def test_missing_flake(self):
        with tempfile.TemporaryDirectory() as checkout:
            with patch.object(vm.Path, "exists", return_value=True), patch.object(vm.os, "access", return_value=True):
                with patch.object(vm.shutil, "which", return_value="/bin/nix"), contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(vm.run(argparse.Namespace(flake=checkout)), 1)

    def exercise_run(self, build_code=0, interrupted=False, guest_code=0, stubborn=False):
        with tempfile.TemporaryDirectory() as checkout:
            (Path(checkout) / "flake.nix").touch()
            process = MagicMock()
            process.__enter__.return_value = process
            if stubborn:
                process.wait.side_effect = [KeyboardInterrupt(), subprocess.TimeoutExpired("qemu", 5), 0]
            else:
                process.wait.side_effect = [KeyboardInterrupt(), 0] if interrupted else [guest_code]
            with patch.object(vm.Path, "exists", return_value=True), patch.object(vm.os, "access", return_value=True):
                with patch.object(vm.shutil, "which", return_value="/bin/nix"):
                    with patch.object(vm.subprocess, "run", return_value=subprocess.CompletedProcess([], build_code)) as build:
                        with patch.object(vm.subprocess, "Popen", return_value=process) as launch:
                            with contextlib.redirect_stdout(io.StringIO()):
                                code = vm.run(argparse.Namespace(flake=checkout))
            command = build.call_args.args[0]
            self.assertEqual(command[-6:], ["--argstr", "flakePath", checkout, "--argstr", "guestUser", "alice"])
            self.assertEqual(command[command.index("--expr") + 1], vm.RUNNER_EXPRESSION)
            self.assertIn("--impure", command)
            runtime = Path(command[command.index("--out-link") + 1]).parent
            self.assertFalse(runtime.exists(), "Temporary VM state must be cleaned up")
            return code, launch, process, runtime

    def test_build_failure_does_not_launch(self):
        code, launch, _, _ = self.exercise_run(build_code=7)
        self.assertEqual(code, 7)
        launch.assert_not_called()

    def test_success_and_cleanup(self):
        code, launch, _, runtime = self.exercise_run()
        self.assertEqual(code, 0)
        launch.assert_called_once_with([str(runtime / "runner/bin/microvm-run")], cwd=str(runtime))

    def test_guest_failure_is_returned(self):
        code, _, _, _ = self.exercise_run(guest_code=3)
        self.assertEqual(code, 3)

    def test_each_run_gets_a_fresh_directory(self):
        first = self.exercise_run()[3]
        second = self.exercise_run()[3]
        self.assertNotEqual(first, second)

    def test_stubborn_guest_is_killed(self):
        code, _, process, _ = self.exercise_run(stubborn=True)
        self.assertEqual(code, 130)
        process.terminate.assert_called_once()
        process.kill.assert_called_once()

    def test_interrupt_terminates_guest(self):
        code, _, process, _ = self.exercise_run(interrupted=True)
        self.assertEqual(code, 130)
        process.terminate.assert_called_once()


if __name__ == "__main__":
    unittest.main()
