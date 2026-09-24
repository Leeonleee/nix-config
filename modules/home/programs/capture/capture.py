"""Niri capture backend. TOOLS is prepended by the Home Manager module.

Verified against pinned Niri feb3e43 and gpu-screen-recorder 5.13.8:
* Niri implements wlr-screencopy (src/handlers/mod.rs), so grim + slurp
  works here. Native screenshot --path also writes the clipboard; do not use
  it for recognition, where cancellation/failure must preserve clipboard.
* Niri's native `msg --json pick-color` returns null on cancellation.
* GSR is built with portal=true; -w portal prompts each time (no restore flag),
  requires no privileged KMS helper, and omitting -a records no audio.
* Upstream README documents SIGINT as the finalize/save operation.
"""

import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

UNIT = "capture-record.service"
# GSR 5.13.8 src/capture/portal.c; main.cpp propagates this exit code.
PORTAL_CANCELLED = 60


def run(tool, *args, **kwargs):
    return subprocess.run([TOOLS[tool], *args], check=True, **kwargs)


def notify(title, body="", failure=False):
    try:
        run("notify", "--app-name=Capture", "--urgency=" + ("critical" if failure else "normal"),
            title, body, timeout=5, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        pass


def runtime():
    directory = Path(os.environ["XDG_RUNTIME_DIR"]) / "capture"
    directory.mkdir(mode=0o700, exist_ok=True)
    return directory


def unit_properties():
    result = run("systemctl", "--user", "show", UNIT,
                 "--property=ActiveState,SubState,InvocationID", capture_output=True, text=True)
    return dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)


def status():
    properties = unit_properties()
    active = properties.get("ActiveState", "inactive")
    state = {"inactive": "idle", "failed": "failed", "deactivating": "stopping"}.get(active, "starting")
    elapsed = 0
    try:
        data = json.loads((runtime() / "state.json").read_text())
        if data["invocation"] == properties.get("InvocationID") and active in ("active", "deactivating"):
            if active == "active":
                state = data["state"]
            if data.get("since") is not None:
                elapsed = max(0, int(time.monotonic() - data["since"]))
    except (OSError, ValueError, KeyError):
        pass
    return {"state": state, "elapsed": elapsed}


def choose(prompt, labels):
    # Return an index, not a label: descriptions can be duplicated or contain
    # Rofi metadata characters. No custom input or shell interpolation.
    labels = [" ".join(label.replace("\0", " ").splitlines()) for label in labels]
    result = subprocess.run(
        [TOOLS["rofi"], "-dmenu", "-i", "-no-custom", "-format", "i", "-p", prompt],
        input="\n".join(labels) + "\n", capture_output=True, text=True,
    )
    if result.returncode == 1:
        return None
    result.check_returncode()
    index = int(result.stdout.strip())
    if not 0 <= index < len(labels):
        raise ValueError("Invalid capture menu selection")
    return index


def select_audio():
    mode = choose("Recording audio", [
        "No audio", "System audio", "Microphone", "System audio + microphone",
    ])
    if mode is None:
        return None
    sources = []
    if mode in (1, 3):
        sink = run("pactl", "get-default-sink", capture_output=True, text=True).stdout.strip()
        if not sink:
            raise ValueError("No default audio output available")
        sources.append(sink + ".monitor")
    if mode in (2, 3):
        devices = json.loads(run("pactl", "--format=json", "list", "sources",
                                 capture_output=True, text=True).stdout)
        microphones = [device for device in devices
                       if device.get("monitor_of_sink") in (None, 4294967295, "4294967295")
                       and not device["name"].endswith(".monitor")]
        if not microphones:
            raise ValueError("No microphone inputs available")
        index = choose("Microphone", [
            f"{device.get('description', device['name'])} ({device['name']})"
            for device in microphones
        ])
        if index is None:
            return None
        sources.append(microphones[index]["name"])
    return sources


