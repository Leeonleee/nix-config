{ pkgs, ... }:

{
  # Linux workstation applications, imported only by graphical Linux hosts.
  imports = [
    ../programs/voxtype.nix
    ../programs/vicinae.nix
  ];

  services.trayscale.enable = true;

  home.packages = with pkgs; [
    kdePackages.kate
  ];
}
