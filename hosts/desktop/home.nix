{ pkgs, pkgsUnstable, pkgsMaster, ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ../../modules/home/profiles/development.nix
    ../../modules/home/profiles/general-use.nix
    ../../modules/home/profiles/linux-workstation.nix
    ../../modules/home/profiles/niri.nix
    ../../modules/home/profiles/hyprland.nix
  ];

  programs.niri.settings.outputs."DP-4" = {
    mode = {
      width = 3840;
      height = 2160;
      refresh = 160.0;
    };
    scale = 1.5;
  };

  wayland.windowManager.hyprland.settings = {
    monitor = [ "DP-4,3840x2160@160,auto,1.5" ];
    env = [
      "LIBVA_DRIVER_NAME,nvidia"
      "__GLX_VENDOR_LIBRARY_NAME,nvidia"
    ];
  };

  # Add packages and other Home Manager settings used only on desktop here.
  # home.packages = [
  #   pkgs.example-package
  #   pkgsUnstable.example-package
  #   pkgsMaster.example-package
  # ];
}
