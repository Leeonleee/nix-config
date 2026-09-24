# PROJECT KNOWLEDGE BASE

**Generated:** 2026-09-15

## OVERVIEW

This repository is Leon Lee's personal declarative system configuration for three x86_64 NixOS machines and one Apple Silicon macOS machine.
It uses Nix flakes, NixOS, nix-darwin, Home Manager, and Stylix.
The main package set tracks NixOS 26.05; separate unstable and master package sets supply selected newer tools.

Configured hosts and roles:

| Flake output | System roles | Home Manager roles | Purpose |
| --- | --- | --- | --- |
| `nixosConfigurations.desktop` | baseline, workstation, Niri, gaming, secure boot | development, general-use, Linux workstation, Niri | KDE Plasma/Niri desktop with NVIDIA graphics |
| `nixosConfigurations.framework` | baseline, workstation, Niri | development, general-use, Linux workstation, Niri | Framework laptop with KDE Plasma/Niri, DMS, fingerprint support, and Btrfs Docker storage |
| `nixosConfigurations.dev-nix` | baseline; headless SSH, Docker, and Tailscale | development | Headless development server |
| `darwinConfigurations.mac` | nix-darwin and Homebrew | development, general-use | Apple Silicon macOS |

The baseline NixOS module supplies NetworkManager, Docker, Tailscale, Zsh,
Australian locale settings, and the Stylix theme. Workstation is shared by
`desktop` and `framework`. Niri system integration is shared by those two
hosts. Gaming currently enables Steam on `desktop`; future GameMode, Gamescope,
or MangoHud additions belong in the gaming role. Secure boot is desktop-only.

Home Manager has a deliberately small universal base: Git, Zsh, Neovim,
Starship, Eza, fastfetch, the theme, and baseline CLI tools. Development is a
host-selected profile rather than a universal default. Graphical applications
are in general-use, Linux utilities are in linux-workstation, and Niri/DMS
settings are in the Niri profile. There is no universal-apps profile; Chrome
and Bitwarden belong to general-use.

## STRUCTURE

```text
.
├── flake.nix                         # Inputs, package sets, host factory, and outputs
├── flake.lock                        # Generated input pins
├── hosts/
│   ├── desktop/                      # Desktop identity, NVIDIA, secure boot, and monitor layout
│   ├── framework/                    # Framework identity, laptop/lid behavior, outputs, and Home Manager config
│   ├── dev-nix/                      # Headless server identity, SSH, and Home Manager config
│   └── mac/                          # macOS user, state version, and Home Manager config
└── modules/
    ├── nixos/                        # Baseline, workstation, Niri, gaming, and secure-boot roles
    ├── darwin/                       # Shared macOS system and Homebrew settings
    └── home/
        ├── default.nix               # Minimal universal Home Manager base
        ├── platforms/                # Linux and macOS identity differences
        ├── profiles/                 # Development, general-use, Linux workstation, and Niri roles
        └── programs/                 # Per-program Home Manager modules and source configs
```

`flake.nix` is the composition root. Its `mkHost` helper builds the Linux
configurations, passes package sets to Home Manager through
`home-manager.extraSpecialArgs`, and keeps common module wiring in one place.
It does not inject Home Manager roles: each host's `home.nix` imports the
profiles it needs. The macOS output is composed separately because it uses
`aarch64-darwin` and nix-darwin.

The package sets are platform-native. Linux receives `pkgsUnstable` and
`pkgsMaster` for `x86_64-linux`; macOS receives matching `aarch64-darwin`
imports. Do not reuse the Linux package sets for macOS.

### Home Manager role map

| Host | Imports |
| --- | --- |
| `dev-nix` | development |
| `desktop` | development, general-use, linux-workstation, niri |
| `framework` | development, general-use, linux-workstation, niri |
| `mac` | development, general-use |

Mental model: **host** = specific machine; **profile** = Home Manager role/capability;
**program** = individual user application configuration; **platform** = OS-specific
Home Manager differences; **NixOS module** = system-level role/capability.

Role boundaries:

- `modules/home/default.nix` is the minimal base for every host. Keep Git,
  Zsh, Neovim/Nixvim, Starship, Eza, fastfetch, Stylix, and small universal
  CLI tools here.
- `modules/home/profiles/development.nix` owns toolchains, compilers/build
  tools, `direnv`, development CLIs, and developer programs such as Pi,
  Claude Code, and Herdr.
- `modules/home/profiles/general-use.nix` owns graphical daily applications
  such as Chrome, Bitwarden, VS Code, Kitty, and Vesktop.
- `modules/home/profiles/linux-workstation.nix` owns Linux-only utilities
  such as Kate, Voxtype, Vicinae, and Trayscale.
