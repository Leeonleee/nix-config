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
| `desktop` | baseline, workstation, Niri, Hyprland, gaming, secure boot | development, general-use, Linux workstation, Niri, Hyprland | KDE Plasma, Niri, Hyprland trial, NVIDIA graphics, and the desktop monitor layout |
| `framework` | baseline, workstation, Niri, Hyprland | development, general-use, Linux workstation, Niri, Hyprland | Framework laptop, latest Linux kernel, fingerprint support, Btrfs-backed Docker, lid handling, and monitor outputs |
| `dev-nix` | baseline; headless SSH, Docker, and Tailscale host | development | No graphical workstation or Niri role |
| `mac` | nix-darwin and Homebrew | development, general-use | Apple Silicon macOS with the shared Home Manager base |

The Linux baseline provides NetworkManager, Docker, Tailscale, Zsh,
Australian locale settings, and the shared Stylix theme from `modules/theme.nix`. The
workstation role adds the shared graphical stack for `desktop` and `framework`.
The separate gaming role currently owns Steam for `desktop`; future gaming
additions such as GameMode, Gamescope, or MangoHud belong there as well. Secure
boot is also desktop-specific.

DMS follows Stylix through its built-in target while retaining its configured
wallpaper. Herdr uses custom color tokens generated from the Stylix palette.
Changing `modules/theme.nix` and rebuilding updates both; runtime theme
auto-switching is disabled in Herdr so it follows the selected palette.

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

### Hyprland trial alongside Niri

`desktop` and `framework` also offer Hyprland with Caelestia. Rebuild with
`sudo nixos-rebuild test --flake .#framework` (use `desktop` on the desktop),
then log out and select **Hyprland** in SDDM's session selector. Do not launch it
inside an existing Niri session. Select **Niri** at the next login to return;
Niri/DMS and KDE Plasma remain installed. Once tested, use
`sudo nixos-rebuild switch --flake .#framework` to keep the configuration.

`modules/nixos/hyprland.nix` only supplies system integration (the session,
portal, and polkit support). The Home Manager profile
`modules/home/profiles/hyprland.nix` imports `programs/hyprland.nix` for desktop
settings and `programs/caelestia.nix` for the shell. Both layers use the stable
Hyprland package; do not install a separate compositor version in Home Manager.
Edit those Nix modules and rebuild rather than editing generated files under
`~/.config/hypr` or installing an upstream dotfiles bundle.

