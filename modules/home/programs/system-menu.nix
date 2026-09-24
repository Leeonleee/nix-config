{ config, lib, pkgs, ... }:

let
  inherit (config.lib.formats.rasi) mkLiteral;
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

  renderMenu = name: node: ''
    ${name}() {
      local choice
      while true; do
        if ! choice=$(printf '%s\n' ${lib.escapeShellArgs ((map (entry: entry.label) node.children) ++ [ "Back / close" ])} | rofi -dmenu -i -no-custom -format i -p ${lib.escapeShellArg node.label}); then
          return 0
        fi
        case "$choice" in
          ${lib.concatStringsSep "\n" (lib.imap0 (index: entry: ''
            ${toString index})
              ${if entry ? children then "${name}_${toString index}" else ''
                if ${entry.action}; then
                  exit 0
                else
                  notify-send --urgency=critical 'System menu' ${lib.escapeShellArg "Failed: ${entry.label}"}
                fi
              ''}
              ;;
          '') node.children)}
          *) return 0 ;;
        esac
      done
    }
    ${lib.concatStringsSep "\n" (lib.imap0 (index: entry:
      lib.optionalString (entry ? children) (renderMenu "${name}_${toString index}" entry)
    ) node.children)}
  '';

  systemMenu = pkgs.writeShellApplication {
    name = "system-menu";
    runtimeInputs = [ config.programs.rofi.finalPackage pkgs.libnotify ];
    text = ''
      ${renderMenu "menu_root" menu}
      menu_root
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
      kb-cancel = "Escape,Control+g,Control+bracketleft,Control+h";
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
        fixed-height = false;
        scrollbar = false;
      };
      element = {
        padding = mkLiteral "10px";
        border-radius = mkLiteral "6px";
      };
    };
  };

  # Inherit the existing Catppuccin palette and fonts rather than duplicating them.
  stylix.targets.rofi.enable = true;

  programs.niri.settings.binds."Mod+Shift+Space" = {
    hotkey-overlay.title = "Open system menu";
    action.spawn = lib.getExe systemMenu;
  };
}
