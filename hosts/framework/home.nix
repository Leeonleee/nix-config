{ inputs, pkgs, ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ../../modules/home/profiles/general-use.nix
    ../../modules/home/profiles/linux-workstation.nix
    ./niri.nix
  ];

  # Claude Desktop is available on Linux through llm-agents.nix.
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
  ];

  # Add other packages and Home Manager settings used only on framework here.
}
