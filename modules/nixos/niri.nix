{ pkgs, inputs, ... }:

{
  imports = [
    inputs.niri.nixosModules.niri
    inputs.nirinit.nixosModules.nirinit
  ];

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

  # Niri's default GNOME portal delegates its file chooser to Nautilus, which
  # is not installed. Use the KDE file chooser alongside Dolphin instead.
  xdg.mime.defaultApplications."inode/directory" = "org.kde.dolphin.desktop";
  environment.etc."xdg/menus/applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

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

  security.pam.services.dankshell = {
    # DMS handles fingerprints separately
    fprintAuth = false;
  };
}
