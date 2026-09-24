# lsy

Extensible lsylabs CLI, installed on every configured host through Home Manager.

```sh
lsy try ripgrep
lsy try jq fd
lsy try --help
```

`try` opens a temporary shell using `nix shell`. Type `exit` to leave.
Packages resolve through the `nixpkgs` registry entry, not this config's lockfile.
Downloads stay in the Nix store until garbage collection; no host configuration
or profile is changed. Nix must be available on PATH.

Add future commands under `src/lsy/commands/` and register them in `cli.py`.

Run tests without installing:

```sh
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=packages/lsy/src \
  python3 -m unittest discover -s packages/lsy/tests -v
```