- `modules/home/profiles/niri.nix` composes the shared Niri, DMS and Noctalia
  program modules and selects the Niri shell with `desktop.niri.shell`
  (`"dms"` or `"noctalia"`). `modules/home/programs/niri.nix` owns shared
  layout, input, rules, keybindings, and Niri utilities; shell keybindings
  live in the selected shell's module.
- `hosts/<name>/home.nix` owns one-device packages and settings. Desktop and
  Framework monitor layouts stay host-specific.

### NixOS system role map

- `modules/nixos/default.nix`: baseline services shared by all Linux hosts.
- `modules/nixos/workstation.nix`: graphical workstation stack shared by
  `desktop` and `framework`.
- `modules/nixos/niri.nix`: shared Niri system integration. It imports the
  upstream Niri and `nirinit` modules, applies the Niri overlay, enables
  `nirinit`, and contains shared portal, application-menu, and Dankshell PAM
  configuration.
- `modules/nixos/gaming.nix`: desktop gaming role; currently Steam. Future
  GameMode, Gamescope, or MangoHud additions belong here.
- `modules/nixos/secure-boot.nix`: desktop Lanzaboote and `sbctl` support.

Keep NVIDIA drivers/settings in `hosts/desktop/default.nix`. Keep Framework
kernel, fingerprint, lid, and monitor behavior in Framework host files. Keep
the desktop monitor layout in the desktop host Home Manager file.

## COMMANDS

Nix fetches flake inputs automatically, so there is no separate dependency installation step.
On a machine where flakes have not yet been enabled system-wide, include the experimental feature option shown below.

| Action | Command |
| --- | --- |
| Check flake and NixOS configurations without building | `nix --extra-experimental-features "nix-command flakes" flake check --no-build` |
| Evaluate the macOS system and Home Manager configuration | `nix --extra-experimental-features "nix-command flakes" eval --raw .#darwinConfigurations.mac.system.drvPath` |
| Inspect outputs | `nix --extra-experimental-features "nix-command flakes" flake show --all-systems` |
| Update and repin all inputs | `nix --extra-experimental-features "nix-command flakes" flake update` |
| Build NixOS | `sudo nixos-rebuild build --flake .#<desktop-framework-or-dev-nix> --option experimental-features "nix-command flakes"` |
| Temporarily activate NixOS | `sudo nixos-rebuild test --flake .#<desktop-framework-or-dev-nix> --option experimental-features "nix-command flakes"` |
| Apply NixOS | `sudo nixos-rebuild switch --flake .#<desktop-framework-or-dev-nix> --option experimental-features "nix-command flakes"` |
| Build macOS | `darwin-rebuild build --flake .#mac` |
| Check macOS activation | `sudo darwin-rebuild check --flake .#mac` |
| Apply macOS | `sudo darwin-rebuild switch --flake .#mac` |

There is no standalone unit-test suite.
`nix flake check --no-build` is the repository-wide evaluation check and
should be run after source changes. Also evaluate the Darwin system explicitly:
`flake check` does not fully validate `darwinConfigurations`. Use `nixos-rebuild test` on Linux before
switching whenever a change can affect a live system.

After activation, Zsh provides `rebuild` and `rebuild-test` aliases that assume the checkout is at `~/nix-config`.
The Linux aliases select the configuration with `hostname`.
The current macOS `rebuild-test` alias contains `#$mac` rather than `#mac`, so use the explicit `darwin-rebuild check --flake .#mac` command until that alias is corrected.

## CODING STANDARDS

### Commit messages

- Use short, lowercase, plain-language messages describing only what changed, matching the existing history (for example, `added dolphin send with taildrop` or `fixed capture notifications`).
- Do not use Conventional Commit prefixes or scopes such as `feat:`, `fix:`, or `feat(capture):`.
- Apply this style to every commit unless the user explicitly requests otherwise.

### Nix

- Use two-space indentation, semicolon-terminated attributes, and multiline lists for nontrivial values.
- Keep modules focused and compose them through `imports` rather than growing a single large host file.
- Put the universal Home Manager base in `modules/home/default.nix`; select development, general-use, Linux workstation, and Niri roles explicitly from host Home Manager files.
- Put machine-specific system settings under `hosts/<name>/`.
- Pass flake inputs or package sets through module arguments instead of importing package sets inside leaf modules. Package sets used by Home Manager modules must be passed through `home-manager.extraSpecialArgs`; NixOS `specialArgs` do not propagate into Home Manager.
- Keep package sets platform-native: use an `aarch64-darwin` import for `pkgsMaster` on macOS rather than reusing the `x86_64-linux` package set.
- Use `pkgs.lib.optionals pkgs.stdenv.isLinux` or platform modules when a package is not portable.
- Keep comments for non-obvious operational constraints, such as portal selection, DMS restart behavior, or application compatibility.
- No Nix formatter, linter, or flake `formatter` output is currently configured.
- Do not hand-edit `flake.lock`.
- Do not casually change `system.stateVersion` or `home.stateVersion`; these are compatibility versions, not release selectors. They are kept in each host's system and Home Manager modules rather than in shared modules.

