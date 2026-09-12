{ pkgs, ... }:

{
  # Applications installed for every Home Manager host.
  home.packages = with pkgs; [
    bitwarden-desktop
    google-chrome
  ];
}
