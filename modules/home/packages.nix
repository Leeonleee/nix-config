{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bitwarden-desktop
    google-chrome
    vscode
  ];
}
