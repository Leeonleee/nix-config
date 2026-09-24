{ pkgs, ... }:

{
  # Register the greeter session and portal; desktop settings live in Home Manager.
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
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
