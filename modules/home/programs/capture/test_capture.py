"""Pure backend tests: python -m unittest discover -s modules/home/programs/capture."""
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("capture_backend", Path(__file__).with_name("capture.py"))
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)
backend.TOOLS = {name: "/mock/" + name for name in ("slurp", "recorder", "systemctl", "rofi")}


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        environment = patch.dict(os.environ, {"XDG_RUNTIME_DIR": self.temporary.name})
        environment.start()
        self.addCleanup(environment.stop)

    def test_latest_capture_selects_newest_nonempty_file(self):
        home = Path(self.temporary.name)
        screenshots = home / "Pictures" / "Screenshots"
        recordings = home / "Videos" / "Recordings"
        screenshots.mkdir(parents=True)
        recordings.mkdir(parents=True)
        image = screenshots / "Screenshot with spaces.png"
        video = recordings / "Recording.mp4"
        image.write_bytes(b"image")
        video.write_bytes(b"video")
        (recordings / "empty.mp4").touch()
        os.utime(image, (100, 100))
        os.utime(video, (200, 200))
        with patch.object(backend.Path, "home", return_value=home), \
                patch.object(backend, "recording_directory", return_value=recordings), \
                patch.object(backend, "status", return_value={"state": "idle"}):
            self.assertEqual(backend.latest_capture(), str(video))
            video.unlink()
            self.assertEqual(backend.latest_capture(), str(image))
            image.unlink()
            with self.assertRaisesRegex(ValueError, "No saved"):
                backend.latest_capture()

    def test_latest_capture_refuses_unfinished_recording(self):
        for state in ("starting", "recording", "stopping", "unavailable"):
            with self.subTest(state=state), \
                    patch.object(backend, "status", return_value={"state": state}):
                with self.assertRaisesRegex(ValueError, "Stop the recording"):
                    backend.latest_capture()

    def test_failed_status_query_is_quiet_and_preserves_diagnostics(self):
        error = subprocess.CalledProcessError(1, "systemctl", stderr="Unit temporarily unavailable\n")
        with patch.object(backend.sys, "argv", ["capture", "record", "status"]), \
                patch.object(backend, "unit_properties", side_effect=error), \
                patch.object(backend, "notify") as notify, \
                patch.object(backend.sys, "stdout", new_callable=io.StringIO) as stdout, \
                patch.object(backend.sys, "stderr", new_callable=io.StringIO) as stderr:
            self.assertEqual(backend.entrypoint(), 1)
            self.assertEqual(json.loads(stdout.getvalue()), {"state": "unavailable", "elapsed": 0})
            self.assertIn("Unit temporarily unavailable", stderr.getvalue())
            notify.assert_not_called()

    def test_status_recovers_after_transient_query_failure(self):
        with patch.object(backend.sys, "argv", ["capture", "record", "status"]), \
                patch.object(backend, "unit_properties", side_effect=[
                    subprocess.CalledProcessError(1, "systemctl"), {"ActiveState": "inactive"},
                ]), \
                patch.object(backend, "notify") as notify, \
                patch.object(backend.sys, "stdout", new_callable=io.StringIO) as stdout, \
                patch.object(backend.sys, "stderr", new_callable=io.StringIO):
            self.assertEqual(backend.entrypoint(), 1)
            self.assertEqual(backend.entrypoint(), 0)
            states = [json.loads(line)["state"] for line in stdout.getvalue().splitlines()]
            self.assertEqual(states, ["unavailable", "idle"])
            notify.assert_not_called()

    def test_user_action_query_errors_still_notify(self):
        for action in ("toggle", "stop"):
            with self.subTest(action=action), \
                    patch.object(backend.sys, "argv", ["capture", "record", action]), \
                    patch.object(backend, "unit_properties", side_effect=subprocess.CalledProcessError(
                        1, "systemctl", stderr="Connection refused",
                    )), \
                    patch.object(backend, "notify") as notify, \
                    patch.object(backend.sys, "stderr", new_callable=io.StringIO):
                self.assertEqual(backend.entrypoint(), 1)
                notify.assert_called_once()
                self.assertEqual(notify.call_args.args[0], "Capture failed")
                self.assertIn("Connection refused", notify.call_args.args[1])

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
                patch.object(backend, "select_audio", return_value=[]), \
                patch.object(backend, "run") as run:
            backend.record("toggle")
            run.assert_called_once_with("systemctl", "--user", "start", backend.UNIT)

    def test_toggle_failed_resets_before_start(self):
        with patch.object(backend, "status", return_value={"state": "failed"}), \
                patch.dict(os.environ, {"XDG_RUNTIME_DIR": self.temporary.name}, clear=True), \
                patch.object(backend, "select_audio", return_value=[]), \
                patch.object(backend, "run") as run:
            backend.record("toggle")
            self.assertEqual([call.args for call in run.call_args_list], [
                ("systemctl", "--user", "reset-failed", backend.UNIT),
                ("systemctl", "--user", "start", backend.UNIT),
            ])

    def test_audio_cancel_does_not_start(self):
        with patch.object(backend, "status", return_value={"state": "idle"}), \
                patch.object(backend, "select_audio", return_value=None), \
                patch.object(backend, "run") as run:
            backend.record("toggle")
            run.assert_not_called()
            self.assertFalse((backend.runtime() / "audio.json").exists())

    def test_failed_start_discards_audio_consent(self):
        with patch.object(backend, "status", return_value={"state": "idle"}), \
                patch.dict(os.environ, {"XDG_RUNTIME_DIR": self.temporary.name}, clear=True), \
                patch.object(backend, "select_audio", return_value=["mic"]), \
                patch.object(backend, "run", side_effect=subprocess.CalledProcessError(1, "systemctl")):
            with self.assertRaises(subprocess.CalledProcessError):
                backend.record("toggle")
            self.assertFalse((backend.runtime() / "audio.json").exists())

    def test_silent_choice_does_not_query_audio_server(self):
        with patch.object(backend, "choose", return_value=0), patch.object(backend, "run") as run:
            self.assertEqual(backend.select_audio(), [])
            run.assert_not_called()

    def test_system_audio_uses_default_output_monitor(self):
        with patch.object(backend, "choose", return_value=1), \
                patch.object(backend, "run", return_value=subprocess.CompletedProcess([], 0, "speakers\n")):
            self.assertEqual(backend.select_audio(), ["speakers.monitor"])

    def test_microphone_picker_filters_monitors(self):
        devices = [
            {"name": "speakers.monitor", "monitor_of_sink": 1},
            {"name": "virtual-monitor", "monitor_of_sink": 2},
            {"name": "mic", "description": "USB microphone", "monitor_of_sink": None},
        ]
        with patch.object(backend, "choose", side_effect=[3, 0]) as choose, \
                patch.object(backend, "run", side_effect=[
                    subprocess.CompletedProcess([], 0, "speakers\n"),
                    subprocess.CompletedProcess([], 0, json.dumps(devices)),
                ]):
            self.assertEqual(backend.select_audio(), ["speakers.monitor", "mic"])
            self.assertEqual(choose.call_args.args, ("Microphone", ["USB microphone (mic)"]))

    def test_microphone_cancel_does_not_fall_back_to_system_audio(self):
        devices = [{"name": "mic", "monitor_of_sink": 4294967295}]
        with patch.object(backend, "choose", side_effect=[3, None]), \
                patch.object(backend, "run", side_effect=[
                    subprocess.CompletedProcess([], 0, "speakers\n"),
                    subprocess.CompletedProcess([], 0, json.dumps(devices)),
                ]):
            self.assertIsNone(backend.select_audio())

    def test_no_microphones_is_an_error(self):
        with patch.object(backend, "choose", return_value=2), \
                patch.object(backend, "run", return_value=subprocess.CompletedProcess([], 0, "[]")):
            with self.assertRaisesRegex(ValueError, "No microphone"):
                backend.select_audio()

    def test_audio_request_is_mixed_and_consumed_once(self):
        request = backend.runtime() / "audio.json"
        request.write_text(json.dumps(["speakers.monitor", "mic"]))
        self.assertEqual(backend.recording_audio_args(), ["-a", "speakers.monitor|mic"])
        self.assertFalse(request.exists())
        self.assertEqual(backend.recording_audio_args(), [])

    def test_invalid_audio_request_is_consumed_without_recording(self):
        request = backend.runtime() / "audio.json"
        request.write_text(json.dumps(["mic|unexpected"]))
        with self.assertRaises(ValueError):
            backend.recording_audio_args()
        self.assertFalse(request.exists())

    def test_silent_request_has_no_audio_flags(self):
        (backend.runtime() / "audio.json").write_text("[]")
        self.assertEqual(backend.recording_audio_args(), [])

    def test_rofi_cancel(self):
        with patch.object(backend.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "")):
            self.assertIsNone(backend.choose("Audio", ["No audio"]))

    def test_duplicate_toggle_does_not_queue(self):
        with patch.object(backend.fcntl, "flock", side_effect=BlockingIOError), \
                patch.object(backend, "select_audio") as select, patch.object(backend, "run") as run:
            backend.record("toggle")
            select.assert_not_called()
            run.assert_not_called()

    def check_worker_exit(self, exit_code, expected_result, expect_failure):
        child = Mock(returncode=exit_code)
        child.poll.return_value = exit_code
        with patch.object(backend.signal, "signal"), \
                patch.object(backend, "recording_audio_args", return_value=[]), \
                patch.object(backend, "run", return_value=subprocess.CompletedProcess([], 0, self.temporary.name)), \
                patch.object(backend.subprocess, "Popen", return_value=child), \
                patch.object(backend, "notify") as notify:
            self.assertEqual(backend.worker(), expected_result)
            if expect_failure:
                notify.assert_called_once_with(
                    "Recording failed", "See journalctl --user -u " + backend.UNIT, failure=True,
                )
            else:
                notify.assert_not_called()
        self.assertEqual(list((Path(self.temporary.name) / "Recordings").iterdir()), [])
        self.assertFalse((backend.runtime() / "state.json").exists())

    def test_portal_cancel_is_silent_success_and_cleans_up(self):
        self.check_worker_exit(60, 0, False)

    def test_portal_error_still_reports_failure(self):
        self.check_worker_exit(50, 1, True)

    def test_other_startup_errors_still_report_failure(self):
        self.check_worker_exit(1, 1, True)

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
