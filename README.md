# NixOS and nix-darwin configuration

This repository contains the NixOS, nix-darwin, and Home Manager configuration for my computers.
It uses a Nix flake so the system and user setup can be applied with one command.

> The usernames, home directories, hardware settings, and some personal details are specific to `leonl` on Linux and `leonlee` on macOS.
> Change them before using this configuration on another account or computer.

## Hosts and roles

The flake keeps `mkHost` as the Linux composition helper. It wires the shared
system and Home Manager modules and passes the native package sets through to
Home Manager; it does not inject Home Manager profiles. Each host's
`home.nix` explicitly selects its Home Manager roles.

| Host | NixOS or Darwin roles | Home Manager roles | Host-specific details |
| --- | --- | --- | --- |
| `desktop` | baseline, workstation, Niri, gaming, secure boot | development, general-use, Linux workstation, Niri | KDE Plasma and Niri, NVIDIA graphics, and the desktop monitor layout |
| `framework` | baseline, workstation, Niri | development, general-use, Linux workstation, Niri | Framework laptop, latest Linux kernel, fingerprint support, Btrfs-backed Docker, lid handling, and monitor outputs |
| `dev-nix` | baseline; headless SSH, Docker, and Tailscale host | development | No graphical workstation or Niri role |
| `mac` | nix-darwin and Homebrew | development, general-use | Apple Silicon macOS with the shared Home Manager base |

The Linux baseline provides NetworkManager, Docker, Tailscale, Zsh,
Australian locale settings, and the Catppuccin Frappé Stylix theme. The
workstation role adds the shared graphical stack for `desktop` and `framework`.
The separate gaming role currently owns Steam for `desktop`; future gaming
additions such as GameMode, Gamescope, or MangoHud belong there as well. Secure
boot is also desktop-specific.

Niri has two layers:

- `modules/nixos/niri.nix` contains shared system integration: the upstream
  Niri and `nirinit` modules, the Niri overlay, portal and application-menu
  setup, and the Dankshell PAM setting.
- `modules/home/profiles/niri.nix` selects the shared Home Manager Niri/DMS
  configuration. `modules/home/programs/niri.nix` contains the shared Niri
  layout, input, rules, utilities, and keybindings.

NVIDIA configuration remains in the desktop host. Framework laptop behavior,
lid handling, and monitor outputs remain in Framework host files. The desktop
and Framework monitor layouts are not shared defaults.

## Repository layout

- `flake.nix` - inputs, native stable/unstable/master package sources, and host composition.
- `flake.lock` - pins all inputs to exact versions; update it only with an intentional flake update.
- `hosts/<name>/` - machine identity, generated hardware configuration, host-specific system settings, and Home Manager role selection.
- `modules/nixos/` - shared baseline, workstation, Niri, gaming, and secure-boot system roles.
- `modules/darwin/` - shared nix-darwin settings.
- `modules/home/default.nix` - the minimal Home Manager base shared by every host.
- `modules/home/platforms/` - Linux and macOS identity/platform differences.
- `modules/home/profiles/` - host-selected Home Manager roles: development, general-use, Linux workstation, and Niri.
- `modules/home/programs/` - configuration for individual programs used by the base or profiles.

The stable package source is the NixOS `26.05` branch. `nixpkgs-unstable`
and `nixpkgs-master` are also available. Linux uses `x86_64-linux` package
sets and macOS uses native `aarch64-darwin` package sets.

## Configuration mental model

- **Host** = a specific machine.
- **Profile** = a Home Manager role/capability that a host selects.
- **Program** = configuration for an individual user application.
- **Platform** = OS-specific Home Manager differences only.
- **NixOS module** = a system-level role/capability.

Home Manager is layered from the smallest shared base to increasingly
specific host roles:

