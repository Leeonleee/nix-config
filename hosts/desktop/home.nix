{ pkgs, pkgsUnstable, pkgsMaster, ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ../../modules/home/profiles/general-use.nix
    ../../modules/home/profiles/linux-workstation.nix
  ];

  programs.niri.settings.outputs."DP-4" = {
    mode = {
      width = 3840;
      height = 2160;
      refresh = 160.0;
    };
    scale = 1.5;
  };

  # Add packages and other Home Manager settings used only on desktop here.
  # home.packages = [
  #   pkgs.example-package
  #   pkgsUnstable.example-package
  #   pkgsMaster.example-package
  # ];
}
