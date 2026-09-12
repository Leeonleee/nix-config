{ pkgs, ... }:

{
  # Linux workstation applications, imported only by graphical Linux hosts.
  imports = [
    ../programs/voxtype.nix
  ];

  home.packages = with pkgs; [
    kdePackages.kate
  ];
}
