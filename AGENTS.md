# PROJECT KNOWLEDGE BASE

**Generated:** 2026-08-31

## OVERVIEW

This repository is Leon Lee's personal declarative system configuration for three x86_64 NixOS machines and one Apple Silicon macOS machine.
It uses Nix flakes, NixOS, nix-darwin, Home Manager, and Stylix.
The main package set tracks NixOS 26.05, while a separate unstable package set supplies selected newer tools.

Configured hosts:

| Flake output | Platform | Purpose |
| --- | --- | --- |
| `nixosConfigurations.desktop` | `x86_64-linux` | KDE Plasma desktop with NVIDIA configuration |
| `nixosConfigurations.framework` | `x86_64-linux` | Framework laptop with KDE Plasma, Niri, DMS, fingerprint support, and Btrfs Docker storage |
| `nixosConfigurations.dev-nix` | `x86_64-linux` | Headless development server |
| `darwinConfigurations.mac` | `aarch64-darwin` | macOS with nix-darwin, Homebrew, and shared Home Manager configuration |

## STRUCTURE

```text
.
├── flake.nix                         # Inputs, package sets, host factory, and outputs
├── flake.lock                        # Generated input pins
├── hosts/
│   ├── desktop/                      # Desktop identity, hardware, and host-specific Home Manager config
│   ├── framework/                    # Framework-specific system, Niri, hardware, and Home Manager config
│   ├── dev-nix/                      # Headless server identity, hardware, and Home Manager config
│   └── mac/                          # macOS user, state version, and Home Manager config
└── modules/
    ├── nixos/                        # Shared Linux baseline and workstation system services
    ├── darwin/                       # Shared macOS system and Homebrew settings
    └── home/
        ├── default.nix               # Shared user packages and program imports
        ├── platforms/                # Linux and macOS user differences
        ├── profiles/                 # Optional groups for universal, general-use, Linux workstation, and Niri settings
        └── programs/                 # Per-program Home Manager modules and source configs
```

`flake.nix` is the composition root.
Its `mkHost` helper builds the Linux configurations and passes package sets to Home Manager through `home-manager.extraSpecialArgs`.
The macOS output is composed separately because it uses `aarch64-darwin` and nix-darwin.

All hosts import the shared Home Manager module in `modules/home/default.nix`, one platform module, and `hosts/<name>/home.nix`. Universal applications are imported by the shared module; general-use applications are selected by graphical hosts, Linux workstation applications are selected by the desktop and Framework hosts, and device-specific packages/settings live in each host's Home Manager module. Only `framework` adds `modules/home/profiles/niri.nix`, which imports the Niri and Dank Material Shell modules.

## COMMANDS

Nix fetches flake inputs automatically, so there is no separate dependency installation step.
On a machine where flakes have not yet been enabled system-wide, include the experimental feature option shown below.

| Action | Command |
| --- | --- |
| Validate every configuration without building | `nix --extra-experimental-features "nix-command flakes" flake check --no-build` |
| Inspect outputs | `nix --extra-experimental-features "nix-command flakes" flake show --all-systems` |
| Update and repin all inputs | `nix --extra-experimental-features "nix-command flakes" flake update` |
| Build NixOS | `sudo nixos-rebuild build --flake .#<desktop-framework-or-dev-nix> --option experimental-features "nix-command flakes"` |
| Temporarily activate NixOS | `sudo nixos-rebuild test --flake .#<desktop-framework-or-dev-nix> --option experimental-features "nix-command flakes"` |
| Apply NixOS | `sudo nixos-rebuild switch --flake .#<desktop-framework-or-dev-nix> --option experimental-features "nix-command flakes"` |
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
- Pass flake inputs or package sets through module arguments instead of importing package sets inside leaf modules. Package sets used by Home Manager modules must be passed through `home-manager.extraSpecialArgs`; NixOS `specialArgs` do not propagate into Home Manager.
- Keep package sets platform-native: use an `aarch64-darwin` import for `pkgsMaster` on macOS rather than reusing the `x86_64-linux` package set.
- Use `pkgs.lib.optionals pkgs.stdenv.isLinux` or platform modules when a package is not portable.
- Keep comments for non-obvious operational constraints, such as portal selection, DMS restart behavior, or application compatibility.
- No Nix formatter, linter, or flake `formatter` output is currently configured.
- Do not hand-edit `flake.lock`.
- Do not casually change `system.stateVersion` or `home.stateVersion`; these are compatibility versions, not release selectors. They are kept in each host's system and Home Manager modules rather than in shared modules.

