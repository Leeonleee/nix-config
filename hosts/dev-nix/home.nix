{ pkgs, pkgsUnstable, pkgsMaster, ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ../../modules/home/profiles/development.nix
  ];

  # Keep this host headless by adding only dev-nix-specific packages here.
  # home.packages = [
  #   pkgs.example-package
  #   pkgsUnstable.example-package
  #   pkgsMaster.example-package
  # ];
}
