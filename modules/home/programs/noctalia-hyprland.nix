{ config, lib, ... }:

let
  noctalia = lib.getExe config.programs.noctalia.package;
  msg = args: "${noctalia} msg ${args}";
  selected = config.desktop.hyprland.shell == "noctalia";
  # Same shape as the bindings in hyprland.nix.
  exec = mods: key: description: argument: {
    kind = "bindd";
    dispatcher = "exec";
    inherit mods key description argument;
  };
in
{
  config = lib.mkIf selected {
    programs.noctalia.systemd.enable = true;

    # The upstream unit follows graphical-session.target, which Niri also
    # reaches. Bind it to Hyprland's session only, like Caelestia.
    systemd.user.services.noctalia = {
      Unit = {
        PartOf = lib.mkForce [ "hyprland-session.target" ];
        After = lib.mkForce [ "hyprland-session.target" ];
        Requisite = [ "hyprland-session.target" ];
      };
      Service.Slice = "session.slice";
      Install.WantedBy = lib.mkForce [ "hyprland-session.target" ];
    };

    # Volume, brightness, media and capture keys stay in hyprland.nix; the
    # OSD follows those external changes.
    desktop.hyprland.shellBindings = [
      (exec "SUPER ALT" "L" "Lock screen" (msg "session lock"))
      (exec "SUPER" "P" "Toggle control center" (msg "panel-toggle control-center"))
      (exec "SUPER" "N" "Toggle notification history" (msg "panel-toggle control-center notifications"))
      (exec "SUPER ALT" "N" "Toggle Do Not Disturb" (msg "notification-dnd-toggle"))
      (exec "SUPER ALT" "V" "Toggle clipboard history" (msg "panel-toggle clipboard"))
      (exec "SUPER ALT" "P" "Open power menu" (msg "panel-toggle session"))
    ];

    wayland.windowManager.hyprland.settings = {
      # Noctalia animates its own surfaces.
      layerrule = [
        "no_anim on, match:namespace ^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$"
      ];
      windowrule = [
        "float on, match:class ^dev\\.noctalia\\.Noctalia$"
        "size 1080 920, match:class ^dev\\.noctalia\\.Noctalia$"
      ];
    };

    programs.system-menu.sections.Hyprland = lib.mkAfter [
      {
        label = "Noctalia";
        children = [
          { label = "Control center"; action = msg "panel-toggle control-center"; }
          { label = "Settings"; action = msg "settings-open"; }
          { label = "App launcher"; action = msg "panel-toggle launcher"; }
          { label = "Clipboard history"; action = msg "panel-toggle clipboard"; }
          { label = "Notifications"; action = msg "panel-toggle control-center notifications"; }
          { label = "Do Not Disturb (toggle)"; action = msg "notification-dnd-toggle"; }
        ];
      }
      {
        label = "Appearance / wallpaper";
        children = [
          { label = "Browse wallpapers"; action = msg "panel-toggle wallpaper"; }
        ];
      }
      {
        label = "Network / Bluetooth";
        children = [
          { label = "Network"; action = msg "panel-toggle control-center network"; }
          { label = "Bluetooth"; action = msg "panel-toggle control-center bluetooth"; }
        ];
      }
      {
        label = "Power";
        children = [
          { label = "Lock screen"; action = msg "session lock"; }
          # Noctalia's session panel owns log out, suspend, restart and shut down.
          { label = "Suspend / restart / shut down / log out"; action = msg "panel-toggle session"; }
        ];
      }
    ];
  };
}
