import argparse
import contextlib
import io
import json
import os
from pathlib import Path
import socket
import stat
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch

from lsy.cli import main
from lsy.commands import windows_vm as windows


def completed(code=0, stdout="", stderr=""):
    return subprocess.CompletedProcess([], code, stdout, stderr)


class FakeDocker:
    """Tracks the one container the Windows VM commands manage."""

    def __init__(self, state=None):
        self.state = state
        self.calls = []
        self.down_fails = False

    def __call__(self, *arguments, **kwargs):
        self.calls.append(arguments)
        if arguments[:2] == ("container", "inspect"):
            if self.state is None:
                return completed(1, stderr="Error: No such container: lsy-windows")
            return completed(stdout=f"{self.state}\n")
        if arguments[0] == "compose":
            action = arguments[5]
            if action == "up":
                self.state = "running"
            elif action == "down" and not self.down_fails:
                self.state = None
            return completed()
        if arguments[:2] == ("container", "stop"):
            self.state = "exited"
        elif arguments[:2] == ("container", "rm"):
            self.state = None
        return completed()

    def compose_actions(self):
        return [call[5] for call in self.call_list("compose")]

    def call_list(self, command):
        return [call for call in self.calls if call[0] == command]


class WindowsVmTestCase(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.home = self.root / "home"
        self.runtime = self.root / "runtime"
        self.home.mkdir()
        self.runtime.mkdir(mode=0o700)
        environment = patch.dict(os.environ, {
            "HOME": str(self.home),
            "XDG_RUNTIME_DIR": str(self.runtime),
        })
        environment.start()
        self.addCleanup(environment.stop)
        os.environ.pop("XDG_CONFIG_HOME", None)
        self.paths = windows.paths()
        self.docker = FakeDocker()
        for patcher in (
            patch.object(windows, "docker", self.docker),
            patch.object(windows, "notify"),
            patch.object(windows, "rdp_ready", return_value=True),
            patch.object(windows.time, "sleep"),
            patch.object(windows.pwd, "getpwuid", return_value=argparse.Namespace(pw_name="alice")),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)

    def installed(self, username="alice", password="secret pa$$ word"):
        p = self.paths
        windows.ensure_directory(p.storage, 0o700)
        p.shared.mkdir()
        windows.ensure_directory(p.config, 0o700)
        windows.ensure_directory(p.oem, 0o700)
        windows.write_private(p.credentials, f"USERNAME={username}\nPASSWORD={password}\n")
        settings = {"ram": 8, "cpus": 4, "disk": 80}
        windows.write_compose(p, settings)
        windows.write_private(p.settings, json.dumps(settings))
        return p

    def run_quietly(self, function, args, stdin=None):
        with contextlib.ExitStack() as stack:
            stdout = stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
            stderr = stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
            if stdin is not None:
                stack.enter_context(patch("builtins.input", side_effect=stdin))
            code = function(args)
        return code, stdout.getvalue(), stderr.getvalue()


class CliTests(unittest.TestCase):
    def test_nested_commands_parse(self):
        for argv in (["windows", "--help"], ["windows", "vm", "--help"],
                     *(["windows", "vm", name, "--help"] for name in
                       ("install", "launch", "status", "stop", "console", "remove"))):
            with self.subTest(argv=argv), contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    main(argv)
                self.assertEqual(error.exception.code, 0)

    def test_invalid_usage(self):
        for argv in (["windows"], ["windows", "vm"], ["windows", "vm", "unknown"],
                     ["windows", "run"], ["windows", "vm", "launch", "--unknown"]):
            with self.subTest(argv=argv), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    main(argv)
                self.assertEqual(error.exception.code, 2)

    def test_dispatch(self):
        with patch.object(windows, "launch", return_value=0) as launch:
            # main() registers handlers on each call, so it picks up the patch.
            self.assertEqual(main(["windows", "vm", "launch", "--keep-alive"]), 0)
        self.assertTrue(launch.call_args.args[0].keep_alive)


class ComposeTests(WindowsVmTestCase):
    def test_definition(self):
        p = self.installed()
        service = windows.compose_definition(p, {"ram": 8, "cpus": 4, "disk": 80})["services"]["windows"]
        self.assertEqual(service["environment"], {
            "VERSION": "11", "RAM_SIZE": "8G", "CPU_CORES": "4", "DISK_SIZE": "80G",
        })
        self.assertTrue(all(port.startswith("127.0.0.1:") for port in service["ports"]))
        self.assertEqual(service["devices"], ["/dev/kvm", "/dev/net/tun"])
        self.assertEqual(service["cap_add"], ["NET_ADMIN"])
        self.assertEqual(service["restart"], "no")
        volumes = {volume["target"]: volume for volume in service["volumes"]}
        self.assertEqual(volumes["/storage"]["source"], str(self.home / ".windows"))
        self.assertEqual(volumes["/shared"]["source"], str(self.home / "Windows"))
        self.assertTrue(volumes["/oem"]["read_only"])
        self.assertTrue(all(not volume["bind"]["create_host_path"] for volume in volumes.values()))
        self.assertEqual(service["env_file"], [{"path": str(p.credentials), "format": "raw"}])

    def test_generated_file_has_no_credentials_and_is_private(self):
        p = self.installed(password="hunter2-unique")
        text = p.compose.read_text()
        self.assertNotIn("hunter2-unique", text)
        json.loads(text.split("\n", 1)[1])
        for path in (p.compose, p.credentials, p.settings):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(p.config.stat().st_mode), 0o700)

    def test_dollar_is_escaped_in_paths(self):
        p = windows.Paths(Path("/home/a$b"), Path("/home/a$b/.config"))
        service = windows.compose_definition(p, {"ram": 8, "cpus": 4, "disk": 80})["services"]["windows"]
        self.assertEqual(service["volumes"][0]["source"], "/home/a$$b/.windows")

    def test_xdg_config_home(self):
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.root / "xdg")}):
            self.assertEqual(windows.paths().config, self.root / "xdg/lsy/windows")
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": "relative"}):
            with self.assertRaises(RuntimeError):
                windows.paths()

    def test_credentials_round_trip(self):
        p = self.installed(username="bob", password="a=b $c 'd\" ")
        self.assertEqual(windows.read_credentials(p), ("bob", "a=b $c 'd\" "))


