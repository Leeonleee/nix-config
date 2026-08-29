{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix
    inputs.nirinit.nixosModules.nirinit
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

  services.nirinit = {
    enable = true;

    settings = {
      skip.apps = [];

      launch = {};
    };
  };

  # Niri's default GNOME portal delegates its file chooser to Nautilus, which
  # is not installed. Use the KDE file chooser alongside Dolphin instead.
  xdg.mime.defaultApplications."inode/directory" =
    "org.kde.dolphin.desktop";

  xdg.portal.config.niri = {
    default = [ "gnome" "gtk" ];
    "org.freedesktop.impl.portal.Access" = "gtk";
    "org.freedesktop.impl.portal.FileChooser" = "kde";
    "org.freedesktop.impl.portal.Notification" = "gtk";
    "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
  };
}
