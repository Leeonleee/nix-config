{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos
    ../../modules/nixos/workstation.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/hyprland.nix
  ];

  networking.hostName = "framework";

  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.fprintd.enable = true;

  # Suspend on lid close when using the laptop by itself, but keep running in
  # clamshell mode when an external monitor is connected. Being on AC power
  # alone should not prevent suspension.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  virtualisation.docker.storageDriver = "btrfs";

  programs.ssh = {
    extraConfig = ''


      Host l2v-dev
        HostName dev-nix
        User leonl
        ExitOnForwardFailure yes
        ServerAliveInterval 30
        ServerAliveCountMax 3

        LocalForward 5173 [::1]:5173
        LocalForward 3000 127.0.0.1:3000
        LocalForward 54321 127.0.0.1:54321
        LocalForward 54322 127.0.0.1:54322
        LocalForward 54323 127.0.0.1:54323
        LocalForward 54324 127.0.0.1:54324
    '';
  };
}