Hyprland uses its native scrolling layout, configured to behave like Niri:
half-width columns by default, the same 1/3, 1/2 and 2/3 presets, no
centering, 16px gaps, vertically stacked workspaces with the same five named
persistent workspaces, and Niri-like animation speeds. The authoritative
bindings are in `modules/home/programs/hyprland.nix`; press **Super+Shift+/**
for a searchable, read-only list generated from them. Niri's keys map to their
nearest Hyprland equivalents, including column moves, consume/expel, preset
widths and centering. **Super+P** opens Caelestia's dashboard;
**Super+Shift+Space** opens its launcher. Niri actions without an equivalent,
including **Super+O** (overview), first/last column and window height presets,
are intentionally unbound. Niri's DMS system menu documented below remains
Niri-only; Hyprland screenshots use Grimblast instead. Monitor overrides live
in each host's `home.nix`: DP-4 remains 3840×2160 at 160 Hz and scale 1.5,
while Framework retains eDP-1 at scale 1.5 and its dock connector positions.
Framework's Hyprland lid handling, which turns eDP-1 off and on like Niri's,
lives in `hosts/framework/hyprland.nix`.

DMS is bound to `niri.service`, while Caelestia belongs to
`hyprland-session.target`; rebuilding outside Niri will not start DMS. Fully
log out between sessions so their services and portal environment are replaced.
Hyprland uses its own screencast portal and the KDE file chooser, without
changing Niri's portal selection.

Caelestia uses the existing unstable package set, with no additional flake input.
Its defaults are retained except for Stylix colours and fonts. Since Stylix has
no Caelestia target, `modules/home/programs/caelestia.nix` maps the palette to its
Material colour roles. Home Manager owns `~/.config/caelestia/shell.json` and
`~/.local/state/caelestia/scheme.json`; change the theme declaratively rather than
using Caelestia's interactive scheme editor.

## Repository layout

- `flake.nix` - inputs, native stable/unstable/master package sources, and host composition.
- `flake.lock` - pins all inputs to exact versions; update it only with an intentional flake update.
- `hosts/<name>/` - machine identity, generated hardware configuration, host-specific system settings, and Home Manager role selection.
- `modules/nixos/` - shared baseline, workstation, Niri, Hyprland, gaming, and secure-boot system roles.
- `modules/darwin/` - shared nix-darwin settings.
- `modules/home/default.nix` - the minimal Home Manager base shared by every host.
- `modules/home/platforms/` - Linux and macOS identity/platform differences.
- `modules/home/profiles/` - host-selected Home Manager roles: development, general-use, Linux workstation, Niri, and Hyprland.
- `modules/home/programs/` - configuration for individual programs used by the base or profiles.
- `packages/lsy/` - Linux-only lsylabs CLI, packaged and installed through Home Manager.
- `hosts/lsy-vm/` - standalone disposable NixOS microVM; not a physical host or a `mkHost` configuration.

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
| Hyprland | `desktop` and `framework` | Trial Hyprland desktop and Caelestia shell |
| Host-specific | A single host | Hardware-dependent settings, layouts, services, and one-device packages |

There is no universal-apps profile. Chrome and Bitwarden are general-use
applications, not part of the universal base. Keep platform modules focused on
OS/user identity differences rather than using them to classify a host.
Shared Niri compositor settings remain in one program module. The Niri profile
also imports `modules/home/programs/system-menu.nix`: `Mod+Shift+Space` opens a
Stylix-themed Rofi system menu; `Mod+Space` still opens Vicinae. The menu uses
Rofi script mode to update pages within one fixed-height window without
relaunching it. `Ctrl+h` or the “Back” entry returns to the parent menu;
`Ctrl+h` at the root or Escape anywhere closes it. Rofi also accepts
`Ctrl+j` / `Ctrl+k` for down/up and `Ctrl+l` or Enter for open/run.
Typing always filters entries; changing pages clears the search. Arrow keys
and Backspace work normally. Fuzzel remains installed and can be launched manually.

The system menu delegates settings, wallpaper, connectivity, and power actions
to DMS IPC. NixOS checks/builds/test/switch run in Kitty with output retained;
rebuilds use `~/nix-config` and the current hostname, like the shell aliases.
Test/switch may request sudo authentication. DMS settings managed by Nix can
be reset on rebuild; make persistent changes in `modules/home/programs/dms.nix`.
To extend the menu, add an entry with `label` and either `action` or nested
`children` to the `menu` tree in `system-menu.nix`.

### Capture (Niri)

`System → Capture` and these shortcuts use the shared `capture` command:

| Shortcut | Action |
| --- | --- |
| `Print` | Native Niri screenshot selection |
| `Ctrl+Print` | Native Niri screen screenshot |
| `Alt+Print` | Native Niri window screenshot |
| `Shift+Print` | Start/stop screen recording |
| `Mod+Print` | Pick a colour → clipboard (`#RRGGBB`) |
| `Mod+Ctrl+Print` | OCR region → clipboard |

QR region extraction is available from the menu. OCR and QR use a separate
region selector; cancellation or extraction failure leaves the clipboard alone.
QR contents are copied, never automatically opened.

**Capture → Share latest capture → Taildrop** sends the newest nonempty PNG in
`~/Pictures/Screenshots` or MP4 in the recording directory (by modification time)
using the existing Taildrop recipient picker and device nicknames. Stop any
active recording first so its file is finalized; cancelling the picker sends nothing.

Starting a recording first opens an audio menu: **No audio**, **System audio**,
**Microphone**, or **System audio + microphone**. Microphone modes then prompt
for an input device; system audio captures the default output selected at start.
Choosing both mixes them into one audio track. Audio choices are per-recording,
not remembered; Escape cancels without starting anything. While a recording is
active, the shortcut/menu stops it immediately without opening another chooser.

Next, the desktop portal prompts for the video target. GPU Screen Recorder
writes H.264 MP4 at 60 FPS.
Files go into `Recordings` under the XDG Videos directory (normally
`~/Videos/Recordings`). Press `Shift+Print` again or click the DMS recording
indicator to stop and finalize the file. The indicator hides when idle;
its elapsed timer begins when the recorder first writes output, so it is
approximate. Clicking a failed indicator dismisses the failed state.

`modules/home/programs/capture.nix` owns the command and on-demand user service;
`dms-recording.nix` owns the indicator. For troubleshooting:

```sh
capture record status
journalctl --user -u capture-record.service
python3 -B -m unittest discover -s modules/home/programs/capture -v
```

### NixOS system roles

| Role | Hosts | Examples |
| --- | --- | --- |
| Baseline | All Linux hosts | NetworkManager, Docker, Tailscale, user/Zsh setup, locale, and theme |
| Workstation | `desktop`, `framework` | KDE Plasma/SDDM, Bluetooth, printing, PipeWire, and workstation input support |
| Niri | `desktop`, `framework` | Niri package/module, `nirinit`, portal selection, application menu, and PAM integration |
| Hyprland | `desktop`, `framework` | Greeter session, Hyprland portal, and polkit support; desktop settings belong to Home Manager |
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

## lsy utilities (Linux)

```sh
lsy try cowsay       # Temporary package shell; exit to leave
lsy vm run           # Fresh NixOS guest; sudo poweroff inside to leave
lsy vm run --flake ~/nix-config
lsy vm run --detach  # Start without attaching to the console
lsy vm attach       # Rejoin; Ctrl-B then D detaches without stopping
lsy vm status
lsy vm stop         # Shut down and discard guest state
```

`lsy vm run` uses `microvm.nix` with QEMU/KVM, user-mode networking, no host
filesystem shares, and disposable RAM-backed guest state. It automatically logs
in with your current account's username, a fresh home, and passwordless sudo;
Git, curl, and Nano are included. No host credentials or files are copied.
It builds the guest,
not the host configuration. The first run downloads/builds the guest image;
subsequent runs reuse it. Access to `/dev/kvm` is required; the Linux baseline
adds `leonl` to the `kvm` group (log in again after rebuilding).

The default checkout is `~/nix-config`. New files must be Git-tracked for flakes
to include them. See [the CLI documentation](packages/lsy/README.md) for details.
`lsy` is not installed on macOS.

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

### Dolphin Taildrop sharing

On `desktop` and `framework`, right-click one or more files in Dolphin and
choose **Send with Taildrop…** (possibly under **Actions**). The picker queries
Tailscale each time and lists online devices eligible to receive Taildrop files.
Folders must be compressed into an archive first. Transfers show a start/completion
notification or an error dialog; the recipient accepts/retrieves files normally.

Set friendly names in `modules/home/profiles/linux-workstation.nix`:

```nix
services.dolphin-taildrop.nicknames = {
  "phone-magicdns-name" = "My phone";
  "ipad-magicdns-name" = "My iPad";
  "laptop-magicdns-name" = "My laptop";
};
```

Use names from `tailscale status` (or Tailscale IPs). Full MagicDNS names without
trailing dots and hostnames also work. Nicknamed devices sort first; other
eligible devices remain available below them. Host-specific nicknames can instead
be declared in `hosts/<name>/home.nix`. After rebuilding, restart Dolphin if the
action is not visible. Tailscale must be connected and Taildrop allowed for the
recipient; this action does not change Tailscale permissions or network policy.

### Declarative web apps

On `desktop` and `framework`, the Linux workstation profile imports
`modules/home/programs/web-apps.nix`. Its module-local `webApps` attrset defines
ChatGPT and YouTube by default. To add an app, add an ID with `name`, `url`, and
`icon` fields to that attrset, for example:

```nix
example = {
  name = "Example";
  url = "https://example.com";
  icon = ./web-apps/icons/example.svg;
};
```

Use local SVG or PNG icons under `modules/home/programs/web-apps/icons/`;
the defaults are `modules/home/programs/web-apps/icons/chatgpt.svg` and
`modules/home/programs/web-apps/icons/youtube.svg`. Include new icons in Git
so the flake can access them, then rebuild and activate. Home Manager generates
`webapp-<id>.desktop` entries that Vicinae discovers after activation.

Apps launch Chrome with `--app`, using the existing Chrome profile and logins.
Each launcher sets `StartupWMClass=webapp-<id>` and passes the matching
`--class=webapp-<id>` to Chrome to help running-icon matching and window grouping.
This removes normal browser controls, but does not guarantee distinct Wayland
app IDs or decorations, especially when reusing an existing Chrome process.
Before adding Niri window rules, check the actual `app-id` with
`niri msg windows` (expected identities: `webapp-chatgpt`, `webapp-youtube`).

### Package scopes

Add a package according to where it should be available:

| Scope | File | Examples |
| --- | --- | --- |
| Minimal universal CLI base | `modules/home/default.nix` | Git, `gh`, `lsof`, `jq`, `ripgrep`, `fd`, Linux `usbutils` |
| Toolchains and development programs | `modules/home/profiles/development.nix` and its program imports | Go/Rust/Node/Python/JVM/C toolchains, `direnv`, Pi, Claude Code, Herdr |
| Graphical general-use apps | `modules/home/profiles/general-use.nix` | Chrome, Bitwarden, VS Code, Kitty, Vesktop |
| Linux utility workstation | `modules/home/profiles/linux-workstation.nix` | Kate, Claude Desktop, Voxtype, Vicinae, Trayscale |
| Niri profile/program | `modules/home/profiles/niri.nix` and `modules/home/programs/niri.nix` | DMS, Fuzzel, brightnessctl, playerctl, wl-clipboard |
| Hyprland profile/program | `modules/home/profiles/hyprland.nix` and its program imports | Hyprland settings, bindings, and Caelestia |
| NixOS gaming | `modules/nixos/gaming.nix` | Steam; future GameMode, Gamescope, or MangoHud additions |
| Host-only hardware/layout | `hosts/<device>/` | NVIDIA settings, desktop DP-4 layout, Framework lid and monitor outputs |
| OS-specific user settings | `modules/home/platforms/linux.nix` or `macos.nix` | User and home-directory differences |
| One device only | `hosts/<device>/home.nix` | Packages needed on only that machine |

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

From the repository root, evaluate the flake and NixOS configurations and run the
capture unit tests, then explicitly evaluate macOS (not fully checked by `flake check`):

```sh
nix --extra-experimental-features "nix-command flakes" flake check
nix --extra-experimental-features "nix-command flakes" eval --raw .#darwinConfigurations.mac.system.drvPath
```

The flake check runs the capture tests for the current platform (Linux or macOS);
use `--no-build` for evaluation only, without running tests. These commands do not
build or activate the systems. Test Linux changes on the matching host with
`nixos-rebuild test` before switching; build/check macOS with
`darwin-rebuild` on the Mac. New module files must be added to Git for a Git flake
to include them.

## Update dependencies

```sh
cd ~/nix-config
nix flake update
rebuild-test
```

Commit the updated `flake.lock`, along with any changes made to `flake.nix`.
