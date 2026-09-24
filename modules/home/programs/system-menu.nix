{ config, lib, pkgs, ... }:

let
  inherit (config.lib.formats.rasi) mkLiteral;
  cfg = config.programs.system-menu;
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
  # Sessions add their own sections through programs.system-menu.sections,
  # keyed by XDG_CURRENT_DESKTOP; the NixOS section is shared.
  nixosSection = {
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
  };
  menuFor = sections: {
    label = "System";
    children = [ nixosSection ] ++ sections;
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
          if ! (
            ${node.action}
          ); then
            notify-send --urgency=critical 'System menu' ${lib.escapeShellArg "Failed: ${node.label}"}
          fi
        ) </dev/null >/dev/null 2>&1 &
      ''}
      ;;
    ${lib.optionalString (node ? children) (lib.concatStringsSep "\n" (lib.imap0 (index: entry:
      renderMenu "${id}_${toString index}" entry
    ) node.children))}
  '';

  menuBackend = session: sections: pkgs.writeShellApplication {
    name = "system-menu-backend-${session}";
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
        ${renderMenu "root" (menuFor sections)}
        *) exit 0 ;;
      esac
    '';
  };

  systemMenu = pkgs.writeShellApplication {
    name = "system-menu";
    runtimeInputs = [ config.programs.rofi.finalPackage ];
    text = ''
      case "''${XDG_CURRENT_DESKTOP:-}" in
        ${lib.concatStrings (lib.mapAttrsToList (session: sections: ''
          ${lib.escapeShellArg session}) backend=${lib.getExe (menuBackend session sections)} ;;
        '') cfg.sections)}
        *) backend=${lib.getExe (menuBackend "default" [ ])} ;;
      esac
      exec rofi -show system -modes "system:$backend" \
        -i -kb-custom-1 'Control+h'
    '';
  };
in
{
  options.programs.system-menu = {
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Rofi system menu command used by compositor keybindings.";
    };
    sections = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
      default = { };
      description = "Menu sections per session, keyed by XDG_CURRENT_DESKTOP.";
    };
  };

  config = {
    programs.system-menu.package = systemMenu;
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

    programs.system-menu.sections.niri = [
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
          {
            label = "Share latest capture";
            children = [
              {
                label = "Taildrop";
                action = ''
                  latest="$(${capture [ "latest" ]})" &&
                    ${lib.getExe config.services.dolphin-taildrop.package} "$latest"
                '';
              }
            ];
          }
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

    programs.niri.settings.binds."Mod+Shift+Space" = {
      hotkey-overlay.title = "Open system menu";
      action.spawn = lib.getExe systemMenu;
    };
  };
}