def record(action):
    if action == "status":
        print(json.dumps(status()))
        return
    # Serialize the whole decision plus the systemd transaction. Type=exec
    # ensures a successful start is visible before another toggle takes the lock.
    with (runtime() / "control.lock").open("a") as lock:
        # Ignore duplicate shortcuts while a chooser or start transaction is
        # open rather than queueing a second toggle that immediately stops it.
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        current = status()["state"]
        if current in ("starting", "recording", "stopping"):
            run("systemctl", "--user", "--no-block", "stop", UNIT)
        elif action == "stop" and current == "failed":
            # Let the indicator dismiss a failed attempt without starting another.
            run("systemctl", "--user", "reset-failed", UNIT)
        elif action == "toggle":
            request = runtime() / "audio.json"
            request.unlink(missing_ok=True)
            audio = select_audio()
            if audio is None:
                return
            # The invoking compositor's environment is authoritative. Do not
            # rely on an old graphical session's socket in the user manager.
            names = [name for name in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET", "XDG_CURRENT_DESKTOP")
                     if name in os.environ]
            if names:
                run("systemctl", "--user", "import-environment", *names)
            # Inactive on-demand units can be unloaded by systemd; resetting
            # one then fails with "Unit not loaded" before start can load it.
            if current == "failed":
                run("systemctl", "--user", "reset-failed", UNIT)
            temporary = request.with_suffix(".tmp")
            temporary.write_text(json.dumps(audio))
            temporary.replace(request)
            try:
                run("systemctl", "--user", "start", UNIT)
            except (OSError, subprocess.SubprocessError):
                request.unlink(missing_ok=True)
                raise


def recording_audio_args():
    # Consume the per-recording choice once. Direct service starts are silent;
    # microphone consent never becomes a persistent default.
    request = runtime() / "audio.json"
    try:
        sources = json.loads(request.read_text())
    except FileNotFoundError:
        return []
    finally:
        request.unlink(missing_ok=True)
    if not isinstance(sources, list) or len(sources) > 2 or any(
        not isinstance(source, str) or not source or any(char in source for char in "|\n\0")
        for source in sources
    ):
        raise ValueError("Invalid recording audio sources")
    return ["-a", "|".join(sources)] if sources else []


def worker():
    directory = runtime()
    invocation = os.environ.get("INVOCATION_ID", "")
    data = {"invocation": invocation, "state": "starting", "since": None}

    def save():
        temporary = directory / "state.tmp"
        temporary.write_text(json.dumps(data))
        temporary.replace(directory / "state.json")

    stopping = False
    child = None

    def stop(_signum, _frame):
        nonlocal stopping
        if stopping:
            return
        stopping = True
        data["state"] = "stopping"
        save()
        if child is not None and child.poll() is None:
            child.send_signal(signal.SIGINT)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    save()
    output = None
    try:
        audio_args = recording_audio_args()
        videos = run("videos", "VIDEOS", capture_output=True, text=True).stdout.strip()
        base = Path(videos) if videos and Path(videos).is_absolute() else Path.home() / "Videos"
        # Some user-dirs configurations disable Videos by pointing it at HOME.
        if base == Path.home():
            base = Path.home() / "Videos"
        base = base / "Recordings"
        base.mkdir(parents=True, exist_ok=True)
        fd, name = tempfile.mkstemp(prefix=time.strftime("Recording-%Y-%m-%d_%H-%M-%S-"), suffix=".mp4", dir=base)
        os.close(fd)
        output = Path(name)
        if stopping:
            return 0
        child = subprocess.Popen([
            TOOLS["recorder"], "-w", "portal", "-f", "60", "-k", "h264",
            *audio_args, "-o", str(output),
        ])
        if stopping and child.poll() is None:
            child.send_signal(signal.SIGINT)
        while child.poll() is None:
            # GSR has no readiness protocol. A nonempty container is the first
            # observable evidence that portal selection and encoder setup passed.
            if not stopping and data["state"] == "starting" and output.stat().st_size > 0:
                data.update(state="recording", since=time.monotonic())
                save()
                notify("Recording started", str(output))
            time.sleep(0.2)
        if child.returncode == PORTAL_CANCELLED and data["since"] is None:
            # Closing the portal chooser is not a recording failure. Returning
            # success also leaves the DMS indicator idle rather than failed.
            return 0
        if child.returncode == 0 and output.stat().st_size > 0:
            notify("Recording saved", str(output))
            return 0
        if stopping and data["since"] is None:
            return 0
        notify("Recording failed", "See journalctl --user -u " + UNIT, failure=True)
        return 1
    finally:
        # Never orphan a recorder if the supervisor encounters an exception.
        if child is not None and child.poll() is None:
            child.send_signal(signal.SIGINT)
            try:
                child.wait(timeout=20)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        if output is not None and output.exists() and output.stat().st_size == 0:
            output.unlink()
        (directory / "state.json").unlink(missing_ok=True)