| Layer | Selected by | What belongs there |
| --- | --- | --- |
| Minimal universal base | Every host, through `modules/home/default.nix` | Git, Zsh, Neovim/Nixvim, Starship, Eza, fastfetch, the Stylix theme, and small baseline CLI tools |
| Development | `dev-nix`, `desktop`, `framework`, and `mac` | Toolchains, compilers, build tools, `direnv`, development CLIs, and coding-agent programs |
| General-use | `desktop`, `framework`, and `mac` | Graphical daily applications such as Chrome, Bitwarden, VS Code, Kitty, and Vesktop |
| Linux workstation | `desktop` and `framework` | Linux-only utilities such as Kate, Voxtype, Vicinae, and Trayscale |
| Niri | `desktop` and `framework` | Niri/DMS configuration and session utilities such as Fuzzel, brightnessctl, playerctl, and wl-clipboard |
| Host-specific | A single host | Hardware-dependent settings, layouts, services, and one-device packages |

There is no universal-apps profile. Chrome and Bitwarden are general-use
applications, not part of the universal base. Keep platform modules focused on
OS/user identity differences rather than using them to classify a host.
Niri configuration remains in one shared program module rather than being
split into smaller files.

### NixOS system roles

| Role | Hosts | Examples |
| --- | --- | --- |
| Baseline | All Linux hosts | NetworkManager, Docker, Tailscale, user/Zsh setup, locale, and theme |
| Workstation | `desktop`, `framework` | KDE Plasma/SDDM, Bluetooth, printing, PipeWire, and workstation input support |
| Niri | `desktop`, `framework` | Niri package/module, `nirinit`, portal selection, application menu, and PAM integration |
| Gaming | `desktop` | Steam; future GameMode, Gamescope, or MangoHud additions |
| Secure boot | `desktop` | Lanzaboote and `sbctl` |

Place host hardware and topology in the host instead of a shared role:
NVIDIA drivers/settings belong to `hosts/desktop/default.nix`, the desktop
Niri monitor layout belongs to `hosts/desktop/home.nix`, and Framework
laptop/lid and monitor output settings belong to `hosts/framework/default.nix`
and `hosts/framework/niri.nix`.

## Install or apply NixOS

You need an existing NixOS installation and hardware that matches one of the host configurations.

```sh
git clone https://github.com/leeonleee/nix-config.git ~/nix-config
cd ~/nix-config
sudo nixos-rebuild test --flake .#framework --option experimental-features "nix-command flakes"
sudo nixos-rebuild switch --flake .#framework --option experimental-features "nix-command flakes"
```

Replace `framework` with `desktop` or `dev-nix` when applying another NixOS configuration. `test` activates the configuration until reboot; `switch` makes it the active boot configuration.

After the first successful switch, flakes are enabled and these Zsh aliases are available:

```sh
rebuild-check  # Evaluate the flake without building or activating
rebuild-test   # Test the configuration for the current hostname
rebuild        # Apply it permanently
```

`rebuild-check` also works on macOS. It checks `~/nix-config` from any working directory and does not require sudo.

The current macOS `rebuild-test` alias contains `#$mac` rather than `#mac`.
Use the explicit command below until that alias is corrected:

```sh
sudo darwin-rebuild check --flake ~/nix-config#mac
```

For a new computer, create a new directory under `hosts/`, use that computer's generated `hardware-configuration.nix`, and add the host to `nixosConfigurations` in `flake.nix` before rebuilding.

## Add packages

