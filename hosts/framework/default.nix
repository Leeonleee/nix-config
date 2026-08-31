{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos
    inputs.nirinit.nixosModules.nirinit
  ];

  networking.hostName = "framework";

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
        HostName dev
        User leonl
        ExitOnForwardFailure yes
        ServerAliveInterval 30
        ServerAliveCountMax 3

        LocalForward 5173 [::1]:5173
        LocalForward 3000 127.0.0.1:3000
        LocalForward 54321 127.0.0.1:54321
        LocalForward 54324 127.0.0.1:54324
    '';
  };

  nixpkgs.overlays = [
    inputs.niri.overlays.niri
  ];

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };

  services.nirinit = {
    enable = true;

    settings = {
      skip.apps = [ ];

      launch = { };
    };
  };

  security.pam.services.dankshell = {
    # DMS handles fingerprints separately
    fprintAuth = false;
  };

  # Niri's default GNOME portal delegates its file chooser to Nautilus, which
  # is not installed. Use the KDE file chooser alongside Dolphin instead.
  xdg.mime.defaultApplications."inode/directory" = "org.kde.dolphin.desktop";

  xdg.portal.config.niri = {
    default = [
      "gnome"
      "gtk"
    ];
    "org.freedesktop.impl.portal.Access" = "gtk";
    "org.freedesktop.impl.portal.FileChooser" = "kde";
    "org.freedesktop.impl.portal.Notification" = "gtk";
    "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
  };
}
