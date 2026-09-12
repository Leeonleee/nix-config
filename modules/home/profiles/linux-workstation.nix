{ pkgs, ... }:

{
  # Linux workstation applications, imported only by graphical Linux hosts.
  imports = [
    ../programs/openwhispr.nix
  ];

  home.packages = with pkgs; [
    kdePackages.kate
  ];
}
