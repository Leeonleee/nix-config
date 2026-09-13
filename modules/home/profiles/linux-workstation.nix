{ pkgs, ... }:

{
  # Linux workstation applications, imported only by graphical Linux hosts.
  imports = [
    ../programs/voxtype.nix
    ../programs/vicinae.nix
  ];

  home.packages = with pkgs; [
    kdePackages.kate
  ];
}
