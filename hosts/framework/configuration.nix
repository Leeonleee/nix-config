{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
  ];

  networking.hostName = "framework";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.fprintd.enable = true;

  virtualisation.docker.storageDriver = "btrfs";

  nixpkgs.overlays = [
    inputs.niri.overlays.niri
  ];

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };
}
