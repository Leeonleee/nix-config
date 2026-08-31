{ pkgs, ... }:

{
  imports = [
    ../programs/openwhispr.nix
  ];

  home.username = "leonl";
  home.homeDirectory = "/home/leonl";

  home.packages = with pkgs; [
    kdePackages.kate
  ];
}
