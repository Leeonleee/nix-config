{ config, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos
    ../../modules/nixos/workstation.nix
    ../../modules/nixos/secure-boot.nix
  ];

  networking.hostName = "desktop";

  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
