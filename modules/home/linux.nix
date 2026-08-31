# modules/home/linux.nix

{
  imports = [
    ./programs/openwhispr.nix
  ];

  home.packages = with pkgs; [
    kdePackages.kate
  ];
}