Use the [package scopes](#package-scopes) below to decide where a Home Manager package belongs. Keep the universal base small: CLI essentials go in `modules/home/default.nix`, while toolchains and graphical applications belong in their selected profiles.

### Stable package

Add a package to the profile or host that owns its scope:

```nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    example-package
  ];
}
```

Search for package names at [search.nixos.org/packages](https://search.nixos.org/packages).

### Unstable package

Add `pkgsUnstable` to the module arguments, then prefix the package with `pkgsUnstable.`:

```nix
{ pkgs, pkgsUnstable, ... }:

{
  home.packages = with pkgs; [
    stable-package
    pkgsUnstable.example-package
  ];
}
```

`pkgsUnstable` and `pkgsMaster` are created as native Linux or Darwin package sets and passed to Home Manager by `flake.nix`.

### Voxtype

On `desktop` and `framework`, Home Manager manages Voxtype's configuration and
user service in `modules/home/programs/voxtype.nix`. Hold **Right Alt** to record;
release it to transcribe into the focused application. This reserves Right Alt
for dictation rather than AltGr. The service starts with the graphical session.

Download the English model once per machine with `voxtype setup --download --model base.en`,
then run `systemctl --user restart voxtype`. Models remain in
`~/.local/share/voxtype/models`. Do not run `voxtype setup systemd` or `voxtype configure`; edit the Nix module and rebuild instead.
Check failures with `journalctl --user -u voxtype -b`.

On Framework, the DMS bar includes a Voxtype status widget showing Ready,
Recording, Transcribing, or Stopped. Its source is in
`modules/home/programs/dms-voxtype.nix`; Nix generates its JSON manifest and QML
component in the store, and Home Manager installs and enables it.
After widget-only changes, restart DMS with `systemctl --user restart dms`.

### Package scopes

Add a package according to where it should be available:

| Scope | File | Examples |
| --- | --- | --- |
| Minimal universal CLI base | `modules/home/default.nix` | Git, `gh`, `lsof`, `jq`, `ripgrep`, `fd`, Linux `usbutils` |
| Toolchains and development programs | `modules/home/profiles/development.nix` and its program imports | Go/Rust/Node/Python/JVM/C toolchains, `direnv`, Pi, Claude Code, Herdr |
| Graphical general-use apps | `modules/home/profiles/general-use.nix` | Chrome, Bitwarden, VS Code, Kitty, Vesktop |
| Linux utility workstation | `modules/home/profiles/linux-workstation.nix` | Kate, Voxtype, Vicinae, Trayscale |
| Niri profile/program | `modules/home/profiles/niri.nix` and `modules/home/programs/niri.nix` | DMS, Fuzzel, brightnessctl, playerctl, wl-clipboard |
| NixOS gaming | `modules/nixos/gaming.nix` | Steam; future GameMode, Gamescope, or MangoHud additions |
| Host-only hardware/layout | `hosts/<device>/` | NVIDIA settings, desktop DP-4 layout, Framework lid and monitor outputs |
| OS-specific user settings | `modules/home/platforms/linux.nix` or `macos.nix` | User and home-directory differences |
| One device only | `hosts/<device>/home.nix` | Claude Desktop on Framework |

Use the appropriate package source:

```nix
pkgs.package
pkgsUnstable.package
pkgsMaster.package
inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.package
```

For a device-specific package, add it to the relevant host file:

```nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    example-package
  ];
}
```

### Check package availability on a system

To check whether any package exists in the `nixpkgs-master` package set for a specific system, run this from the repository root. Replace the two `--argstr` values as needed:

```sh
nix eval --impure --json \
  --argstr package herdr \
  --argstr system aarch64-darwin \
  --expr '
    let
      flake = builtins.getFlake (toString ./.);
      pkgs = import flake.inputs.nixpkgs-master {
        inherit system;
        config.allowUnfree = true;
      };
    in builtins.hasAttr package pkgs
  '
```

The result is `true` or `false`. This checks that the package attribute exists; test whether it actually builds with `nix build --impure --no-link` using the same package set.

Apply package changes with `rebuild-test`, then `rebuild` when everything works.

## Validate changes

From the repository root, evaluate the flake and all three NixOS configurations,
then explicitly evaluate macOS (not fully checked by `flake check`):

```sh
nix --extra-experimental-features "nix-command flakes" flake check --no-build
nix --extra-experimental-features "nix-command flakes" eval --raw .#darwinConfigurations.mac.system.drvPath
```

These commands do not build or activate the systems. Test Linux changes on the
matching host with `nixos-rebuild test` before switching; build/check macOS with
`darwin-rebuild` on the Mac. New module files must be added to Git for a Git flake
to include them.

## Update dependencies

```sh
cd ~/nix-config
nix flake update
rebuild-test
```

Commit the updated `flake.lock`, along with any changes made to `flake.nix`.
