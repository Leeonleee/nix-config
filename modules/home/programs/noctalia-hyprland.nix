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
    desktop.noctalia.sessionTargets = [ "hyprland-session.target" ];

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

    programs.system-menu.sections.Hyprland = lib.mkAfter (import ./noctalia-menu.nix msg);
  };
}