class InstallTests(WindowsVmTestCase):
    def setUp(self):
        super().setUp()
        for target, value in (("preflight", []), ("resource_problems", [])):
            patcher = patch.object(windows, target, return_value=value)
            patcher.start()
            self.addCleanup(patcher.stop)
        tty = patch.object(windows.sys.stdin, "isatty", return_value=True)
        tty.start()
        self.addCleanup(tty.stop)
        self.args = argparse.Namespace(ram=8, cpus=4, disk=80, no_start=False)

    def install(self, usernames=("alice",), passwords=("pw", "pw"), args=None):
        with patch.object(windows.getpass, "getpass", side_effect=passwords):
            return self.run_quietly(windows.install, args or self.args, stdin=list(usernames))

    def test_creates_configuration_and_starts(self):
        code, output, _ = self.install()
        self.assertEqual(code, 0, output)
        p = self.paths
        self.assertEqual(windows.read_credentials(p), ("alice", "pw"))
        self.assertEqual(json.loads(p.settings.read_text()), {"ram": 8, "cpus": 4, "disk": 80})
        self.assertEqual(stat.S_IMODE(p.storage.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(p.config.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(p.credentials.stat().st_mode), 0o600)
        self.assertTrue((p.shared / "README.txt").is_file())
        self.assertIn(b"\r\n", (p.oem / "install.bat").read_bytes())
        self.assertIn(r"\\host.lan\Data", (p.oem / "install.bat").read_text())
        self.assertEqual(self.docker.compose_actions(), ["up"])
        self.assertIn("lsy windows vm console", output)

    def test_no_start(self):
        code, _, _ = self.install(args=argparse.Namespace(ram=8, cpus=4, disk=80, no_start=True))
        self.assertEqual(code, 0)
        self.assertTrue(self.paths.settings.is_file())
        self.assertEqual(self.docker.compose_actions(), [])

    def test_existing_shared_folder_is_untouched(self):
        self.paths.shared.mkdir()
        (self.paths.shared / "notes.txt").write_text("mine")
        self.assertEqual(self.install()[0], 0)
        self.assertEqual(sorted(p.name for p in self.paths.shared.iterdir()), ["notes.txt"])

    def test_retries_invalid_input(self):
        code, _, errors = self.install(usernames=("bad name", "ends.", ""),
                                       passwords=("", "multi\nline", "pw", "other", "pw", "pw"))
        self.assertEqual(code, 0)
        # An empty answer selects the host account name.
        self.assertEqual(windows.read_credentials(self.paths), ("alice", "pw"))
        self.assertIn("do not match", errors)
        self.assertIn("line breaks", errors)

    def test_refuses_reinstall(self):
        self.installed()
        before = self.paths.credentials.read_text()
        code, _, errors = self.install()
        self.assertEqual(code, 1)
        self.assertIn("already installed", errors)
        self.assertEqual(self.paths.credentials.read_text(), before)

    def test_preflight_failure_writes_nothing(self):
        with patch.object(windows, "preflight", return_value=["xfreerdp (FreeRDP 3) was not found on PATH"]):
            code, _, errors = self.install()
        self.assertEqual(code, 1)
        self.assertIn("xfreerdp", errors)
        self.assertFalse(self.paths.config.exists())
        self.assertFalse(self.paths.storage.exists())

    def test_requires_terminal(self):
        with patch.object(windows.sys.stdin, "isatty", return_value=False):
            code, _, errors = self.install()
        self.assertEqual(code, 1)
        self.assertIn("interactive terminal", errors)

    def test_cancelled_prompt(self):
        with patch("builtins.input", side_effect=EOFError), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(windows.install(self.args), 1)
        self.assertFalse(self.paths.settings.exists())

    def test_refuses_symlinked_storage(self):
        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        self.paths.storage.symlink_to(elsewhere)
        code, _, errors = self.install()
        self.assertEqual(code, 1)
        self.assertIn("unsafe directory", errors)
        self.assertFalse(self.paths.settings.exists())


class PreflightTests(WindowsVmTestCase):
    def check(self, which=True, devices=True, free=10**15, daemon=0):
        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(windows.shutil, "which",
                                             return_value="/bin/tool" if which else None))
            stack.enter_context(patch.object(windows, "is_char_device", return_value=devices))
            stack.enter_context(patch.object(windows.shutil, "disk_usage",
                                             return_value=argparse.Namespace(free=free)))
            self.docker.calls.clear()
            with patch.object(windows, "docker", return_value=completed(daemon)):
                return windows.preflight(self.paths, 80)

    def test_passes(self):
        self.assertEqual(self.check(), [])

    def test_reports_each_problem(self):
        self.assertTrue(any("docker was not found" in p for p in self.check(which=False)))
        self.assertTrue(any("xfreerdp" in p for p in self.check(which=False)))
        problems = self.check(devices=False)
        self.assertTrue(any("/dev/kvm" in p for p in problems))
        self.assertTrue(any("/dev/net/tun" in p for p in problems))
        self.assertTrue(any("Docker daemon" in p for p in self.check(daemon=1)))

    def test_disk_space(self):
        self.assertTrue(any("GiB free" in p for p in self.check(free=50 * windows.GIB)))
        self.assertEqual(self.check(free=90 * windows.GIB), [])
        # An existing disk only needs room for downloads.
        self.paths.storage.mkdir()
        (self.paths.storage / "data.img").touch()
        self.assertEqual(self.check(free=11 * windows.GIB), [])

    def test_resources(self):
        self.assertEqual(windows.resource_problems(8, 2, 64), [])
        self.assertEqual(len(windows.resource_problems(2, 1, 32)), 3)
        self.assertTrue(windows.resource_problems(10**6, 2, 64))
        self.assertTrue(windows.resource_problems(8, 10**6, 64))


class LaunchTests(WindowsVmTestCase):
    def setUp(self):
        super().setUp()
        self.p = self.installed(username="alice", password="s3cret")
        which = patch.object(windows.shutil, "which", return_value="/bin/xfreerdp")
        which.start()
        self.addCleanup(which.stop)
        self.freerdp = patch.object(windows.subprocess, "run", return_value=completed(0))
        self.run = self.freerdp.start()
        self.addCleanup(self.freerdp.stop)
        scale = patch.object(windows, "compositor_scale", return_value=None)
        self.compositor_scale = scale.start()
        self.addCleanup(scale.stop)

    def launch(self, keep_alive=False, timeout=5):
        return self.run_quietly(windows.launch, argparse.Namespace(keep_alive=keep_alive, timeout=timeout))

    def test_starts_connects_and_stops(self):
        code, output, _ = self.launch()
        self.assertEqual(code, 0)
        self.assertEqual(self.docker.compose_actions(), ["up", "down"])
        self.assertIsNone(self.docker.state)
        self.assertIn("stopped", output)
        command = self.run.call_args.args[0]
        self.assertEqual(command, ["/bin/xfreerdp", "/args-from:stdin"])
        arguments = self.run.call_args.kwargs["input"].splitlines()
        self.assertIn("/p:s3cret", arguments)
        self.assertIn("/u:alice", arguments)
        for option in ("+dynamic-resolution", "+clipboard", "/sound", "/microphone"):
            self.assertIn(option, arguments)
        self.assertNotIn("/f", arguments)
        self.assertTrue(all("s3cret" not in part for part in command))

    def test_keep_alive_leaves_vm_running(self):
        code, output, _ = self.launch(keep_alive=True)
        self.assertEqual(code, 0)
        self.assertEqual(self.docker.compose_actions(), ["up"])
        self.assertEqual(self.docker.state, "running")
        self.assertIn("left running", output)

    def test_reuses_running_vm(self):
        self.docker.state = "running"
        self.assertEqual(self.launch()[0], 0)
        self.assertEqual(self.docker.compose_actions(), ["down"])

    def test_regenerates_compose(self):
        self.p.compose.write_text("stale")
        self.launch()
        self.assertTrue(self.p.compose.read_text().startswith(windows.COMPOSE_HEADER))

    def test_rdp_timeout_leaves_vm_running(self):
        with patch.object(windows, "rdp_ready", return_value=False), \
                patch.object(windows.time, "monotonic", side_effect=[0, 0, 10, 20]):
            code, _, errors = self.launch()
        self.assertEqual(code, 1)
        self.assertIn("left running", errors)
        self.run.assert_not_called()
        self.assertEqual(self.docker.state, "running")

    def test_freerdp_failure_still_stops(self):
        self.run.return_value = completed(132)
        code, _, errors = self.launch()
        self.assertEqual(code, 132)
        self.assertIn("credentials", errors)
        self.assertIsNone(self.docker.state)

    def test_normal_session_end_codes(self):
        for exit_code in (0, 11, 12):
            self.run.return_value = completed(exit_code)
            self.assertEqual(self.launch()[0], 0)
            self.assertEqual(self.run.call_count, 1)
            self.run.reset_mock()

    def test_server_disconnect_reconnects(self):
        # Windows drops the connection while applying display scaling.
        self.run.side_effect = [completed(1), completed(0)]
        code, output, _ = self.launch()
        self.assertEqual(code, 0)
        self.assertEqual(self.run.call_count, 2)
        self.assertIn("reconnecting", output)
        self.assertEqual(self.docker.compose_actions(), ["up", "down"])

    def test_repeated_quick_disconnects_give_up(self):
        self.run.return_value = completed(1)
        code, _, errors = self.launch()
        self.assertEqual(code, 1)
        self.assertEqual(self.run.call_count, windows.MAX_QUICK_RECONNECTS + 1)
        self.assertIn("giving up", errors)
        self.assertIsNone(self.docker.state)

    def test_long_sessions_reset_the_reconnect_limit(self):
        self.run.side_effect = [completed(1)] * 6 + [completed(0)]
        # Each session lasts two minutes.
        clock = iter(range(0, 100000, 120))
        with patch.object(windows.time, "monotonic", side_effect=lambda: next(clock)):
            self.assertEqual(self.launch(timeout=10**6)[0], 0)
        self.assertEqual(self.run.call_count, 7)

    def test_passes_compositor_scale(self):
        self.compositor_scale.return_value = 1.5
        self.launch()
        arguments = self.run.call_args.kwargs["input"].splitlines()
        self.assertIn("/scale-desktop:150", arguments)
        self.assertIn("/scale:140", arguments)

    def test_preferred_scale_wins(self):
        self.compositor_scale.return_value = 1.5
        self.p.preferences.write_text(json.dumps({"scale": 175}))
        self.launch()
        arguments = self.run.call_args.kwargs["input"].splitlines()
        self.assertIn("/scale-desktop:175", arguments)
        self.assertIn("/scale:180", arguments)

    def test_invalid_preferences_fall_back_to_compositor(self):
        self.compositor_scale.return_value = 1.5
        for text in ("not json", json.dumps({"scale": 50}), json.dumps({"scale": True}), "[]"):
            with self.subTest(text=text):
                self.p.preferences.write_text(text)
                self.launch()
                self.assertIn("/scale-desktop:150", self.run.call_args.kwargs["input"].splitlines())

    def test_unknown_scale_sends_nothing(self):
        self.launch()
        self.assertFalse(any("/scale" in line for line in self.run.call_args.kwargs["input"].splitlines()))

    def test_interrupted_freerdp_still_stops(self):
        self.run.side_effect = KeyboardInterrupt
        with self.assertRaises(KeyboardInterrupt), contextlib.redirect_stdout(io.StringIO()):
            windows.launch(argparse.Namespace(keep_alive=False, timeout=5))
        self.assertIsNone(self.docker.state)

    def test_not_installed(self):
        self.p.settings.unlink()
        code, _, errors = self.launch()
        self.assertEqual(code, 1)
        self.assertIn("lsy windows vm install", errors)
        self.assertEqual(self.docker.calls, [])

    def test_compose_failure(self):
        with patch.object(windows, "compose", return_value=completed(1)):
            code, _, errors = self.launch()
        self.assertEqual(code, 1)
        self.assertIn("could not start", errors)
        self.run.assert_not_called()

    def test_single_session(self):
        with windows.session_lock("busy"):
            code, _, errors = self.launch()
        self.assertEqual(code, 1)
        self.assertIn("already open", errors)
        self.assertEqual(self.docker.compose_actions(), [])


class WaitTests(WindowsVmTestCase):
    def test_requires_consecutive_confirmations(self):
        self.docker.state = "running"
        with patch.object(windows, "rdp_ready", side_effect=[True, False, True, True]) as ready:
            self.assertTrue(windows.wait_for_rdp(60))
        self.assertEqual(ready.call_count, 4)

    def test_container_exit_is_an_error(self):
        self.docker.state = "exited"
        with self.assertRaisesRegex(RuntimeError, "stopped unexpectedly"):
            windows.wait_for_rdp(60)


class ScaleTests(unittest.TestCase):
    def detect(self, environment, stdout):
        with patch.dict(os.environ, environment, clear=True), \
                patch.object(windows.shutil, "which", return_value="/bin/tool"), \
                patch.object(windows.subprocess, "run", return_value=completed(stdout=stdout)) as run:
            return windows.compositor_scale(), run

    def test_hyprland_focused_monitor(self):
        monitors = [{"name": "eDP-1", "scale": 1.5, "focused": False},
                    {"name": "DP-2", "scale": 1.25, "focused": True}]
        scale, run = self.detect({"HYPRLAND_INSTANCE_SIGNATURE": "x"}, json.dumps(monitors))
        self.assertEqual(scale, 1.25)
        self.assertEqual(run.call_args.args[0], ["hyprctl", "-j", "monitors"])

    def test_niri_focused_output(self):
        scale, run = self.detect({"NIRI_SOCKET": "/run/niri"}, json.dumps({"logical": {"scale": 1.5}}))
        self.assertEqual(scale, 1.5)
        self.assertEqual(run.call_args.args[0], ["niri", "msg", "--json", "focused-output"])

    def test_unavailable(self):
        self.assertIsNone(self.detect({}, "")[0])
        self.assertIsNone(self.detect({"NIRI_SOCKET": "/run/niri"}, "not json")[0])
        self.assertIsNone(self.detect({"HYPRLAND_INSTANCE_SIGNATURE": "x"}, "[]")[0])

    def test_arguments(self):
        self.assertEqual(windows.scale_arguments(None), [])
        self.assertEqual(windows.scale_arguments(100), ["/scale-desktop:100", "/scale:100"])
        self.assertEqual(windows.scale_arguments(200), ["/scale-desktop:200", "/scale:180"])
        p = windows.Paths(Path("/nonexistent"), Path("/nonexistent/.config"))
        with patch.object(windows, "compositor_scale", return_value=9.0):
            self.assertEqual(windows.scale_percent(p), 500)
        with patch.object(windows, "compositor_scale", return_value=0.5):
            self.assertEqual(windows.scale_percent(p), 100)


class RdpProbeTests(unittest.TestCase):
    def serve(self, reply):
        server = socket.socket()
        server.bind(("127.0.0.1", 0))
        server.listen()
        self.addCleanup(server.close)
        received = []

        def respond():
            connection, _ = server.accept()
            with connection:
                received.append(connection.recv(64))
                if reply:
                    connection.sendall(reply)

        thread = threading.Thread(target=respond, daemon=True)
        thread.start()
        return server.getsockname()[1], thread, received

    def test_connection_confirm(self):
        confirm = bytes.fromhex("03000013" "0ed00000123400" "0200080002000000")
        port, thread, received = self.serve(confirm)
        self.assertTrue(windows.rdp_ready(port=port, timeout=2))
        thread.join()
        self.assertEqual(received, [windows.RDP_PROBE])

    def test_proxy_that_closes(self):
        port, thread, _ = self.serve(b"")
        self.assertFalse(windows.rdp_ready(port=port, timeout=2))
        thread.join()

    def test_not_rdp(self):
        port, thread, _ = self.serve(b"HTTP/1.1 400 Bad Request\r\n\r\n")
        self.assertFalse(windows.rdp_ready(port=port, timeout=2))
        thread.join()

    def test_refused(self):
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        self.assertFalse(windows.rdp_ready(port=port, timeout=1))


class StatusTests(WindowsVmTestCase):
    def status(self):
        return self.run_quietly(windows.status, argparse.Namespace())

    def test_not_installed(self):
        code, output, _ = self.status()
        self.assertEqual(code, 1)
        self.assertIn("not installed", output)

    def test_stopped(self):
        self.installed()
        code, output, _ = self.status()
        self.assertEqual(code, 1)
        self.assertIn("Windows VM: stopped", output)
        self.assertIn("~/.windows", output)
        self.assertIn("~/Windows (Z: in Windows)", output)
        self.assertIn("8 GiB RAM, 4 CPUs, 80 GiB disk", output)

    def test_starting_and_running(self):
        self.installed()
        self.docker.state = "running"
        with patch.object(windows, "rdp_ready", return_value=False):
            code, output, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn("Windows VM: starting", output)
        code, output, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn("Windows VM: running", output)
        self.assertIn(windows.CONSOLE_URL, output)

    def test_orphaned_container(self):
        self.docker.state = "running"
        code, output, _ = self.status()
        self.assertEqual(code, 0)
        self.assertIn("lsy windows vm stop", output)

    def test_docker_unavailable(self):
        with patch.object(windows, "docker", return_value=completed(1, stderr="permission denied")):
            code, _, errors = self.status()
        self.assertEqual(code, 1)
        self.assertIn("permission denied", errors)


class StopTests(WindowsVmTestCase):
    def stop(self):
        return self.run_quietly(windows.stop, argparse.Namespace())

    def test_idempotent(self):
        self.installed()
        self.assertEqual(self.stop()[0], 0)
        self.assertEqual(self.stop()[0], 0)
        self.assertEqual(self.docker.compose_actions(), [])

    def test_graceful_timeout(self):
        self.installed()
        self.docker.state = "running"
        code, output, _ = self.stop()
        self.assertEqual(code, 0)
        down = self.docker.call_list("compose")[0]
        self.assertEqual(down[5:], ("down", "--timeout", "120"))
        self.assertIn("Shutting down", output)

    def test_without_configuration(self):
        self.docker.state = "running"
        self.assertEqual(self.stop()[0], 0)
        self.assertEqual(self.docker.call_list("container")[1],
                         ("container", "stop", "--time", "120", "lsy-windows"))
        self.assertIsNone(self.docker.state)

    def test_failure(self):
        self.installed()
        self.docker.state = "running"
        self.docker.down_fails = True
        code, _, errors = self.stop()
        self.assertEqual(code, 1)
        self.assertIn("could not stop", errors)


class ConsoleTests(WindowsVmTestCase):
    def test_starts_and_opens(self):
        self.installed()
        with patch.object(windows, "console_ready", return_value=True), \
                patch.object(windows.shutil, "which", return_value="/bin/xdg-open"), \
                patch.object(windows.subprocess, "run") as run:
            code, output, _ = self.run_quietly(windows.console, argparse.Namespace())
        self.assertEqual(code, 0)
        self.assertEqual(self.docker.state, "running")
        self.assertEqual(run.call_args.args[0], ["/bin/xdg-open", "http://127.0.0.1:8006/"])
        self.assertIn("keeps running", output)

    def test_not_installed(self):
        code, _, errors = self.run_quietly(windows.console, argparse.Namespace())
        self.assertEqual(code, 1)
        self.assertEqual(self.docker.calls, [])


class RemoveTests(WindowsVmTestCase):
    def setUp(self):
        super().setUp()
        self.p = self.installed()
        (self.p.storage / "data.img").write_bytes(b"disk")
        (self.p.shared / "document.txt").write_text("keep me")
        self.docker.state = "exited"

    def remove(self, answer=windows.CONFIRMATION):
        return self.run_quietly(windows.remove, argparse.Namespace(), stdin=[answer])

    def assert_untouched(self):
        self.assertTrue((self.p.storage / "data.img").is_file())
        self.assertTrue(self.p.settings.is_file())
        self.assertEqual((self.p.shared / "document.txt").read_text(), "keep me")

    def test_confirmed_removal_preserves_shared_folder(self):
        self.p.preferences.write_text('{"scale": 175}')
        code, output, _ = self.remove()
        self.assertTrue(self.p.preferences.is_file())
        self.assertIn("~/.config/lsy/windows.json", output)
        self.assertEqual(code, 0, output)
        self.assertFalse(self.p.storage.exists())
        self.assertFalse(self.p.config.exists())
        self.assertEqual((self.p.shared / "document.txt").read_text(), "keep me")
        self.assertIsNone(self.docker.state)
        for expected in ("~/.windows", "~/.config/lsy/windows", "Preserved:", "~/Windows"):
            self.assertIn(expected, output)

    def test_wrong_confirmation_deletes_nothing(self):
        for answer in ("", "delete windows", "DELETE WINDOWS ", "yes"):
            with self.subTest(answer=answer):
                code, output, _ = self.remove(answer)
                self.assertEqual(code, 1)
                self.assertIn("nothing was deleted", output)
                self.assert_untouched()
        self.assertEqual(self.docker.compose_actions(), [])

    def test_end_of_input_deletes_nothing(self):
        code, _, _ = self.run_quietly(windows.remove, argparse.Namespace(), stdin=EOFError)
        self.assertEqual(code, 1)
        self.assert_untouched()

    def test_container_that_will_not_stop_blocks_deletion(self):
        self.docker.state = "running"
        self.docker.down_fails = True
        code, _, errors = self.remove()
        self.assertEqual(code, 1)
        self.assertIn("could not stop", errors)
        self.assert_untouched()

    def test_refuses_symlinked_storage(self):
        target = self.root / "real-disk"
        self.p.storage.rename(target)
        self.p.storage.symlink_to(target)
        code, _, errors = self.remove()
        self.assertEqual(code, 1)
        self.assertIn("symlink", errors)
        self.assertTrue((target / "data.img").is_file())
        self.assertTrue(self.p.storage.is_symlink())
        self.assertEqual(self.docker.compose_actions(), [])

    def test_refuses_symlinked_config_parent(self):
        real = self.root / "real-lsy"
        (self.home / ".config/lsy").rename(real)
        (self.home / ".config/lsy").symlink_to(real)
        code, _, errors = self.remove()
        self.assertEqual(code, 1)
        self.assertIn("resolves through a symlink", errors)
        self.assertTrue((real / "windows/settings.json").is_file())

    def test_refuses_shared_folder_inside_storage(self):
        inside = self.p.storage / "shared"
        self.p.shared.rename(inside)
        self.p.shared.symlink_to(inside)
        code, _, errors = self.remove()
        self.assertEqual(code, 1)
        self.assertIn("inside ~/.windows", errors)
        self.assertEqual((inside / "document.txt").read_text(), "keep me")

    def test_refuses_file_in_place_of_storage(self):
        (self.p.storage / "data.img").unlink()
        self.p.storage.rmdir()
        self.p.storage.write_text("not a directory")
        code, _, errors = self.remove()
        self.assertEqual(code, 1)
        self.assertIn("not a directory", errors)
        self.assertTrue(self.p.storage.is_file())

    def test_refuses_while_session_open(self):
        with windows.session_lock("busy"):
            code, _, errors = self.remove()
        self.assertEqual(code, 1)
        self.assertIn("close the Windows session", errors)
        self.assert_untouched()

    def test_root_owned_files_are_removed_through_docker(self):
        real_rmtree = windows.shutil.rmtree
        attempts = []

        def rmtree(path):
            attempts.append(Path(path))
            if len(attempts) == 1 and Path(path) == self.p.storage:
                raise PermissionError(13, "Permission denied")
            real_rmtree(path)

        with patch.object(windows.shutil, "rmtree", side_effect=rmtree):
            code, _, _ = self.remove()
        self.assertEqual(code, 0)
        cleanup = self.docker.call_list("run")[0]
        self.assertIn(f"type=bind,source={self.p.storage},target=/storage", cleanup)
        self.assertEqual(cleanup[-5:], ("/storage", "-xdev", "-mindepth", "1", "-delete"))
        self.assertFalse(self.p.storage.exists())
        self.assertTrue((self.p.shared / "document.txt").exists())

    def test_nothing_installed(self):
        real_rmtree = windows.shutil.rmtree
        real_rmtree(self.p.storage)
        real_rmtree(self.p.config)
        self.docker.state = None
        code, output, _ = self.run_quietly(windows.remove, argparse.Namespace(), stdin=[])
        self.assertEqual(code, 0)
        self.assertIn("nothing to remove", output)
        self.assertTrue(self.p.shared.exists())

    def test_orphaned_container_without_files(self):
        real_rmtree = windows.shutil.rmtree
        real_rmtree(self.p.config)
        self.docker.state = "running"
        code, _, _ = self.remove()
        self.assertEqual(code, 0)
        self.assertIsNone(self.docker.state)
        self.assertFalse(self.p.storage.exists())


if __name__ == "__main__":
    unittest.main()
