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
| `dev-nix` | Headless-oriented development server with Docker and SSH |
| `mac` | nix-darwin, Homebrew, and the shared Home Manager setup |

All Linux hosts share the baseline system setup: NetworkManager, Docker, Tailscale, Zsh, Australian locale settings, and the Catppuccin Frappé theme.
The desktop and Framework hosts additionally enable the graphical workstation stack; `dev-nix` does not.

Home Manager configures `leonl` on Linux and `leonlee` on macOS.
Shared defaults provide CLI and development tools, while universal applications and selected general-use applications are layered separately.
The Framework host also gets the Niri, Dank Material Shell, and Claude Desktop configuration.

## Repository layout

- `flake.nix` - inputs, stable and unstable package sources, and host definitions.
- `flake.lock` - pins all inputs to exact versions.
- `hosts/<name>/` - machine identity, hardware configuration, and host-specific settings.
- `modules/nixos/` - shared NixOS baseline settings and graphical workstation settings.
- `modules/darwin/` - shared nix-darwin settings.
- `modules/home/default.nix` - shared Home Manager settings and user packages.
- `modules/home/platforms/` - Linux and macOS Home Manager settings.
- `modules/home/programs/` - configuration for individual programs.
- `modules/home/profiles/` - optional Home Manager groups for universal apps, general-use apps, Linux workstation apps, and Niri.

The stable package source is the NixOS `26.05` branch. `nixpkgs-unstable` is also available for packages that need a newer version.

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

For a new computer, create a new directory under `hosts/`, use that computer's generated `hardware-configuration.nix`, and add the host to `nixosConfigurations` in `flake.nix` before rebuilding.

## Add packages

Use the [package scopes](#package-scopes) below to decide where a Home Manager package belongs.
Universal command-line packages remain in `modules/home/default.nix`.

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

### Package scopes

Add a package according to where it should be available:

| Scope | File | Example |
| --- | --- | --- |
| Universal CLI tools | `modules/home/default.nix` | `gh`, `lsof` |
| Universal graphical apps | `modules/home/profiles/universal-apps.nix` | Bitwarden, Chrome |
| Daily apps for graphical hosts | `modules/home/profiles/general-use.nix` | VS Code, ChatGPT, Vesktop |
| Linux workstation apps | `modules/home/profiles/linux-workstation.nix` | Kate |
| OS-specific settings | `modules/home/platforms/linux.nix` or `macos.nix` | User and home-directory differences |
| One device only | `hosts/<device>/home.nix` | Claude Desktop on Framework |
| Device-specific configuration | The same host file, or a module imported from it | App settings and services |

The host modules are imported automatically by `flake.nix`. `desktop`, `framework`, and `mac` import `general-use.nix`; `dev-nix` intentionally does not, so it avoids those graphical applications.

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

## Update dependencies

```sh
cd ~/nix-config
nix flake update
rebuild-test
```

Commit the updated `flake.lock`, along with any changes made to `flake.nix`.
