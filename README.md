# NixOS and nix-darwin configuration

This repository contains the NixOS, nix-darwin, and Home Manager configuration for my computers.
It uses a Nix flake so the system and user setup can be applied with one command.

> The usernames, home directories, hardware settings, and some personal details are specific to `leonl` on Linux and `leonlee` on macOS.
> Change them before using this configuration on another account or computer.

## Hosts

| Host | Main differences |
| --- | --- |
| `desktop` | KDE Plasma with NVIDIA graphics settings |
| `framework` | KDE Plasma and Niri, the latest Linux kernel, fingerprint support, and Btrfs-backed Docker |
| `mac` | nix-darwin, Homebrew, and the shared Home Manager setup |

Both Linux hosts share the main system setup: systemd-boot, NetworkManager, Bluetooth, PipeWire, printing, Docker, Tailscale, Firefox, Zsh, Australian locale settings, and the Catppuccin Frappé theme.

Home Manager configures `leonl` on Linux and `leonlee` on macOS.
It installs desktop applications and manages tools including Git, Zsh, Neovim, Kitty, Starship, eza, fastfetch, pi, and herdr.
The Framework host also gets the Niri and Dank Material Shell configuration.

## Repository layout

- `flake.nix` - inputs, stable and unstable package sources, and host definitions.
- `flake.lock` - pins all inputs to exact versions.
- `hosts/<name>/` - machine identity, hardware configuration, and host-specific settings.
- `modules/nixos/` - shared NixOS settings and the Stylix theme.
- `modules/darwin/` - shared nix-darwin settings.
- `modules/home/default.nix` - shared Home Manager settings and user packages.
- `modules/home/platforms/` - Linux and macOS Home Manager settings.
- `modules/home/programs/` - configuration for individual programs.
- `modules/home/profiles/` - optional groups of Home Manager modules, such as Niri.

The stable package source is the NixOS `26.05` branch. `nixpkgs-unstable` is also available for packages that need a newer version.

## Install or apply NixOS

You need an existing NixOS installation and hardware that matches one of the host configurations.

```sh
git clone https://github.com/leeonleee/nix-config.git ~/nix-config
cd ~/nix-config
sudo nixos-rebuild test --flake .#framework --option experimental-features "nix-command flakes"
sudo nixos-rebuild switch --flake .#framework --option experimental-features "nix-command flakes"
```

Replace `framework` with `desktop` when applying the desktop configuration. `test` activates the configuration until reboot; `switch` makes it the active boot configuration.

After the first successful switch, flakes are enabled and these Zsh aliases are available:

```sh
rebuild-test   # Test the configuration for the current hostname
rebuild        # Apply it permanently
```

For a new computer, create a new directory under `hosts/`, use that computer's generated `hardware-configuration.nix`, and add the host to `nixosConfigurations` in `flake.nix` before rebuilding.

## Add packages

Add normal applications and command-line tools to `home.packages` in `modules/home/default.nix`.
These packages are installed for both Home Manager users.

### Stable package

Add the package name to `home.packages`:

```nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bitwarden-desktop
    firefox
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
    bitwarden-desktop
    pkgsUnstable.example-package
  ];
}
```

`pkgsUnstable` is already created and passed to all NixOS and Home Manager modules by `flake.nix`.

Apply package changes with `rebuild-test`, then `rebuild` when everything works.

## Update dependencies

```sh
cd ~/nix-config
nix flake update
rebuild-test
```

Commit the updated `flake.lock`, along with any changes made to `flake.nix`.
