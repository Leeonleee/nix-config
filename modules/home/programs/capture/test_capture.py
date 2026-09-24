"""Pure backend tests: python -m unittest discover -s modules/home/programs/capture."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("capture_backend", Path(__file__).with_name("capture.py"))
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)
backend.TOOLS = {name: "/mock/" + name for name in ("slurp", "recorder", "systemctl")}


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        environment = patch.dict(os.environ, {"XDG_RUNTIME_DIR": self.temporary.name})
        environment.start()
        self.addCleanup(environment.stop)

    def test_stale_state_is_ignored(self):
        (backend.runtime() / "state.json").write_text(json.dumps({
            "invocation": "old", "state": "recording", "since": 0,
        }))
        with patch.object(backend, "unit_properties", return_value={"ActiveState": "active", "InvocationID": "new"}):
            self.assertEqual(backend.status(), {"state": "starting", "elapsed": 0})
        for active, expected in (("inactive", "idle"), ("failed", "failed"), ("deactivating", "stopping")):
            with patch.object(backend, "unit_properties", return_value={"ActiveState": active}):
                self.assertEqual(backend.status()["state"], expected)

    def test_elapsed_is_monotonic_integer(self):
        (backend.runtime() / "state.json").write_text(json.dumps({
            "invocation": "current", "state": "recording", "since": 10.5,
        }))
        with patch.object(backend, "unit_properties", return_value={"ActiveState": "active", "InvocationID": "current"}), \
                patch.object(backend.time, "monotonic", return_value=15.9):
            self.assertEqual(backend.status(), {"state": "recording", "elapsed": 5})

    def test_region_cancel_preserves_clipboard(self):
        with patch.object(backend.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "")), \
                patch.object(backend, "clipboard") as clipboard:
            backend.recognition("ocr")
            clipboard.assert_not_called()

    def test_recognition_failure_preserves_clipboard(self):
        with patch.object(backend.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "0,0 10x10", "")), \
                patch.object(backend, "run", side_effect=subprocess.CalledProcessError(1, "grim")), \
                patch.object(backend, "clipboard") as clipboard:
            with self.assertRaises(subprocess.CalledProcessError):
                backend.recognition("qr")
            clipboard.assert_not_called()

    def test_empty_text_preserves_clipboard(self):
        with patch.object(backend, "run") as run:
            with self.assertRaises(ValueError):
                backend.clipboard(" \n")
            run.assert_not_called()

    def test_toggle_running_requests_stop(self):
        with patch.object(backend, "status", return_value={"state": "recording"}), patch.object(backend, "run") as run:
            backend.record("toggle")
            run.assert_called_once_with("systemctl", "--user", "--no-block", "stop", backend.UNIT)

    def test_toggle_idle_starts_without_resetting_unloaded_unit(self):
        with patch.object(backend, "status", return_value={"state": "idle"}), \
                patch.dict(os.environ, {"XDG_RUNTIME_DIR": self.temporary.name}, clear=True), \
                patch.object(backend, "run") as run:
            backend.record("toggle")
            run.assert_called_once_with("systemctl", "--user", "start", backend.UNIT)

    def test_toggle_failed_resets_before_start(self):
        with patch.object(backend, "status", return_value={"state": "failed"}), \
                patch.dict(os.environ, {"XDG_RUNTIME_DIR": self.temporary.name}, clear=True), \
                patch.object(backend, "run") as run:
            backend.record("toggle")
            self.assertEqual([call.args for call in run.call_args_list], [
                ("systemctl", "--user", "reset-failed", backend.UNIT),
                ("systemctl", "--user", "start", backend.UNIT),
            ])

    def test_stop_idle_does_not_start(self):
        with patch.object(backend, "status", return_value={"state": "idle"}), patch.object(backend, "run") as run:
            backend.record("stop")
            run.assert_not_called()

    def test_stop_failed_clears_failure_without_starting(self):
        with patch.object(backend, "status", return_value={"state": "failed"}), patch.object(backend, "run") as run:
            backend.record("stop")
            run.assert_called_once_with("systemctl", "--user", "reset-failed", backend.UNIT)

    def test_native_colour_cancel_preserves_clipboard(self):
        with patch.object(backend.sys, "argv", ["capture", "colour"]), \
                patch.object(backend, "run", return_value=subprocess.CompletedProcess([], 0, "null")), \
                patch.object(backend, "clipboard") as clipboard:
            self.assertEqual(backend.main(), 0)
            clipboard.assert_not_called()


if __name__ == "__main__":
    unittest.main()
