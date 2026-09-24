"""Top-level command dispatch."""

import argparse
import sys

from lsy.commands import try_package


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lsy", description="lsylabs utilities")
    subparsers = parser.add_subparsers(dest="command", required=True)
    try_package.register(subparsers)
    args = parser.parse_args(argv)
    try:
        return args.handler(args)
    except FileNotFoundError:
        print("lsy: nix was not found on PATH; install Nix to use this command.", file=sys.stderr)
        return 127
    except OSError as error:
        print(f"lsy: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
