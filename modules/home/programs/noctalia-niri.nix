{ config, lib, ... }:

let
  noctalia = lib.getExe config.programs.noctalia.package;
  msg = args: "${noctalia} msg ${args}";
  spawn = title: args: {
    hotkey-overlay.title = title;
    action.spawn-sh = msg args;
  };
in
{
  config = lib.mkIf (config.desktop.niri.shell == "noctalia") {
    desktop.noctalia.sessionTargets = [ "niri.service" ];

    # Matches the Noctalia bindings in noctalia-hyprland.nix. Volume,
    # brightness and media keys stay in niri.nix.
    programs.niri.settings = {
      binds = {
        # Noctalia has no keybind viewer; use the searchable Rofi list.
        "Mod+Shift+Slash" = {
          hotkey-overlay.title = "Show all keybindings";
          action.spawn = lib.getExe config.programs.niri-keybinds.package;
        };
        "Super+Alt+L" = spawn "Lock the Screen: Noctalia" "session lock";
        "Mod+P" = spawn "Toggle control center" "panel-toggle control-center";
        "Mod+N" = spawn "Toggle notification history" "panel-toggle control-center notifications";
        "Super+Alt+N" = spawn "Toggle Do Not Disturb" "notification-dnd-toggle";
        "Super+Alt+V" = spawn "Toggle clipboard history" "panel-toggle clipboard";
        "Super+Alt+P" = spawn "Open power menu" "panel-toggle session";
      };

      window-rules = [
        {
          matches = [ { app-id = "^dev\\.noctalia\\.Noctalia$"; } ];
          open-floating = true;
          default-column-width.fixed = 1080;
          default-window-height.fixed = 920;
        }
      ];
    };

    programs.system-menu.sections.niri = lib.mkAfter (import ./noctalia-menu.nix msg);
  };
}
