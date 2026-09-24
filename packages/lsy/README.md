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

## Persistent Windows 11 VM

```sh
lsy windows vm install [--ram GIB] [--cpus N] [--disk GIB] [--no-start]
lsy windows vm console
lsy windows vm launch [--keep-alive] [--timeout SECONDS]
lsy windows vm status
lsy windows vm stop
lsy windows vm remove
```

Separate from `lsy vm`: Windows 11 runs persistently in
[Dockur](https://github.com/dockur/windows) under Docker Compose and is viewed
with FreeRDP. There is no GPU passthrough. Requires Docker with the Compose plugin
(and membership of the `docker` group), `/dev/kvm`, `/dev/net/tun` and
`xfreerdp` (FreeRDP 3). The Linux workstation Home Manager profile installs
FreeRDP.

| Path | Contents |
| --- | --- |
| `~/.windows` | Windows disk, firmware state and installer files (Dockur `/storage`) |
| `~/Windows` | Shared folder, mapped as `Z:` (`\\host.lan\Data`) in Windows |
| `~/.config/lsy/windows/` | Mode 0700: `settings.json`, generated `compose.yaml`, `credentials.env` (0600), and the `oem/install.bat` setup script |

`install` checks Docker, KVM, TUN, FreeRDP and free space (the disk size plus
10 GiB for downloads). It then asks for the Windows username and password and
writes the configuration. Finally it starts the unattended installation, which
downloads Windows and can take a while; follow it with `console`. Defaults are
8 GiB RAM, 4 CPUs and an 80 GiB disk. Credentials only take effect during
installation. If `~/.windows` already contains a disk, enter that Windows
account's credentials. The OEM script maps `Z:` at the end of setup and installs
a startup script that reconnects it at each logon. `install` adds a
`README.txt` to an empty `~/Windows`, because Dockur makes an empty shared
folder world-writable. Files created from Windows are owned by root, mode 0666.

Compose passes the credentials from a raw `env_file`, so they never appear in the
Compose file. FreeRDP reads its arguments from stdin, so the password never
appears in a process's command line. Anyone with Docker access can still read
it with `docker inspect` while the container exists.
`compose.yaml` is regenerated on every start; change resources in
`settings.json`. Ports 8006 (web console) and 3389 (RDP) are bound to
`127.0.0.1` only. The Compose service has `restart: "no"`, and `stop` runs
`docker compose down`, so the container is disposable and persistence
comes only from `~/.windows`.

`launch` starts the VM if necessary and waits for Windows to complete a real RDP
handshake twice. Docker's port proxy accepts TCP connections before Windows
listens, so a plain port check is not enough. It then opens fullscreen FreeRDP
with dynamic resolution, clipboard, sound and microphone. Closing FreeRDP shuts
the VM down unless `--keep-alive` is given. If Windows itself drops the
connection (FreeRDP exit code 1, for example while applying display settings),
`launch` reconnects instead. It gives up after more than three drops, counting
only sessions shorter than a minute. Display scaling follows the focused
Hyprland or Niri output: `/scale-desktop` gets its exact percentage, and Store
apps' `/scale` gets the nearest of 100, 140 or 180. Pin a percentage (100–500)
with `{"scale": 175}` in `~/.config/lsy/windows.json`. Home Manager writes that
file from `programs.windows-vm.scale`, and `remove` keeps it. Windows applies
the scale at sign-in or
reconnect, so change it here rather than in Windows Settings. If RDP is not
ready within
`--timeout` (default 300 s), the VM is left running because Windows may still be
installing. Only one FreeRDP session is allowed at a time. When not attached to a
terminal, for example when started from the desktop entry, progress and errors
are shown as notifications.

`status` reports `not installed`, `stopped`, `starting` (container up, RDP not
ready) or `running`, with resources and paths. It exits 0 while the container
runs and 1 otherwise. `stop` requests an ACPI shutdown and allows 120 seconds
before Docker forces it; stopping an already stopped VM succeeds. `console`
starts the VM if needed and opens `http://127.0.0.1:8006/`.

`remove` lists exactly what it deletes and preserves, then requires typing
`DELETE WINDOWS`. It shuts the VM down, removes the container, `~/.windows` and
`~/.config/lsy/windows`, and always preserves `~/Windows` and the Docker image.
It refuses when either path is a symlink, is not a directory you own, resolves
through a symlinked parent, or contains the shared folder. It also refuses while
a FreeRDP session is open, or if the container cannot be stopped. Root-owned
directories left by Dockur are emptied through a network-less container
created from the cached image.

Add future commands under `src/lsy/commands/` and register them in `cli.py`.

Run tests without installing:

```sh
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=packages/lsy/src \
  python3 -m unittest discover -s packages/lsy/tests -v
```
