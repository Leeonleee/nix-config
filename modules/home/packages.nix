{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bitwarden-desktop
    google-chrome
    kdePackages.kate
    vscode
  ];
}
