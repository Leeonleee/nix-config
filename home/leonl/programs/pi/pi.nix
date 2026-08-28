{ inputs, pkgs, ... }:

let
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.system;
  };
in
{
  imports = [
    "${inputs.home-manager-unstable}/modules/programs/pi-coding-agent.nix"
  ];
  programs.pi-coding-agent = {
    enable = true;
    package = unstable.pi-coding-agent;

    settings = {
      defaultProvider = "openai";
      defaultThinkingLevel = "high";
    };
  };
}
