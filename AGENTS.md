# PROJECT KNOWLEDGE BASE

**Generated:** 2026-08-31

## OVERVIEW

This repository is Leon Lee's personal declarative system configuration for two x86_64 NixOS machines and one Apple Silicon macOS machine.
It uses Nix flakes, NixOS, nix-darwin, Home Manager, and Stylix.
The main package set tracks NixOS 26.05, while a separate unstable package set supplies selected newer tools.

Configured hosts:

| Flake output | Platform | Purpose |
| --- | --- | --- |
| `nixosConfigurations.desktop` | `x86_64-linux` | KDE Plasma desktop with NVIDIA configuration |
| `nixosConfigurations.framework` | `x86_64-linux` | Framework laptop with KDE Plasma, Niri, DMS, fingerprint support, and Btrfs Docker storage |
| `darwinConfigurations.mac` | `aarch64-darwin` | macOS with nix-darwin, Homebrew, and shared Home Manager configuration |

## STRUCTURE

```text
.
├── flake.nix                         # Inputs, package sets, host factory, and outputs
├── flake.lock                        # Generated input pins
├── hosts/
│   ├── desktop/                      # Desktop identity and generated hardware config
│   ├── framework/                    # Framework-specific system, Niri, and hardware config
│   └── mac/                          # macOS user and state version
└── modules/
    ├── nixos/                        # Shared Linux system services and Stylix theme
    ├── darwin/                       # Shared macOS system and Homebrew settings
    └── home/
        ├── default.nix               # Shared user packages and program imports
        ├── platforms/                # Linux and macOS user differences
        ├── profiles/                 # Optional module groups, currently the Niri profile
        └── programs/                 # Per-program Home Manager modules and source configs
```

`flake.nix` is the composition root.
Its `mkHost` helper builds both Linux configurations and gives modules access to `inputs` and `pkgsUnstable` through `specialArgs`.
The macOS output is composed separately because it uses `aarch64-darwin` and nix-darwin.

All hosts import the shared Home Manager module in `modules/home/default.nix` plus one platform module.
Only `framework` adds `modules/home/profiles/niri.nix`, which imports the Niri and Dank Material Shell modules.

## COMMANDS

Nix fetches flake inputs automatically, so there is no separate dependency installation step.
On a machine where flakes have not yet been enabled system-wide, include the experimental feature option shown below.

| Action | Command |
| --- | --- |
| Validate every configuration without building | `nix --extra-experimental-features "nix-command flakes" flake check --no-build` |
| Inspect outputs | `nix --extra-experimental-features "nix-command flakes" flake show --all-systems` |
| Update and repin all inputs | `nix --extra-experimental-features "nix-command flakes" flake update` |
| Build NixOS | `sudo nixos-rebuild build --flake .#<desktop-or-framework> --option experimental-features "nix-command flakes"` |
| Temporarily activate NixOS | `sudo nixos-rebuild test --flake .#<desktop-or-framework> --option experimental-features "nix-command flakes"` |
| Apply NixOS | `sudo nixos-rebuild switch --flake .#<desktop-or-framework> --option experimental-features "nix-command flakes"` |
| Build macOS | `darwin-rebuild build --flake .#mac` |
| Check macOS activation | `sudo darwin-rebuild check --flake .#mac` |
| Apply macOS | `sudo darwin-rebuild switch --flake .#mac` |

There is no standalone unit-test suite.
`nix flake check --no-build` is the repository-wide evaluation check and should be run after changes.
Use `nixos-rebuild test` on Linux before switching whenever the change can affect a live system.

After activation, Zsh provides `rebuild` and `rebuild-test` aliases that assume the checkout is at `~/nix-config`.
The Linux aliases select the configuration with `hostname`.
The current macOS `rebuild-test` alias contains `#$mac` rather than `#mac`, so use the explicit `darwin-rebuild check --flake .#mac` command until that alias is corrected.

## CODING STANDARDS

### Nix

- Use two-space indentation, semicolon-terminated attributes, and multiline lists for nontrivial values.
- Keep modules focused and compose them through `imports` rather than growing a single large host file.
- Put settings shared by all users in `modules/home/default.nix` and platform differences in `modules/home/platforms/`.
- Put machine-specific system settings under `hosts/<name>/`.
- Pass flake inputs or unstable packages through module arguments instead of importing package sets inside leaf modules.
- Use `pkgs.lib.optionals pkgs.stdenv.isLinux` or platform modules when a package is not portable.
- Keep comments for non-obvious operational constraints, such as portal selection, DMS restart behavior, or application compatibility.
- No Nix formatter, linter, or flake `formatter` output is currently configured.
- Do not hand-edit `flake.lock`.
- Do not casually change `system.stateVersion` or `home.stateVersion`; these are compatibility versions, not release selectors.

### Lua and TOML

- Neovim Lua in `modules/home/programs/neovim/init.lua` uses two-space indentation and plugin setup grouped by concern.
- TOML configurations are loaded declaratively with `builtins.fromTOML (builtins.readFile ...)` when they are active.
- `modules/home/programs/starship/starship.toml` is the source of the managed Starship configuration.
- `modules/home/programs/herdr/config.toml` is currently not imported because its `xdg.configFile` declaration is commented out; active Herdr settings live in `modules/home/programs/herdr/default.nix`.

## COMMON CHANGE LOCATIONS

- Add a package for every user in `modules/home/default.nix`.
- Add Linux-only packages or settings in `modules/home/platforms/linux.nix`.
- Add macOS-only user settings in `modules/home/platforms/macos.nix`.
- Add shared NixOS services in `modules/nixos/default.nix`.
- Add machine-specific settings in `hosts/<name>/default.nix`.
- Change the global NixOS Stylix scheme or font in `modules/nixos/theme.nix`.
- Change Niri layout, outputs, input, rules, or keybindings in `modules/home/programs/niri.nix`.
- Change DMS settings in `modules/home/programs/dms.nix`.
- Change shared shell aliases in `modules/home/programs/zsh.nix`.
- Add a host by creating `hosts/<name>/`, supplying its hardware configuration, and adding a flake output in `flake.nix`.

## NOTES AND GOTCHAS

- Usernames and home directories are intentionally hard-coded as `leonl` on Linux and `leonlee` on macOS.
- The two `hardware-configuration.nix` files are generated by `nixos-generate-config` and contain machine-specific filesystem UUIDs.
- Replace generated hardware files from the target machine rather than treating them as normal shared modules.
- `pkgsUnstable` is imported separately for Linux and Darwin with unfree packages allowed.
- `modules/home/home-manager-unstable.nix` is a compatibility shim for Pi and Herdr modules missing from the Home Manager release branch.
- OpenWhispr is Linux-only and its package path is explicitly `x86_64-linux`.
- DMS disables its Stylix target to retain its own theme and restarts its user service when Home Manager replaces `settings.json`.
- The Framework output names several physical display connectors in the Niri configuration, so output changes should be checked on that machine.
- A successful flake check currently emits a known Stylix warning that the KDE `qt` platform is not supported beyond `qtct`.
- The README is the human-facing setup guide and should stay consistent with host names, package sources, and rebuild commands.
