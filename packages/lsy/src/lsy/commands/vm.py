"""Build and launch an isolated, disposable microvm.nix guest."""

import argparse
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import sys
import shlex
import signal
import time

from . import vm_session as session


# Pass dynamic values via --argstr, never interpolate them into Nix source.
RUNNER_EXPRESSION = """
{ flakePath, guestUser }:
let
  flake = builtins.getFlake flakePath;
  guest = flake.nixosConfigurations.lsy-vm.extendModules {
    modules = [ { lsy.vm.userName = guestUser; } ];
  };
in guest.config.microvm.declaredRunner
"""


def run(args: argparse.Namespace) -> int:
    try:
        username = pwd.getpwuid(os.getuid()).pw_name
    except KeyError:
        print("lsy: cannot determine the current account's username.", file=sys.stderr)
        return 1
    if username in {"root", "nobody", "nixbld"} or not re.fullmatch(r"[a-z_][a-z0-9_-]*\$?", username):
        print("lsy: run as a regular user with a NixOS-compatible username, not sudo/root.", file=sys.stderr)
        return 1
    if not Path("/dev/kvm").exists() or not os.access("/dev/kvm", os.R_OK | os.W_OK):
        print(
            "lsy: /dev/kvm must be readable and writable. Enable hardware virtualization "
            "and grant your user KVM access (the kvm group on NixOS), then log in again.",
            file=sys.stderr,
        )
        return 1
    if shutil.which("nix") is None:
        print("lsy: nix was not found on PATH; install Nix to use this command.", file=sys.stderr)
        return 127

    flake = Path(args.flake).expanduser().resolve()
    if not (flake / "flake.nix").is_file():
        print(f"lsy: no flake.nix in {flake}; use --flake PATH.", file=sys.stderr)
        return 1

    try:
        directory = session.runtime_directory()
        with session.locked(directory):
            if session.has_session(directory) or session.live_processes(directory):
                raise RuntimeError("VM already running; use lsy vm attach or lsy vm stop")
            session.cleanup(directory)
            work = session.private_directory(directory / "work")
            runner = work / "runner"
            result = subprocess.run([
                "nix", "--extra-experimental-features", "nix-command flakes",
                "build", "--impure", "--out-link", str(runner),
                "--expr", RUNNER_EXPRESSION,
                "--argstr", "flakePath", str(flake),
                "--argstr", "guestUser", username,
            ], check=False, cwd=work)
            if result.returncode:
                session.cleanup(directory)
                return result.returncode

            # A dedicated server need not inherit the current wrapper's environment.
            # Pass the interpreter's actual import path explicitly to the supervisor.
            pythonpath = os.pathsep.join(os.path.abspath(p) for p in sys.path)
            command = "exec " + shlex.join([
                "env", f"PYTHONPATH={pythonpath}", os.path.abspath(sys.executable),
                "-m", "lsy.commands.vm_session", str(directory),
            ])
            result = session.tmux(directory, "new-session", "-d", "-s", session.SESSION,
                                  "-c", str(work), command)
            if result.returncode:
                if not session.live_processes(directory):
                    session.cleanup(directory)
                raise RuntimeError("could not start the VM tmux session (is tmux installed?)")
            # Wait for the supervisor to start, not for the guest to become ready.
            deadline = time.monotonic() + 5
            while session.has_session(directory):
                if len(session.live_processes(directory)) >= 2:
                    break
                if time.monotonic() >= deadline:
                    raise RuntimeError("VM supervisor did not start; inspect with vm attach or use vm stop")
                time.sleep(0.05)
            if not session.has_session(directory):
                raise RuntimeError("VM exited during startup; check the runner and KVM configuration")
            print(f"VM session started (user {username}); guest may still be booting.\n"
                  "Detach with Ctrl-b d; guest changes are disposable.", flush=True)
        return 0 if args.detach else attach(args)
    except (OSError, RuntimeError, ValueError) as error:
        return failure(error)


def failure(error) -> int:
    print(f"lsy: {error}", file=sys.stderr)
    return 1


def attach(args: argparse.Namespace) -> int:
    try:
        directory = session.runtime_directory()
        if not session.has_session(directory):
            raise RuntimeError("no VM running; start one with lsy vm run")
        # Apply on every attach, including sessions started before a CLI upgrade.
        return session.tmux(
            directory,
            "set-option", "-t", session.SESSION, "prefix", "C-b", ";",
            "unbind-key", "-T", "prefix", "C-s", ";",
            "bind-key", "-T", "prefix", "C-b", "send-prefix", ";",
            "attach-session", "-t", session.SESSION,
        ).returncode
    except (OSError, RuntimeError) as error:
        return failure(error)


def status(args: argparse.Namespace) -> int:
    try:
        directory = session.runtime_directory()
        if session.has_session(directory):
            print("VM running")
            return 0
        if session.live_processes(directory):
            print("VM processes still running without a console; use lsy vm stop")
            return 0
        print("VM stopped")
        return 1
    except (OSError, RuntimeError, ValueError) as error:
        return failure(error)


def wait_stopped(directory: Path, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while session.has_session(directory) or session.live_processes(directory):
        if time.monotonic() >= deadline:
            return False
        time.sleep(0.1)
    return True


def stop(args: argparse.Namespace) -> int:
    try:
        directory = session.runtime_directory()
        with session.locked(directory):
            if not session.has_session(directory) and not session.live_processes(directory):
                session.cleanup(directory)
                print("VM stopped")
                return 0
            try:
                session.qmp(directory, "system_powerdown")
            except (OSError, RuntimeError, ValueError):
                pass
            if not wait_stopped(directory, 10):
                print("Graceful shutdown timed out; forcing VM shutdown.", file=sys.stderr)
                try:
                    session.qmp(directory, "quit")
                except (OSError, RuntimeError, ValueError):
                    pass
                if not wait_stopped(directory, 3):
                    # HUP from tmux closes the supervisor; its finally block reaps QEMU.
                    session.tmux(directory, "kill-session", "-t", session.SESSION,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    if not wait_stopped(directory, 7):
                        for pid in session.live_processes(directory):
                            try:
                                os.kill(pid, signal.SIGTERM)
                            except ProcessLookupError:
                                pass
                        if not wait_stopped(directory, 7):
                            raise RuntimeError("VM processes have not exited; retaining state for a later vm stop")
            session.cleanup(directory)
            print("VM stopped")
            return 0
    except (OSError, RuntimeError, ValueError) as error:
        return failure(error)


def register(subparsers) -> None:
    parser = subparsers.add_parser("vm", help="Disposable NixOS virtual machines")
    commands = parser.add_subparsers(dest="vm_command", required=True)
    run_parser = commands.add_parser(
        "run",
        help="Boot a fresh terminal-based NixOS microVM",
        description=(
            "Boot a disposable NixOS microVM with user-mode networking and no host "
            "directory shares. Requires Linux and access to /dev/kvm. "
            "The first run builds/downloads the guest; subsequent runs reuse the build."
        ),
    )
    run_parser.add_argument(
        "--flake", default="~/nix-config", metavar="PATH",
        help="Nix config checkout containing lsy-vm (default: ~/nix-config)",
    )
    run_parser.add_argument("--detach", action="store_true", help="Start without attaching to the console")
    run_parser.set_defaults(handler=run)
    for name, handler, help_text in (
        ("attach", attach, "Attach to the running VM console"),
        ("status", status, "Report whether the VM session is running"),
        ("stop", stop, "Shut down the VM and discard its state"),
    ):
        commands.add_parser(name, help=help_text).set_defaults(handler=handler)
