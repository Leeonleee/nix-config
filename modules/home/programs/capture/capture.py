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


def record(action):
    if action == "status":
        print(json.dumps(status()))
        return
    # Serialize the whole decision plus the systemd transaction. Type=exec
    # ensures a successful start is visible before another toggle takes the lock.
    with (runtime() / "control.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        current = status()["state"]
        if current in ("starting", "recording", "stopping"):
            run("systemctl", "--user", "--no-block", "stop", UNIT)
        elif action == "stop" and current == "failed":
            # Let the indicator dismiss a failed attempt without starting another.
            run("systemctl", "--user", "reset-failed", UNIT)
        elif action == "toggle":
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
            run("systemctl", "--user", "start", UNIT)


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
        child = subprocess.Popen([TOOLS["recorder"], "-w", "portal", "-f", "60", "-k", "h264", "-o", str(output)])
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
        if child.returncode == 0 and output.stat().st_size > 0:
            notify("Recording saved", str(output))
            return 0
        if stopping and data["since"] is None:
            notify("Recording cancelled")
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


def clipboard(text):
    if not text.strip():
        raise ValueError("No text found; clipboard unchanged")
    run("clipboard", "--type", "text/plain;charset=utf-8", input=text.encode())


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
        clipboard(text)
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


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"capture: {error}", file=sys.stderr)
        notify("Capture failed", str(error), failure=True)
        sys.exit(1)