### Package placement

- Add baseline CLI packages in `modules/home/default.nix` only when they are
  useful on every host.
- Add toolchains and developer programs to `modules/home/profiles/development.nix`.
- Add Chrome, Bitwarden, and other daily graphical applications to
  `modules/home/profiles/general-use.nix`; do not recreate a universal-apps
  profile.
- Add Linux workstation utilities to `modules/home/profiles/linux-workstation.nix`.
- Add Niri session programs/settings to the Niri profile/program modules;
  split large program files only when it improves navigation.
- Add Steam and future GameMode/Gamescope/MangoHud system integration to
  `modules/nixos/gaming.nix`.
- Keep NVIDIA and monitor layouts in the relevant host files.

### Lua and TOML

- Neovim is configured declaratively with Nixvim in `modules/home/programs/neovim/default.nix`; prefer typed Nixvim options and keep raw Lua limited to runtime-only behavior.
- TOML configurations are loaded declaratively with `builtins.fromTOML (builtins.readFile ...)` when they are active.
- `modules/home/programs/starship/starship.toml` is the source of the managed Starship configuration.
- `modules/home/programs/herdr/config.toml` is currently not imported because its `xdg.configFile` declaration is commented out; active Herdr settings live in `modules/home/programs/herdr.nix`.
- Herdr's Home Manager module generates a read-only config in the Nix store. Keep Herdr declarative by setting `programs.herdr.settings.onboarding = false;` and adding desired settings to the Nix `settings` attribute; do not enable the separate `xdg.configFile` source or rely on Herdr writing settings interactively.

## COMMON CHANGE LOCATIONS

- Add universal command-line packages in `modules/home/default.nix`.
- Add development toolchains or developer programs in `modules/home/profiles/development.nix`.
- Add daily graphical applications, including Chrome and Bitwarden, in `modules/home/profiles/general-use.nix`.
- Keep Linux/macOS user differences in `modules/home/platforms/linux.nix` and `macos.nix`; do not put workstation classification there.
- Add Linux graphical user applications in `modules/home/profiles/linux-workstation.nix`.
- Change shared Niri Home Manager layout, input, rules, or keybindings in `modules/home/programs/niri.nix`; change Framework-specific outputs and lid handling in `hosts/framework/niri.nix`.
- Change shared NixOS Niri integration in `modules/nixos/niri.nix`; retain NVIDIA desktop settings in `hosts/desktop/default.nix`.
- Add or change desktop gaming system packages in `modules/nixos/gaming.nix`.
- Change the global NixOS Stylix scheme or font in `modules/theme.nix`.
- Change DMS settings in `modules/home/programs/dms.nix`.
- Change Noctalia settings in `modules/home/programs/noctalia.nix`; its session
  wiring lives in `noctalia-hyprland.nix` and `noctalia-niri.nix`, and
  `noctalia-service.nix` binds its single user service to every session that
  selects it.
- Switch the Niri shell with `desktop.niri.shell` in
  `modules/home/profiles/niri.nix`, or the Hyprland shell with
  `desktop.hyprland.shell` in `modules/home/profiles/hyprland.nix`.
- Change shared shell aliases in `modules/home/programs/zsh.nix`.
- Add a host by creating `hosts/<name>/`, supplying its hardware configuration, system state version, and `home.nix` with its Home Manager state version, and adding a flake output in `flake.nix`.
- Add device-specific Home Manager packages and settings in `hosts/<name>/home.nix`; leave the file focused on that host's needs.

## NOTES AND GOTCHAS

- Usernames and home directories are intentionally hard-coded as `leonl` on Linux and `leonlee` on macOS.
- The three `hardware-configuration.nix` files are generated by `nixos-generate-config` and contain machine-specific filesystem UUIDs.
- Replace generated hardware files from the target machine rather than treating them as normal shared modules.
- `pkgsUnstable` and `pkgsMaster` are imported separately for Linux and Darwin with unfree packages allowed.
- `modules/home/home-manager-unstable.nix` is a compatibility shim for Pi, Herdr, and Noctalia modules missing from the Home Manager release branch.
- DMS disables its Stylix target to retain its own theme and restarts its user service when Home Manager replaces `settings.json`.
- Shared Niri system integration belongs in `modules/nixos/niri.nix`; Framework-specific Niri output names and lid events live in `hosts/framework/niri.nix`, and the desktop monitor layout remains host-specific.
- Niri's portal setup deliberately uses the KDE file chooser alongside Dolphin because the default GNOME portal delegates to Nautilus, which is not installed.
- A successful flake check currently emits a known Stylix warning that the KDE `qt` platform is not supported beyond `qtct`.
- The README is the human-facing setup guide and should stay consistent with host names, role selection, package sources, and rebuild commands.
