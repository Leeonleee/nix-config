{ pkgs, ... }:

{
  # Linux workstation applications, imported only by graphical Linux hosts.
  home.packages = with pkgs; [
    kdePackages.kate
  ];
}
