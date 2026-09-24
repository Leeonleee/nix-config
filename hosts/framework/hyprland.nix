{ config, ... }:

let
  hyprctl = "${config.wayland.windowManager.hyprland.finalPackage}/bin/hyprctl";
in
{
  # Framework lid handling, matching hosts/framework/niri.nix. Reloading on
  # open restores eDP-1 from the configured monitor rules.
  wayland.windowManager.hyprland.settings.bindl = [
    ", switch:on:Lid Switch, exec, ${hyprctl} keyword monitor eDP-1,disable"
    ", switch:off:Lid Switch, exec, ${hyprctl} reload"
  ];
}
