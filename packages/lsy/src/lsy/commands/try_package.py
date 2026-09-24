"""Open a temporary shell with packages from the nixpkgs registry entry."""

import argparse
import os


def run(args: argparse.Namespace) -> int:
    command = [
        "nix",
        "--extra-experimental-features",
        "nix-command flakes",
        "shell",
        "--",
        *(f"nixpkgs#{package}" for package in args.packages),
    ]
    # Replace lsy so the interactive shell receives signals and owns its exit code.
    os.execvp(command[0], command)
    return 0


def register(subparsers) -> None:
    parser = subparsers.add_parser(
        "try",
        help="Try nixpkgs packages in a temporary shell",
        description=(
            "Open a temporary shell with packages from your nixpkgs registry entry. "
            "Type exit to leave; downloaded packages remain cached until garbage collection."
        ),
    )
    parser.add_argument("packages", nargs="+", metavar="PACKAGE")
    parser.set_defaults(handler=run)
