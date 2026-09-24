{ ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ../../modules/home/profiles/development.nix
    ../../modules/home/profiles/general-use.nix
    ../../modules/home/profiles/linux-workstation.nix
    ../../modules/home/profiles/niri.nix
    ../../modules/home/profiles/hyprland.nix
    ../../modules/home/programs/easyeffects.nix
    ./niri.nix
    ./hyprland.nix
  ];

  wayland.windowManager.hyprland.settings.monitor = [
    "eDP-1,preferred,0x0,1.5"
    "DP-2,preferred,1920x0,1.5"
    "DP-9,preferred,auto,1"
    "DP-10,preferred,0x0,1"
    "DP-11,preferred,auto,1"
    "DP-12,preferred,0x0,1"
    "DP-19,preferred,0x0,1"
  ];

  # Add packages and Home Manager settings used only on framework here.
}
