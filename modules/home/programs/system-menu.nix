{ config, lib, pkgs, ... }:

let
  inherit (config.lib.formats.rasi) mkLiteral;
  capture = args: lib.escapeShellArgs ([ (lib.getExe config.programs.capture.package) ] ++ args);
  dms = args: lib.escapeShellArgs ([ (lib.getExe config.programs.dank-material-shell.package) "ipc" "call" ] ++ args);
  terminal = command: lib.escapeShellArgs [
    (lib.getExe config.programs.kitty.package)
    "--hold"
    (pkgs.writeShellScript "system-menu-terminal" command)
  ];
  checkout = lib.escapeShellArg "${config.home.homeDirectory}/nix-config";
  rebuild = mode: terminal ''
    cd ${checkout} && sudo ${lib.getExe pkgs.nixos-rebuild} ${mode} \
      --flake ".#$(${pkgs.nettools}/bin/hostname)" \
      --option experimental-features 'nix-command flakes'
  '';

  # Each entry has either an action or children. Add children at any depth;
  # navigation/dispatch is generated below without eval or label matching.
  menu = {
    label = "System";
    children = [
      {
        label = "NixOS";
        children = [
          {
            label = "Check configuration";
            action = terminal "cd ${checkout} && ${lib.getExe pkgs.nix} --extra-experimental-features 'nix-command flakes' flake check --no-build";
          }
          { label = "Build configuration"; action = rebuild "build"; }
          { label = "Test configuration (temporary)"; action = rebuild "test"; }
          { label = "Switch configuration"; action = rebuild "switch"; }
        ];
      }
      {
        label = "Capture";
        children = [
          {
            label = "Screenshot";
            children = [
              { label = "Region"; action = capture [ "screenshot" "region" ]; }
              { label = "Window"; action = capture [ "screenshot" "window" ]; }
              { label = "Screen"; action = capture [ "screenshot" "screen" ]; }
            ];
          }
          { label = "Screen recording (toggle)"; action = capture [ "record" "toggle" ]; }
          { label = "OCR region"; action = capture [ "ocr" ]; }
          { label = "Colour picker"; action = capture [ "colour" ]; }
          { label = "QR code"; action = capture [ "qr" ]; }
        ];
      }
      {
        label = "DMS settings";
        children = [
          { label = "All settings"; action = dms [ "settings" "open" ]; }
          { label = "Control center"; action = dms [ "control-center" "open" ]; }
          { label = "Bar appearance"; action = dms [ "settings" "openWith" "dankbar_appearance" ]; }
        ];
      }
      {
        label = "Appearance / wallpaper";
        children = [
          { label = "Browse wallpapers"; action = dms [ "dash" "open" "wallpaper" ]; }
          { label = "Wallpaper settings"; action = dms [ "settings" "openWith" "personalization" ]; }
          { label = "Theme and colors"; action = dms [ "settings" "openWith" "theme" ]; }
          { label = "Interface appearance"; action = dms [ "settings" "openWith" "theme_surfaces" ]; }
        ];
      }
      {
        label = "Network / Bluetooth";
        children = [
          { label = "Network"; action = dms [ "control-center" "openWith" "network" ]; }
          { label = "Bluetooth"; action = dms [ "control-center" "openWith" "bluetooth" ]; }
          { label = "Network settings"; action = dms [ "settings" "openWith" "network" ]; }
        ];
      }
      {
        label = "Power";
        children = [
          { label = "Lock screen"; action = dms [ "lock" "lock" ]; }
          # DMS owns power actions, confirmation, and lock-before-suspend.
          { label = "Suspend / restart / shut down / log out"; action = dms [ "powermenu" "open" ]; }
        ];
      }
    ];
  };

  # Stable IDs are passed as row metadata, independently of labels/filtering.
  # ROFI_DATA records the current page; stripping its last index goes back.
  renderMenu = id: node: ''
    ${id})
      ${if node ? children then ''
        printf '\0data\x1f%s\n' ${lib.escapeShellArg id}
        printf '\0no-custom\x1ftrue\n\0use-hot-keys\x1ftrue\n'
        printf '\0keep-filter\x1ffalse\n'
        ${lib.concatStringsSep "\n" (lib.imap0 (index: entry: ''
          printf '%s\0info\x1f%s\n' ${lib.escapeShellArgs [ entry.label "${id}_${toString index}" ]}
        '') node.children)}
        printf '%s\0info\x1fback\x1fpermanent\x1ftrue\n' ${lib.escapeShellArg (if id == "root" then "Close" else "Back")}
      '' else ''
        # Do not hold Rofi's output pipe open while an action is running.
        (
          if ! ${node.action}; then
            notify-send --urgency=critical 'System menu' ${lib.escapeShellArg "Failed: ${node.label}"}
          fi
        ) </dev/null >/dev/null 2>&1 &
      ''}
      ;;
    ${lib.optionalString (node ? children) (lib.concatStringsSep "\n" (lib.imap0 (index: entry:
      renderMenu "${id}_${toString index}" entry
    ) node.children))}
  '';

  menuBackend = pkgs.writeShellApplication {
    name = "system-menu-backend";
    runtimeInputs = [ pkgs.libnotify ];
    text = ''
      case "''${ROFI_RETV:-0}" in
        0) target=root ;;
        1) target="''${ROFI_INFO:-}" ;;
        10) target=back ;;
        *) exit 0 ;;
      esac
      if [[ "$target" == back ]]; then
        current="''${ROFI_DATA:-root}"
        [[ "$current" == root ]] && exit 0
        target="''${current%_*}"
      fi
      case "$target" in
        ${renderMenu "root" menu}
        *) exit 0 ;;
      esac
    '';
  };

  systemMenu = pkgs.writeShellApplication {
    name = "system-menu";
    runtimeInputs = [ config.programs.rofi.finalPackage ];
    text = ''
      exec rofi -show system -modes ${lib.escapeShellArg "system:${lib.getExe menuBackend}"} \
        -i -kb-custom-1 'Control+h'
    '';
  };
in
{
  home.packages = [ systemMenu ];

  programs.rofi = {
    enable = true;
    # Rofi in the pinned package set supports Wayland natively.
    package = pkgs.rofi;
    extraConfig = {
      kb-row-down = "Down,Control+n,Control+j";
      kb-row-up = "Up,Control+p,Control+k";
      kb-accept-entry = "Return,KP_Enter,Control+m,Control+l";
      kb-cancel = "Escape,Control+g,Control+bracketleft";
      # Free Ctrl+h/k/l from Rofi's default editing/completion actions.
      kb-remove-char-back = "BackSpace,Shift+BackSpace";
      kb-remove-to-eol = "";
      kb-mode-complete = "";
    };
    theme = {
      window = {
        width = mkLiteral "520px";
        border = mkLiteral "2px";
        border-radius = mkLiteral "12px";
      };
      mainbox.padding = mkLiteral "12px";
      inputbar = {
        padding = mkLiteral "8px";
        children = mkLiteral "[ entry ]";
      };
      entry.placeholder = "Search…";
      listview = {
        lines = 8;
        fixed-height = true;
        scrollbar = false;
      };
      element = {
        padding = mkLiteral "10px";
        border-radius = mkLiteral "6px";
      };
    };
  };

  # Inherit the existing palette and fonts rather than duplicating them.
  stylix.targets.rofi.enable = true;

  programs.niri.settings.binds."Mod+Shift+Space" = {
    hotkey-overlay.title = "Open system menu";
    action.spawn = lib.getExe systemMenu;
  };
}
