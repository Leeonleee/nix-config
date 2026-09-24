import argparse
import contextlib
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import unittest
from unittest.mock import MagicMock, patch

from lsy.commands import vm, vm_session as session


class SessionTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.args = argparse.Namespace()

    def test_private_runtime_and_stable_lock(self):
        with patch.dict(os.environ, {"XDG_RUNTIME_DIR": str(self.directory)}):
            directory = session.runtime_directory()
            self.assertEqual(directory, self.directory / "lsy-vm")
            self.assertEqual(directory.stat().st_mode & 0o777, 0o700)
            with session.locked(directory):
                inode = (directory / "lock").stat().st_ino
                with self.assertRaisesRegex(RuntimeError, "in progress"):
                    with session.locked(directory):
                        pass
            session.private_directory(directory / "work")
            session.cleanup(directory)
            self.assertTrue(directory.exists())
            self.assertEqual((directory / "lock").stat().st_ino, inode)

    def test_runtime_rejects_permissions_symlinks_and_owner(self):
        unsafe = self.directory / "unsafe"
        unsafe.mkdir(mode=0o755)
        with self.assertRaises(RuntimeError):
            session.private_directory(unsafe)
        link = self.directory / "link"
        link.symlink_to(self.directory, target_is_directory=True)
        with self.assertRaises(RuntimeError):
            session.private_directory(link)
        with self.assertRaises(RuntimeError):
            session.private_directory(link / "nested")
        with patch.object(session.os, "getuid", return_value=os.getuid() + 1):
            with self.assertRaises(RuntimeError):
                session.private_directory(self.directory)

    def test_fallback_runtime(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(session, "private_directory") as private:
            session.runtime_directory()
        private.assert_called_once_with(Path(f"/tmp/lsy-vm-{os.getuid()}"))

    def test_lock_rejects_symlink(self):
        (self.directory / "lock").symlink_to(self.directory / "other")
        with self.assertRaises(OSError):
            with session.locked(self.directory):
                pass

    def test_tmux_isolation(self):
        with patch.dict(os.environ, {"TMUX": "user-server"}):
            with patch.object(session.subprocess, "run") as run:
                session.tmux(self.directory, "attach-session", "-t", "vm")
        self.assertEqual(run.call_args.args[0], [
            "tmux", "-S", str(self.directory / "tmux.sock"), "-f", "/dev/null",
            "attach-session", "-t", "vm",
        ])
        self.assertNotIn("TMUX", run.call_args.kwargs["env"])

    def test_tmux_rejects_socket_symlink(self):
        (self.directory / "tmux.sock").symlink_to("/tmp/elsewhere")
        with self.assertRaises(RuntimeError):
            session.tmux(self.directory, "has-session")

    def test_status_and_absent_attach(self):
        with patch.object(session, "runtime_directory", return_value=self.directory):
            with patch.object(session, "has_session", return_value=False):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    self.assertEqual(vm.status(self.args), 1)
                self.assertIn("stopped", output.getvalue())
                with contextlib.redirect_stderr(io.StringIO()) as output:
                    self.assertEqual(vm.attach(self.args), 1)
                self.assertIn("lsy vm run", output.getvalue())
            with patch.object(session, "has_session", return_value=True):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    self.assertEqual(vm.status(self.args), 0)
                self.assertIn("running", output.getvalue())

    def test_attach_configures_ctrl_b_prefix(self):
        with patch.object(session, "runtime_directory", return_value=self.directory):
            with patch.object(session, "has_session", return_value=True):
                with patch.object(session, "tmux", return_value=subprocess.CompletedProcess([], 0)) as tmux:
                    self.assertEqual(vm.attach(self.args), 0)
        tmux.assert_called_once_with(
            self.directory,
            "set-option", "-t", "vm", "prefix", "C-b", ";",
            "unbind-key", "-T", "prefix", "C-s", ";",
            "bind-key", "-T", "prefix", "C-b", "send-prefix", ";",
            "attach-session", "-t", "vm",
        )

    def test_status_detects_orphaned_processes(self):
        with patch.object(session, "runtime_directory", return_value=self.directory):
            with patch.object(session, "has_session", return_value=False):
                with patch.object(session, "live_processes", return_value=[123]):
                    with contextlib.redirect_stdout(io.StringIO()) as output:
                        self.assertEqual(vm.status(self.args), 0)
        self.assertIn("without a console", output.getvalue())
        self.assertIn("lsy vm stop", output.getvalue())

    def exercise_stop(self, waits, qmp_error=None):
        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(session, "runtime_directory", return_value=self.directory))
            stack.enter_context(patch.object(session, "has_session", return_value=True))
            stack.enter_context(patch.object(session, "live_processes", return_value=[]))
            qmp = stack.enter_context(patch.object(session, "qmp", side_effect=qmp_error))
            tmux = stack.enter_context(patch.object(session, "tmux"))
            cleanup = stack.enter_context(patch.object(session, "cleanup"))
            stack.enter_context(patch.object(vm, "wait_stopped", side_effect=waits))
            output = stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
            stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
            code = vm.stop(self.args)
        return code, qmp, tmux, cleanup, output.getvalue()

    def test_graceful_stop(self):
        code, qmp, tmux, cleanup, output = self.exercise_stop([True])
        self.assertEqual(code, 0)
        qmp.assert_called_once_with(self.directory, "system_powerdown")
        tmux.assert_not_called()
        cleanup.assert_called_once_with(self.directory)
        self.assertNotIn("forcing", output)

    def test_forced_qmp_stop(self):
        code, qmp, tmux, cleanup, output = self.exercise_stop([False, True])
        self.assertEqual(code, 0)
        self.assertEqual([call.args[1] for call in qmp.call_args_list], ["system_powerdown", "quit"])
        tmux.assert_not_called()
        cleanup.assert_called_once()
        self.assertIn("forcing", output)

    def test_tmux_fallback_and_retention_on_failure(self):
        code, _, tmux, cleanup, _ = self.exercise_stop([False, False, True], OSError())
        self.assertEqual(code, 0)
        self.assertEqual(tmux.call_args.args[1], "kill-session")
        cleanup.assert_called_once()
        code, _, _, cleanup, output = self.exercise_stop([False] * 4, OSError())
        self.assertEqual(code, 1)
        cleanup.assert_not_called()
        self.assertIn("retaining state", output)

    def test_cleanup_does_not_follow_work_symlink(self):
        target = self.directory / "precious"
        target.mkdir(mode=0o700)
        (target / "data").touch()
        (self.directory / "work").symlink_to(target)
        with self.assertRaises(RuntimeError):
            session.cleanup(self.directory)
        self.assertTrue((target / "data").exists())

    def test_process_identity_rejects_reused_pid(self):
        (self.directory / "processes.json").write_text(json.dumps([[123, "old"], [456, "current"]]))
        with patch.object(session, "identity", side_effect=["new", "current"]):
            self.assertEqual(session.live_processes(self.directory), [456])

    def test_qmp_handshake_and_events(self):
        connection = MagicMock()
        stream = MagicMock()
        connection.__enter__.return_value = connection
        connection.makefile.return_value.__enter__.return_value = stream
        stream.readline.side_effect = [b'{"QMP": {}}\n', b'{"return": {}}\n',
                                       b'{"event": "SHUTDOWN"}\n', b'{"return": {}}\n']
        with patch.object(session.socket, "socket", return_value=connection):
            session.qmp(self.directory, "system_powerdown")
        self.assertEqual([json.loads(call.args[0])["execute"] for call in stream.write.call_args_list],
                         ["qmp_capabilities", "system_powerdown"])

    def test_supervisor_natural_exit_cleans_before_return(self):
        process = MagicMock(pid=123)
        process.wait.return_value = 0
        process.poll.return_value = 0
        session.private_directory(self.directory / "work")
        (self.directory / "work/control.sock").touch()
        with patch.object(session.subprocess, "Popen", return_value=process):
            with patch.object(session, "identity", return_value="started"):
                self.assertEqual(session.supervise(self.directory), 0)
        self.assertFalse((self.directory / "work").exists())
        self.assertFalse((self.directory / "processes.json").exists())
        self.assertTrue(self.directory.exists())

    def test_supervisor_hup_kills_stubborn_child_and_restores_signals(self):
        process = MagicMock(pid=123)
        process.poll.return_value = None
        handlers = {}

        def install(sig, handler):
            handlers[sig] = handler
            return signal.SIG_DFL

        def first_wait(timeout):
            handlers[signal.SIGHUP](signal.SIGHUP, None)
            process.wait.side_effect = [subprocess.TimeoutExpired("runner", 5), 0]
            raise subprocess.TimeoutExpired("runner", timeout)

        process.wait.side_effect = first_wait
        with patch.object(session.subprocess, "Popen", return_value=process):
            with patch.object(session, "identity", return_value="started"):
                with patch.object(session.signal, "signal", side_effect=install):
                    with patch.object(session.os, "killpg") as kill:
                        self.assertEqual(session.supervise(self.directory), 128 + signal.SIGTERM)
        self.assertIn(((123, signal.SIGKILL),), kill.call_args_list)
        self.assertTrue(all(handler == signal.SIG_DFL for handler in handlers.values()))
        self.assertFalse((self.directory / "work").exists())


if __name__ == "__main__":
    unittest.main()
