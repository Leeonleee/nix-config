{ pkgs, pkgsUnstable, pkgsMaster, ... }:

{
  imports = [
    ../../modules/home/profiles/general-use.nix
  ];

  # Add packages and other Home Manager settings used only on macOS here.
  # home.packages = [
  #   pkgs.example-package
  #   pkgsUnstable.example-package
  #   pkgsMaster.example-package
  # ];
}
