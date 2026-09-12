{ pkgs, pkgsUnstable, pkgsMaster, ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ../../modules/home/profiles/general-use.nix
    ../../modules/home/profiles/linux-workstation.nix
  ];

  # Add packages and other Home Manager settings used only on desktop here.
  # home.packages = [
  #   pkgs.example-package
  #   pkgsUnstable.example-package
  #   pkgsMaster.example-package
  # ];
}
