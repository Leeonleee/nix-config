{ pkgs, lib, ... }:

{
  environment.systemPackages = [
    pkgs.sbctl
  ];

  # Lanzaboote replaces the normal systemd-boot installation mechanism.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
}