### Lua and TOML

- Neovim is configured declaratively with Nixvim in `modules/home/programs/neovim/default.nix`; prefer typed Nixvim options and keep raw Lua limited to runtime-only behavior.
- TOML configurations are loaded declaratively with `builtins.fromTOML (builtins.readFile ...)` when they are active.
- `modules/home/programs/starship/starship.toml` is the source of the managed Starship configuration.
- `modules/home/programs/herdr/config.toml` is currently not imported because its `xdg.configFile` declaration is commented out; active Herdr settings live in `modules/home/programs/herdr.nix`.
- Herdr's Home Manager module generates a read-only config in the Nix store. Keep Herdr declarative by setting `programs.herdr.settings.onboarding = false;` and adding desired settings to the Nix `settings` attribute; do not enable the separate `xdg.configFile` source or rely on Herdr writing settings interactively.

## COMMON CHANGE LOCATIONS

- Add universal command-line packages in `modules/home/default.nix`.
- Add universal applications in `modules/home/profiles/universal-apps.nix`.
- Add daily applications shared by the current hosts in `modules/home/profiles/general-use.nix`.
- Keep Linux/macOS user differences in `modules/home/platforms/linux.nix` and `macos.nix`; do not put workstation classification there.
- Add Linux graphical user applications in `modules/home/profiles/linux-workstation.nix`.
- Add shared NixOS baseline services in `modules/nixos/default.nix` and graphical workstation services in `modules/nixos/workstation.nix`.
- Add machine-specific settings in `hosts/<name>/default.nix`.
- Change the global NixOS Stylix scheme or font in `modules/theme.nix`.
- Change shared Niri layout, input, rules, or keybindings in `modules/home/programs/niri.nix`; change Framework-specific outputs and lid handling in `hosts/framework/niri.nix`.
- Change DMS settings in `modules/home/programs/dms.nix`.
- Change shared shell aliases in `modules/home/programs/zsh.nix`.
- Add a host by creating `hosts/<name>/`, supplying its hardware configuration, system state version, and `home.nix` with its Home Manager state version, and adding a flake output in `flake.nix`.
- Add device-specific Home Manager packages in `hosts/<name>/home.nix`; leave the file empty when the host needs only the universal packages.

## NOTES AND GOTCHAS

- Usernames and home directories are intentionally hard-coded as `leonl` on Linux and `leonlee` on macOS.
- The three `hardware-configuration.nix` files are generated by `nixos-generate-config` and contain machine-specific filesystem UUIDs.
- Replace generated hardware files from the target machine rather than treating them as normal shared modules.
- `pkgsUnstable` is imported separately for Linux and Darwin with unfree packages allowed.
- `modules/home/home-manager-unstable.nix` is a compatibility shim for Pi and Herdr modules missing from the Home Manager release branch.
- DMS disables its Stylix target to retain its own theme and restarts its user service when Home Manager replaces `settings.json`.
- Framework-specific Niri output names and lid events live in `hosts/framework/niri.nix`, so output changes should be checked on that machine.
- A successful flake check currently emits a known Stylix warning that the KDE `qt` platform is not supported beyond `qtct`.
- The README is the human-facing setup guide and should stay consistent with host names, package sources, and rebuild commands.
