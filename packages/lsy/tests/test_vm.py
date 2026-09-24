import argparse
import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

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

    def exercise_run(self, build_code=0, detach=True, startup=True):
        with tempfile.TemporaryDirectory() as checkout, tempfile.TemporaryDirectory() as runtime:
            (Path(checkout) / "flake.nix").touch()
            with contextlib.ExitStack() as stack:
                stack.enter_context(patch.object(vm.Path, "exists", return_value=True))
                stack.enter_context(patch.object(vm.os, "access", return_value=True))
                stack.enter_context(patch.object(vm.shutil, "which", return_value="/bin/nix"))
                stack.enter_context(patch.object(vm.session, "runtime_directory", return_value=Path(runtime)))
                stack.enter_context(patch.object(vm.session, "cleanup"))
                stack.enter_context(patch.object(vm.session, "has_session", side_effect=[False, startup, startup]))
                stack.enter_context(patch.object(vm.session, "live_processes", side_effect=[[], [123, 456]]))
                build = stack.enter_context(patch.object(vm.subprocess, "run", return_value=subprocess.CompletedProcess([], build_code)))
                launch = stack.enter_context(patch.object(vm.session, "tmux", return_value=subprocess.CompletedProcess([], 0)))
                attach = stack.enter_context(patch.object(vm, "attach", return_value=0))
                stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
                stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
                code = vm.run(argparse.Namespace(flake=checkout, detach=detach))
            command = build.call_args.args[0]
            self.assertEqual(command[-6:], ["--argstr", "flakePath", checkout, "--argstr", "guestUser", "alice"])
            self.assertEqual(command[command.index("--expr") + 1], vm.RUNNER_EXPRESSION)
            self.assertIn("--impure", command)
            self.assertEqual(command[command.index("--out-link") + 1], str(Path(runtime) / "work/runner"))
            return code, launch, attach

    def test_duplicate_run_does_not_build(self):
        with tempfile.TemporaryDirectory() as checkout, tempfile.TemporaryDirectory() as runtime:
            (Path(checkout) / "flake.nix").touch()
            with contextlib.ExitStack() as stack:
                stack.enter_context(patch.object(vm.Path, "exists", return_value=True))
                stack.enter_context(patch.object(vm.os, "access", return_value=True))
                stack.enter_context(patch.object(vm.shutil, "which", return_value="/bin/nix"))
                stack.enter_context(patch.object(vm.session, "runtime_directory", return_value=Path(runtime)))
                stack.enter_context(patch.object(vm.session, "has_session", return_value=True))
                build = stack.enter_context(patch.object(vm.subprocess, "run"))
                output = stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
                self.assertEqual(vm.run(argparse.Namespace(flake=checkout, detach=True)), 1)
                self.assertIn("already running", output.getvalue())
                build.assert_not_called()

    def test_build_failure_does_not_launch(self):
        code, launch, attach = self.exercise_run(build_code=7)
        self.assertEqual(code, 7)
        launch.assert_not_called()
        attach.assert_not_called()

    def test_detached_launch(self):
        code, launch, attach = self.exercise_run()
        self.assertEqual(code, 0)
        self.assertEqual(launch.call_args.args[1:5], ("new-session", "-d", "-s", "vm"))
        self.assertIn("lsy.commands.vm_session", launch.call_args.args[-1])
        self.assertIn("PYTHONPATH=", launch.call_args.args[-1])
        attach.assert_not_called()

    def test_default_attaches(self):
        code, _, attach = self.exercise_run(detach=False)
        self.assertEqual(code, 0)
        attach.assert_called_once()

    def test_startup_failure(self):
        code, _, attach = self.exercise_run(startup=False)
        self.assertEqual(code, 1)
        attach.assert_not_called()


if __name__ == "__main__":
    unittest.main()
