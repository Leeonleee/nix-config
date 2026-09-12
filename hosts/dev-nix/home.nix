{ pkgs, pkgsUnstable, pkgsMaster, ... }:

{
  imports = [
    ../../modules/home/profiles/general-use.nix
  ];

  # Keep this host headless by adding only dev-nix-specific packages here.
  # home.packages = [
  #   pkgs.example-package
  #   pkgsUnstable.example-package
  #   pkgsMaster.example-package
  # ];
}
