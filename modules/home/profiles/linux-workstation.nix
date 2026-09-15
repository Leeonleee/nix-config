{ inputs, pkgs, ... }:

{
  # Linux workstation applications, imported only by graphical Linux hosts.
  imports = [
    ../programs/voxtype.nix
    ../programs/vicinae.nix
  ];

  services.trayscale.enable = true;

  home.packages = with pkgs; [
    kdePackages.kate
    # Claude Desktop is available on Linux through llm-agents.nix.
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
  ];
}
