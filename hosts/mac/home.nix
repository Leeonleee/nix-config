{ pkgs, pkgsUnstable, pkgsMaster, ... }:

{
  home.stateVersion = "26.05";

  # Home Manager uses the system package set, so disable its overlays.
  stylix.overlays.enable = false;

  imports = [
    ../../modules/home/profiles/development.nix
    ../../modules/home/profiles/general-use.nix
  ];

  # Add packages and other Home Manager settings used only on macOS here.
  # home.packages = [
  #   pkgs.example-package
  #   pkgsUnstable.example-package
  #   pkgsMaster.example-package
  # ];
}
