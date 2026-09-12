{ inputs, pkgs, ... }:

{
  imports = [
    ../../modules/home/profiles/general-use.nix
  ];

  # Claude Desktop is available on Linux through llm-agents.nix.
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
  ];

  # Add other packages and Home Manager settings used only on framework here.
}
