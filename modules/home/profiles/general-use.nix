{ inputs, pkgs, ... }:

{
  imports = [
    ../programs/kitty.nix
  ];

  # Daily-use applications for graphical hosts. Remove this profile from a
  # host's home.nix if that host should not receive these applications.
  home.packages = with pkgs; [
    vscode
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.chatgpt
  ];

  programs.vesktop.enable = true;
}
