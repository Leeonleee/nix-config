{ ... }:

{
  imports = [
    ../programs/hyprland.nix
    ../programs/caelestia.nix
    ../programs/noctalia.nix
    ../programs/noctalia-hyprland.nix
    ../programs/system-menu.nix
  ];

  # Shell started with Hyprland: "caelestia" or "noctalia". Both stay
  # installed; only the selected one runs and owns the shell keybindings.
  desktop.hyprland.shell = "noctalia";
}
