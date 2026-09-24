{ pkgsUnstable, ... }:

{
  # Register the greeter session and portal; desktop settings live in Home Manager.
  programs.hyprland = {
    enable = true;
    # Newer Hyprland than the release branch. Home Manager's hyprland.nix uses
    # the same package so the session and its config agree on the version.
    package = pkgsUnstable.hyprland;
    portalPackage = pkgsUnstable.xdg-desktop-portal-hyprland;
    # Home Manager owns hyprland-session.target, rather than UWSM.
    withUWSM = false;
  };

  security.polkit.enable = true;

  xdg.portal.config.hyprland = {
    default = [ "hyprland" "gtk" ];
    "org.freedesktop.impl.portal.FileChooser" = "kde";
    "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
  };
}
