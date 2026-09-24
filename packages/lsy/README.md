# lsy

Extensible Linux-only lsylabs CLI, installed on Linux hosts through Home Manager.
macOS continues to use Nix as a package manager without installing lsy.

```sh
lsy try ripgrep
lsy try jq fd
lsy try --help
```

`try` opens a temporary shell using `nix shell`. Type `exit` to leave.
Packages resolve through the `nixpkgs` registry entry, not this config's lockfile.
Downloads stay in the Nix store until garbage collection; no host configuration
or profile is changed. Nix must be available on PATH.

## Disposable NixOS guest

```sh
lsy vm run
lsy vm run --flake ~/another-checkout
lsy vm run --detach
lsy vm attach
lsy vm status
lsy vm stop
lsy vm run --help
```

Requires hardware virtualization and read/write access to `/dev/kvm`. The NixOS
baseline adds `leonl` to `kvm`; log out and back in after rebuilding if necessary.
The guest is currently x86_64 Linux, matching this repository's Linux hosts.

This extends `nixosConfigurations.lsy-vm` with your current account's username,
builds its `config.microvm.declaredRunner` from `~/nix-config` (or the local
checkout supplied with `--flake`), and starts QEMU in a private managed tmux
session. Tmux is supplied by the Nix package; it uses a separate server and does
not load your tmux configuration. Git-backed flakes require new files to be tracked
with `git add`. The first build can be substantial; later runs reuse Nix's cache.
It does not activate or rebuild the host system.

The guest has two virtual CPUs, 1536 MiB RAM, user-mode NAT networking, and a
console automatically logged in as your host account's username, with its own
`/home/<username>` and passwordless `sudo`. Git, curl, and Nano are included.
Only the username is used: no host UID, password, credentials, home files, or
Home Manager configuration is copied. Run `lsy` as your regular user, not sudo;
unsupported NixOS usernames are rejected. A directly built guest (without the
CLI override) uses `guest`. Different usernames produce separate cached images.
It has no SSH, forwarded ports, or host
filesystem shares. Networking can still reach services on the host/network;
this is a convenience VM, not a hardened sandbox for hostile software.

There is one managed VM per host user. `run` starts and attaches; `run --detach`
starts without attaching (the Nix build still runs in the foreground). Detach
with **Ctrl-B, then D** and rejoin with `lsy vm attach`. Detaching keeps the VM
and all its changes alive. Starting another VM while one is running is refused.
`lsy vm status` returns exit code 0 when running and 1 when stopped.

Run `sudo poweroff` **inside the guest**, or `lsy vm stop` on the host, to stop it.
Stopping requests a graceful shutdown first and forces termination if the guest
does not respond within the timeout. Its writable filesystem and Nix store
overlay are in RAM: all changes disappear at shutdown. Large builds or downloads
inside the guest may exhaust its RAM. Detaching is not persistent storage and
does not preserve the VM across host reboots; host logout policies may also stop
user processes.

The launcher removes the runner GC root and guest control socket after shutdown.
The private runtime directory and coordination lock may remain for subsequent
runs. The read-only guest image stays cached in the Nix store until garbage
collection.

Add future commands under `src/lsy/commands/` and register them in `cli.py`.

Run tests without installing:

```sh
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=packages/lsy/src \
  python3 -m unittest discover -s packages/lsy/tests -v
```
