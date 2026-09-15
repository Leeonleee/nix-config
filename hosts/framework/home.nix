{ ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ../../modules/home/profiles/development.nix
    ../../modules/home/profiles/general-use.nix
    ../../modules/home/profiles/linux-workstation.nix
    ../../modules/home/profiles/niri.nix
    ./niri.nix
  ];

  # Add packages and Home Manager settings used only on framework here.
}