def clipboard(text, sensitive=False):
    if not text.strip():
        raise ValueError("No text found; clipboard unchanged")
    args = ["--type", "text/plain;charset=utf-8"]
    if sensitive:
        args.append("--sensitive")
    run("clipboard", *args, input=text.encode())


def recognition(kind):
    # slurp Escape exits nonzero; no image or clipboard owner is touched.
    selection = subprocess.run([TOOLS["slurp"], "-d"], capture_output=True, text=True)
    if selection.returncode != 0 or not selection.stdout.strip():
        return
    with tempfile.TemporaryDirectory(prefix="capture-", dir=runtime()) as temporary:
        image = str(Path(temporary) / "region.png")
        run("grim", "-g", selection.stdout.strip(), image)
        if kind == "ocr":
            text = run("tesseract", image, "stdout", capture_output=True, text=True).stdout.rstrip("\n")
        else:
            text = run("zbar", "--quiet", "--raw", "--set", "*.enable=0", "--set", "qrcode.enable=1",
                       image, capture_output=True, text=True).stdout.rstrip("\n")
        clipboard(text, sensitive=(kind == "qr"))
        notify("Text copied" if kind == "ocr" else "QR content copied")


def main():
    args = sys.argv[1:]
    if args == ["_record-worker"]:
        return worker()
    if len(args) == 2 and args[0] == "record" and args[1] in ("toggle", "stop", "status"):
        record(args[1])
    elif len(args) == 2 and args[0] == "screenshot" and args[1] in ("region", "window", "screen"):
        action = {"region": "screenshot", "window": "screenshot-window", "screen": "screenshot-screen"}[args[1]]
        run("niri", "msg", "action", action)
    elif args in (["ocr"], ["qr"]):
        recognition(args[0])
    elif args == ["colour"]:
        color = json.loads(run("niri", "msg", "--json", "pick-color", capture_output=True, text=True).stdout)
        if color is not None:
            text = "#" + "".join(f"{int(max(0, min(1, value)) * 255 + 0.5):02x}" for value in color["rgb"])
            clipboard(text)
            notify("Colour copied", text)
    else:
        print("Usage: capture screenshot region|window|screen | record toggle|stop|status | ocr | colour | qr", file=sys.stderr)
        return 2
    return 0


def entrypoint():
    try:
        return main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        detail = str(error)
        stderr = getattr(error, "stderr", None)
        if isinstance(stderr, bytes):
            stderr = stderr.decode(errors="replace")
        if stderr and stderr.strip():
            detail += ": " + stderr.strip()
        print(f"capture: {detail}", file=sys.stderr)
        if sys.argv[1:] == ["record", "status"]:
            # A background poll can race systemd reload/activation. Unknown is
            # not idle or a failed recording, and must never raise a toast.
            print(json.dumps({"state": "unavailable", "elapsed": 0}))
        else:
            notify("Capture failed", detail, failure=True)
        return 1


if __name__ == "__main__":
    sys.exit(entrypoint())
