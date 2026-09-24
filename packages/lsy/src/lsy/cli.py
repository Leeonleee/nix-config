"""Top-level command dispatch."""

import argparse
import sys

from lsy.commands import try_package, vm


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lsy", description="lsylabs utilities")
    subparsers = parser.add_subparsers(dest="command", required=True)
    try_package.register(subparsers)
    vm.register(subparsers)
    args = parser.parse_args(argv)
    if sys.platform != "linux":
        print("lsy: only Linux is supported.", file=sys.stderr)
        return 1
    try:
        return args.handler(args)
    except KeyboardInterrupt:
        return 130
    except FileNotFoundError as error:
        print(f"lsy: executable or file not found: {error.filename or 'nix'}", file=sys.stderr)
        return 127
    except OSError as error:
        print(f"lsy: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
