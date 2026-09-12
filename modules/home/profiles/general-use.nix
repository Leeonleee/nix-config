{ inputs, pkgs, ... }:

{
  # Daily-use applications shared by the current hosts. Remove this profile
  # from a host's home.nix if that host should not receive these applications.
  home.packages = with pkgs; [
    vscode
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.chatgpt
  ];

  programs.vesktop.enable = true;
}
