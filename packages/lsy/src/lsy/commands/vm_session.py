"""Private runtime helpers and the tmux-owned VM supervisor."""

import contextlib
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import stat
import subprocess
import sys
import time


SESSION = "vm"


def private_directory(path: Path) -> Path:
    if not path.is_absolute() or path.resolve() != path:
        raise RuntimeError(f"unsafe VM runtime directory path: {path}")
    try:
        path.mkdir(mode=0o700)
    except FileExistsError:
        pass
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise RuntimeError(f"unsafe VM runtime directory: {path} (requires owned directory, mode 0700)")
    return path


def runtime_directory(name: str = "lsy-vm") -> Path:
    base = os.environ.get("XDG_RUNTIME_DIR")
    if base:
        parent = Path(base)
        if not parent.is_absolute():
            raise RuntimeError("XDG_RUNTIME_DIR must be absolute")
        private_directory(parent)
        return private_directory(parent / name)
    return private_directory(Path(f"/tmp/{name}-{os.getuid()}"))


@contextlib.contextmanager
def locked(directory: Path, name: str = "lock", blocking: bool = False,
           busy: str = "another vm run/stop is in progress; try again later"):
    fd = os.open(directory / name, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1:
            raise RuntimeError("unsafe VM lock file")
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        except BlockingIOError:
            raise RuntimeError(busy) from None
        yield
    finally:
        os.close(fd)


def tmux(directory: Path, *arguments: str, **kwargs):
    endpoint = directory / "tmux.sock"
    if endpoint.exists() or endpoint.is_symlink():
        info = endpoint.lstat()
        if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
            raise RuntimeError("unsafe VM tmux socket")
    env = os.environ.copy()
    env.pop("TMUX", None)
    return subprocess.run(
        ["tmux", "-S", str(directory / "tmux.sock"), "-f", "/dev/null", *arguments],
        env=env, check=False, **kwargs,
    )


def has_session(directory: Path) -> bool:
    return tmux(directory, "has-session", "-t", SESSION, stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL).returncode == 0


def identity(pid: int):
    try:
        # comm may contain spaces or parentheses. Field 22 is process start time.
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        return None if fields[0] == "Z" else fields[19]
    except (FileNotFoundError, ProcessLookupError):
        return None


def live_processes(directory: Path):
    path = directory / "processes.json"
    if path.is_symlink():
        raise RuntimeError("unsafe VM process state")
    try:
        entries = json.loads(path.read_text())
    except FileNotFoundError:
        # The supervisor may have just completed cleanup.
        return []
    return [int(pid) for pid, started in entries if started is not None and identity(int(pid)) == started]


def cleanup(directory: Path):
    # Never remove the stable directory, lock, or arbitrary paths from state files.
    work = directory / "work"
    if work.exists() or work.is_symlink():
        private_directory(work)
        shutil.rmtree(work)
    (directory / "processes.json").unlink(missing_ok=True)
    (directory / "processes.tmp").unlink(missing_ok=True)


def qmp(directory: Path, command: str):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(2)
        connection.connect(str(directory / "work/control.sock"))
        with connection.makefile("rwb") as stream:
            def receive():
                line = stream.readline(1024 * 1024)
                if not line:
                    raise RuntimeError("QMP connection closed")
                return json.loads(line)

            if "QMP" not in receive():
                raise RuntimeError("invalid QMP greeting")
            for request in ("qmp_capabilities", command):
                stream.write((json.dumps({"execute": request}) + "\n").encode())
                stream.flush()
                deadline = time.monotonic() + 2
                while time.monotonic() < deadline:
                    reply = receive()
                    if "error" in reply:
                        raise RuntimeError(f"QMP rejected {request}")
                    if "return" in reply:
                        break
                else:
                    raise RuntimeError("QMP response timed out")


def supervise(directory: Path) -> int:
    private_directory(directory)
    work = private_directory(directory / "work")
    child = None
    stopping = False
    previous = {}

    def terminate(signum, frame):
        nonlocal stopping
        stopping = True
        if child is not None and child.poll() is None:
            try:
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    def save():
        entries = [(os.getpid(), identity(os.getpid()))]
        if child is not None:
            entries.append((child.pid, identity(child.pid)))
        temporary = directory / "processes.tmp"
        with temporary.open("w") as stream:
            json.dump(entries, stream)
        temporary.replace(directory / "processes.json")

    # Publish identity before installing handlers: once HUP can trigger cleanup,
    # a new CLI must be able to see us even if tmux has already disappeared.
    save()
    try:
        for sig in (signal.SIGHUP, signal.SIGTERM, signal.SIGINT):
            previous[sig] = signal.signal(sig, terminate)
        if stopping:
            return 1
        child = subprocess.Popen([str(work / "runner/bin/microvm-run")], cwd=work,
                                 start_new_session=True)
        save()
        while not stopping:
            try:
                return child.wait(timeout=0.2)
            except subprocess.TimeoutExpired:
                pass
        return 128 + signal.SIGTERM
    finally:
        try:
            if child is not None and child.poll() is None:
                try:
                    os.killpg(child.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    try:
                        os.killpg(child.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    child.wait()
            cleanup(directory)
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)


if __name__ == "__main__":
    try:
        sys.exit(supervise(Path(sys.argv[1])))
    except (OSError, RuntimeError) as error:
        print(f"lsy: VM supervisor: {error}", file=sys.stderr)
        sys.exit(1)
