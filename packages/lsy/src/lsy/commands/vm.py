"""Build and launch an isolated, disposable microvm.nix guest."""

import argparse
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import sys
import tempfile


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

    # A temporary out-link keeps the runner GC-rooted while the VM is running.
    # QEMU's control socket and any runtime files stay in this private directory.
    with tempfile.TemporaryDirectory(prefix="lsy-vm-") as directory:
        runner = Path(directory) / "runner"
        result = subprocess.run([
            "nix", "--extra-experimental-features", "nix-command flakes",
            "build", "--impure", "--out-link", str(runner),
            "--expr", RUNNER_EXPRESSION,
            "--argstr", "flakePath", str(flake),
            "--argstr", "guestUser", username,
        ], check=False)
        if result.returncode:
            return result.returncode

        print(
            f"Starting fresh NixOS guest (user {username}, 1536 MiB RAM).\n"
            "Run sudo poweroff inside the guest to exit. All guest changes will be discarded.",
            flush=True,
        )
        with subprocess.Popen([str(runner / "bin/microvm-run")], cwd=directory) as process:
            try:
                return process.wait()
            except KeyboardInterrupt:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                return 130


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
    run_parser.set_defaults(handler=run)
